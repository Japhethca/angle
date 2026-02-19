defmodule Angle.Recommendations.Scoring.SimilarityScorer do
  @moduledoc """
  Computes similarity scores between items for "similar items" recommendations.

  Similarity formula:
    similarity = (same_category ? 0.5 : 0.0) +
                 (price_range_overlap ? 0.3 : 0.0) +
                 collaborative_signal

  Where collaborative_signal = min(shared_users / 20.0, 0.2)
  """

  require Ash.Query

  @doc """
  Compute similarity scores between source_item and a list of candidate items.

  Returns list of {item, score, reason} tuples sorted by score desc.
  """
  def compute_similarities(source_item, candidate_items) do
    candidate_items
    |> Enum.reject(&(&1.id == source_item.id))
    |> Enum.map(fn candidate ->
      score = compute_similarity_score(source_item, candidate)
      reason = determine_reason(source_item, candidate)

      {candidate, score, reason}
    end)
    |> Enum.filter(fn {_item, score, _reason} -> score > 0.3 end)
    |> Enum.sort_by(fn {_item, score, _reason} -> score end, :desc)
  end

  @doc """
  Compute similarity score between two items.
  """
  def compute_similarity_score(item_a, item_b) do
    category_score = category_similarity(item_a, item_b)
    price_score = price_similarity(item_a, item_b)
    collaborative_score = collaborative_similarity(item_a.id, item_b.id)

    category_score + price_score + collaborative_score
  end

  @doc """
  Category similarity: 0.5 if same category, 0.0 otherwise.
  """
  def category_similarity(item_a, item_b) do
    if item_a.category_id == item_b.category_id, do: 0.5, else: 0.0
  end

  @doc """
  Price similarity: 0.3 if within 50% range, 0.0 otherwise.
  """
  def price_similarity(item_a, item_b) do
    price_a = item_a.current_price
    price_b = item_b.current_price

    # Handle nil prices (items without set prices)
    if is_nil(price_a) or is_nil(price_b) do
      0.0
    else
      price_diff = Decimal.abs(Decimal.sub(price_a, price_b))
      threshold = Decimal.mult(price_a, Decimal.new("0.5"))

      # Include boundary: within 50% includes exactly 50%
      if Decimal.compare(price_diff, threshold) in [:lt, :eq], do: 0.3, else: 0.0
    end
  end

  @doc """
  Collaborative similarity: Users who engaged with both items.

  Returns min(shared_users / 20.0, 0.2)
  """
  def collaborative_similarity(item_a_id, item_b_id) do
    users_a = get_engaged_users(item_a_id)
    users_b = get_engaged_users(item_b_id)

    shared_count =
      MapSet.intersection(users_a, users_b)
      |> MapSet.size()

    min(shared_count / 20.0, 0.2)
  end

  @doc """
  Determine primary reason for similarity.
  """
  def determine_reason(item_a, item_b) do
    cond do
      item_a.category_id == item_b.category_id -> :same_category
      price_similarity(item_a, item_b) > 0 -> :price_range
      true -> :collaborative
    end
  end

  # Private helpers

  defp get_engaged_users(item_id) do
    # Users who bid on this item
    bidders =
      Angle.Bidding.Bid
      |> Ash.Query.filter(item_id == ^item_id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)
      |> MapSet.new()

    # Users who watchlisted this item
    watchers =
      Angle.Inventory.WatchlistItem
      |> Ash.Query.filter(item_id == ^item_id)
      |> Ash.Query.select([:user_id])
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.user_id)
      |> MapSet.new()

    MapSet.union(bidders, watchers)
  end
end
