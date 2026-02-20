defmodule Angle.Recommendations.Scoring.SimilarityScorer do
  @moduledoc """
  Computes similarity scores between items for "similar items" recommendations.

  Similarity formula:
    similarity = (same_category ? CATEGORY_WEIGHT : 0.0) +
                 (price_range_overlap ? PRICE_WEIGHT : 0.0) +
                 collaborative_signal

  Where collaborative_signal = min(shared_users / COLLABORATIVE_DIVISOR, COLLABORATIVE_CAP)
  """

  # Scoring weights and thresholds
  @category_weight 0.5
  @price_weight 0.3
  @collaborative_cap 0.2
  @collaborative_divisor 20.0
  @price_range_threshold "0.5"
  @min_similarity_score 0.3

  @doc """
  Compute similarity scores between source_item and a list of candidate items.

  Returns `{:ok, results}` where results is a list of `{item, score, reason}` tuples sorted by score desc,
  or `{:error, reason}` if data retrieval fails.
  """
  @spec compute_similarities(struct(), [struct()]) ::
          {:ok, [{struct(), float(), atom()}]} | {:error, term()}
  def compute_similarities(source_item, candidate_items) do
    # Pre-compute source item's engaged users once to avoid N+1 queries
    with {:ok, source_users} <- get_engaged_users(source_item.id),
         candidates <- Enum.reject(candidate_items, &(&1.id == source_item.id)),
         candidate_ids <- Enum.map(candidates, & &1.id),
         {:ok, all_candidate_users} <- get_engaged_users_batch(candidate_ids) do
      results =
        candidates
        |> Enum.map(fn candidate ->
          category_score = compute_category_similarity(source_item, candidate)
          price_score = compute_price_similarity(source_item, candidate)

          # Get candidate users from batched results
          candidate_users = Map.get(all_candidate_users, candidate.id, MapSet.new())
          collaborative_score = compute_collaborative_similarity(source_users, candidate_users)

          score = category_score + price_score + collaborative_score
          reason = determine_reason(category_score, price_score, collaborative_score)

          {candidate, score, reason}
        end)
        |> Enum.filter(fn {_item, score, _reason} -> score > @min_similarity_score end)
        |> Enum.sort_by(fn {_item, score, _reason} -> score end, :desc)

      {:ok, results}
    end
  end

  # Private scoring helpers

  defp compute_category_similarity(item_a, item_b) do
    if item_a.category_id == item_b.category_id, do: @category_weight, else: 0.0
  end

  defp compute_price_similarity(item_a, item_b) do
    price_a = item_a.current_price
    price_b = item_b.current_price

    # Handle nil or zero prices
    cond do
      is_nil(price_a) or is_nil(price_b) ->
        0.0

      Decimal.eq?(price_a, Decimal.new(0)) and Decimal.eq?(price_b, Decimal.new(0)) ->
        # Both zero-priced: consider similar
        @price_weight

      Decimal.eq?(price_a, Decimal.new(0)) or Decimal.eq?(price_b, Decimal.new(0)) ->
        # One zero-priced, one not: not similar
        0.0

      true ->
        # Use max price as basis for threshold to ensure symmetry
        max_price = Decimal.max(price_a, price_b)
        price_diff = Decimal.abs(Decimal.sub(price_a, price_b))
        threshold = Decimal.mult(max_price, Decimal.new(@price_range_threshold))

        # Include boundary: within 50% includes exactly 50%
        if Decimal.compare(price_diff, threshold) in [:lt, :eq], do: @price_weight, else: 0.0
    end
  end

  defp compute_collaborative_similarity(users_a, users_b) do
    shared_count =
      users_a
      |> MapSet.intersection(users_b)
      |> MapSet.size()

    min(shared_count / @collaborative_divisor, @collaborative_cap)
  end

  defp determine_reason(category_score, price_score, collaborative_score) do
    cond do
      category_score > 0 -> :same_category
      price_score > 0 -> :price_range
      collaborative_score > 0 -> :collaborative
      true -> :collaborative
    end
  end

  defp get_engaged_users(item_id) do
    with {:ok, bidders} <- get_single_item_bidders(item_id),
         {:ok, watchers} <- get_single_item_watchers(item_id) do
      {:ok, MapSet.union(bidders, watchers)}
    end
  end

  defp get_engaged_users_batch(item_ids) do
    with {:ok, bidders_map} <- get_batch_bidders(item_ids),
         {:ok, watchers_map} <- get_batch_watchers(item_ids) do
      engaged_map = merge_engaged_users(bidders_map, watchers_map, item_ids)
      {:ok, engaged_map}
    end
  end

  defp get_single_item_bidders(item_id) do
    case Angle.Bidding.list_bids_by_item_ids([item_id], authorize?: false) do
      {:ok, bids} ->
        user_ids = Enum.map(bids, & &1.user_id) |> MapSet.new()
        {:ok, user_ids}

      error ->
        error
    end
  end

  defp get_single_item_watchers(item_id) do
    case Angle.Inventory.list_watchlist_by_item_ids([item_id], authorize?: false) do
      {:ok, items} ->
        user_ids = Enum.map(items, & &1.user_id) |> MapSet.new()
        {:ok, user_ids}

      error ->
        error
    end
  end

  defp get_batch_bidders(item_ids) do
    case Angle.Bidding.list_bids_by_item_ids(item_ids, authorize?: false) do
      {:ok, bids} ->
        grouped =
          bids
          |> Enum.group_by(& &1.item_id, & &1.user_id)
          |> Map.new(fn {item_id, user_ids} -> {item_id, MapSet.new(user_ids)} end)

        {:ok, grouped}

      error ->
        error
    end
  end

  defp get_batch_watchers(item_ids) do
    case Angle.Inventory.list_watchlist_by_item_ids(item_ids, authorize?: false) do
      {:ok, items} ->
        grouped =
          items
          |> Enum.group_by(& &1.item_id, & &1.user_id)
          |> Map.new(fn {item_id, user_ids} -> {item_id, MapSet.new(user_ids)} end)

        {:ok, grouped}

      error ->
        error
    end
  end

  defp merge_engaged_users(bidders_map, watchers_map, item_ids) do
    Map.new(item_ids, fn item_id ->
      bidders = Map.get(bidders_map, item_id, MapSet.new())
      watchers = Map.get(watchers_map, item_id, MapSet.new())
      {item_id, MapSet.union(bidders, watchers)}
    end)
  end
end
