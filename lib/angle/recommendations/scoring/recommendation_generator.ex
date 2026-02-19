defmodule Angle.Recommendations.Scoring.RecommendationGenerator do
  @moduledoc """
  Generates personalized item recommendations for users based on their interests.

  Uses a weighted scoring formula combining:
  - Category match (60%)
  - Popularity (20%)
  - Recency (20%)

  TODO: Refactor to use domain code interfaces per Ash patterns instead of direct Ash calls.
  Currently queries Item directly - should use domain functions.
  """

  require Ash.Query
  alias Angle.Recommendations.Scoring.InterestScorer
  alias Angle.Inventory.Item

  # Scoring weights
  @category_weight 0.6
  @popularity_weight 0.2
  @recency_weight 0.2

  # Popularity normalization
  @watcher_multiplier 2
  @popularity_divisor 10.0

  # Recency thresholds
  @recency_days_threshold 7
  @recency_boost_value 0.1

  # Diversity and limits
  @max_per_category 3
  @default_limit 20
  @top_categories_count 5

  # Reason generation thresholds
  @high_interest_threshold 0.7
  @popular_watcher_threshold 5
  @trending_watcher_threshold 10

  @typedoc "A recommendation tuple: {item, score, human-readable reason}"
  @type recommendation :: {Item.t(), float(), String.t()}

  @doc """
  Generates personalized recommendations for a user.

  Returns a list of {item, score, reason} tuples sorted by score descending.

  ## Options

    * `:limit` - Maximum number of recommendations to return (default: #{@default_limit})

  ## Examples

      iex> generate_for_user(user_id)
      {:ok, [{%Item{}, 0.85, "Popular in Fantasy"}, ...]}

      iex> generate_for_user(user_id, limit: 10)
      {:ok, [{%Item{}, 0.85, "Popular in Fantasy"}, ...]}
  """
  @spec generate_for_user(String.t(), keyword()) :: {:ok, [recommendation()]} | {:error, term()}
  def generate_for_user(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)

    with {:ok, interests} <- InterestScorer.compute_user_interests(user_id),
         {:ok, recommendations} <- generate_recommendations(user_id, interests, limit) do
      {:ok, recommendations}
    end
  end

  # Main recommendation generation logic
  defp generate_recommendations(_user_id, [], _limit) do
    {:ok, []}
  end

  defp generate_recommendations(user_id, interests, limit) do
    top_categories = get_top_categories(interests, @top_categories_count)
    interests_map = Map.new(interests, fn {cat, score, _count, _last} -> {cat, score} end)

    with {:ok, candidate_items} <- find_items_in_categories(user_id, top_categories) do
      recommendations =
        candidate_items
        |> Enum.map(&score_item_for_user(&1, interests_map, user_id))
        |> Enum.sort_by(fn {_item, score, _reason} -> score end, :desc)
        |> apply_diversity_filter()
        |> Enum.take(limit)

      {:ok, recommendations}
    end
  end

  # Get top N categories from interests
  defp get_top_categories(interests, count) do
    interests
    |> Enum.sort_by(fn {_cat, score, _count, _last} -> score end, :desc)
    |> Enum.take(count)
    |> Enum.map(fn {cat, _score, _count, _last} -> cat end)
  end

  # Find candidate items in top categories, excluding user's own items/bids/watchlist
  defp find_items_in_categories(user_id, categories) do
    # Use exists() filters to exclude items without loading full associations
    # This is much more efficient than loading all bids/watchlist items
    Item
    |> Ash.Query.filter(category_id in ^categories)
    |> Ash.Query.filter(publication_status == :published)
    |> Ash.Query.filter(auction_status in [:active, :scheduled, :pending])
    |> Ash.Query.filter(created_by_id != ^user_id)
    |> Ash.Query.filter(not exists(bids, user_id == ^user_id))
    |> Ash.Query.filter(not exists(watchlist_items, user_id == ^user_id))
    |> Ash.Query.load([:bid_count, :watcher_count])
    # System-level query: bypasses authorization as this runs in recommendation context
    |> Ash.read(authorize?: false)
  end

  # Score an item for a user based on category match, popularity, and recency
  defp score_item_for_user(item, interests_map, _user_id) do
    category_score = Map.get(interests_map, item.category_id, 0.0)
    popularity = popularity_boost(item)
    recency = recency_boost(item)

    total_score =
      category_score * @category_weight +
        popularity * @popularity_weight +
        recency * @recency_weight

    reason = generate_reason(item, interests_map)

    {item, total_score, reason}
  end

  # Calculate popularity boost based on bid count and watcher count
  defp popularity_boost(item) do
    bid_count = item.bid_count || 0
    watcher_count = item.watcher_count || 0

    normalized =
      (bid_count + watcher_count * @watcher_multiplier) / @popularity_divisor

    min(normalized, 1.0)
  end

  # Calculate recency boost based on auction end time and status
  defp recency_boost(item) do
    ending_soon_boost =
      case item.end_time do
        nil ->
          0.0

        end_time ->
          days_until_end = DateTime.diff(end_time, DateTime.utc_now(), :day)

          if days_until_end > 0 and days_until_end < @recency_days_threshold do
            @recency_boost_value
          else
            0.0
          end
      end

    active_boost =
      if item.auction_status == :active do
        @recency_boost_value
      else
        0.0
      end

    ending_soon_boost + active_boost
  end

  # Apply diversity filter to ensure max N items per category
  defp apply_diversity_filter(scored_items) do
    {filtered, _counts} =
      Enum.reduce(scored_items, {[], %{}}, fn {item, _score, _reason} = tuple, {acc, counts} ->
        category_id = item.category_id
        count = Map.get(counts, category_id, 0)

        if count < @max_per_category do
          {[tuple | acc], Map.put(counts, category_id, count + 1)}
        else
          {acc, counts}
        end
      end)

    Enum.reverse(filtered)
  end

  # Generate human-readable reason for recommendation
  defp generate_reason(item, interests_map) do
    category_score = Map.get(interests_map, item.category_id, 0.0)
    watcher_count = item.watcher_count || 0

    cond do
      category_score > @high_interest_threshold and watcher_count > @popular_watcher_threshold ->
        "Popular in your favorite category"

      category_score > @high_interest_threshold ->
        "Based on your interest in this category"

      watcher_count > @trending_watcher_threshold ->
        "Trending item"

      item.auction_status == :active and item.end_time != nil ->
        days_until_end = DateTime.diff(item.end_time, DateTime.utc_now(), :day)

        if days_until_end < @recency_days_threshold do
          "Ending soon"
        else
          "Active auction"
        end

      true ->
        "Recommended for you"
    end
  end
end
