defmodule Angle.Recommendations.Scoring.InterestScorer do
  @moduledoc """
  Computes user interest scores per category based on bids and watchlist items.

  Scoring formula:
    interest_score = (bid_count × 3.0) + (watchlist_count × 2.0) × time_decay

  Time decay:
    - Last 7 days: 1.0x
    - 8-30 days: 0.7x
    - 31-90 days: 0.4x
    - 90+ days: 0.1x
  """

  @doc """
  Compute interest scores for a user across all categories they've engaged with.

  Returns list of {category_id, score, interaction_count, last_interaction} tuples.
  """
  def compute_user_interests(user_id, since \\ days_ago(90)) do
    # Get user's bids
    bids = get_user_bids(user_id, since)

    # Get user's watchlist
    watchlist = get_user_watchlist(user_id, since)

    # Group by category
    bid_categories = group_by_category(bids)
    watchlist_categories = group_by_category(watchlist)

    # Compute scores
    all_categories = Map.keys(bid_categories) ++ Map.keys(watchlist_categories)
    all_categories = Enum.uniq(all_categories)

    all_categories
    |> Enum.map(fn category_id ->
      bid_items = Map.get(bid_categories, category_id, [])
      watchlist_items = Map.get(watchlist_categories, category_id, [])

      score = compute_category_score(bid_items, watchlist_items)
      interaction_count = length(bid_items) + length(watchlist_items)
      last_interaction = get_last_interaction(bid_items ++ watchlist_items)

      {category_id, score, interaction_count, last_interaction}
    end)
    |> normalize_scores()
  end

  @doc """
  Compute score for a single category based on bids and watchlist items.
  """
  def compute_category_score(bid_items, watchlist_items) do
    bid_score =
      bid_items
      |> Enum.map(&apply_time_decay(&1, 3.0))
      |> Enum.sum()

    watchlist_score =
      watchlist_items
      |> Enum.map(&apply_time_decay(&1, 2.0))
      |> Enum.sum()

    bid_score + watchlist_score
  end

  @doc """
  Apply time decay multiplier based on how recent the interaction was.
  """
  def apply_time_decay(item, base_weight) do
    days_ago = DateTime.diff(DateTime.utc_now(), item.timestamp, :day)

    multiplier =
      cond do
        days_ago <= 7 -> 1.0
        days_ago <= 30 -> 0.7
        days_ago <= 90 -> 0.4
        true -> 0.1
      end

    base_weight * multiplier
  end

  @doc """
  Normalize scores to 0.0-1.0 range.
  """
  def normalize_scores(category_scores) do
    if Enum.empty?(category_scores) do
      []
    else
      max_score = category_scores |> Enum.map(&elem(&1, 1)) |> Enum.max()

      if max_score == 0 do
        category_scores
      else
        Enum.map(category_scores, fn {cat_id, score, count, last_interaction} ->
          normalized = min(score / max_score, 1.0)
          {cat_id, normalized, count, last_interaction}
        end)
      end
    end
  end

  # Private helpers

  defp get_user_bids(user_id, since) do
    require Ash.Query

    Angle.Bidding.Bid
    |> Ash.Query.filter(user_id == ^user_id and bid_time > ^since)
    |> Ash.Query.load(:item)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn bid ->
      %{
        category_id: bid.item.category_id,
        timestamp: bid.bid_time
      }
    end)
  end

  defp get_user_watchlist(user_id, since) do
    require Ash.Query

    Angle.Inventory.WatchlistItem
    |> Ash.Query.filter(user_id == ^user_id and inserted_at > ^since)
    |> Ash.Query.load(:item)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn watchlist_item ->
      %{
        category_id: watchlist_item.item.category_id,
        timestamp: watchlist_item.inserted_at
      }
    end)
  end

  defp group_by_category(items) do
    Enum.group_by(items, & &1.category_id)
  end

  defp get_last_interaction(items) do
    items
    |> Enum.map(& &1.timestamp)
    |> Enum.max(DateTime, fn -> DateTime.utc_now() end)
  end

  defp days_ago(days) do
    DateTime.utc_now()
    |> DateTime.add(-days * 24 * 60 * 60, :second)
  end
end
