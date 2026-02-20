defmodule Angle.Recommendations.Scoring.InterestScorer do
  @moduledoc """
  Computes user interest scores per category based on bids and watchlist items.

  Scoring formula (per-item with individual time decay):
    interest_score = sum(3.0 × decay(bid_i)) + sum(2.0 × decay(watchlist_j))

  Where each interaction is weighted and decayed individually based on recency.

  Time decay multipliers:
    - Last 7 days: 1.0x
    - 8-30 days: 0.7x
    - 31-90 days: 0.4x
    - 90+ days: 0.1x
  """

  @doc """
  Compute interest scores for a user across all categories they've engaged with.

  Returns `{:ok, scores}` where scores is a list of `{category_id, score, interaction_count, last_interaction}` tuples,
  or `{:error, reason}` if data retrieval fails.
  """
  @spec compute_user_interests(String.t(), DateTime.t()) ::
          {:ok, [{String.t(), float(), non_neg_integer(), DateTime.t()}]} | {:error, term()}
  def compute_user_interests(user_id, since \\ days_ago(90)) do
    now = DateTime.utc_now()

    with {:ok, bids} <- get_user_bids(user_id, since),
         {:ok, watchlist} <- get_user_watchlist(user_id, since) do
      bid_categories = group_by_category(bids)
      watchlist_categories = group_by_category(watchlist)

      all_categories = Map.keys(bid_categories) ++ Map.keys(watchlist_categories)
      all_categories = Enum.uniq(all_categories)

      scores =
        all_categories
        |> Enum.map(fn category_id ->
          bid_items = Map.get(bid_categories, category_id, [])
          watchlist_items = Map.get(watchlist_categories, category_id, [])

          score = compute_category_score(bid_items, watchlist_items, now)
          interaction_count = length(bid_items) + length(watchlist_items)
          last_interaction = get_last_interaction(bid_items ++ watchlist_items)

          {category_id, score, interaction_count, last_interaction}
        end)
        |> normalize_scores()

      {:ok, scores}
    end
  end

  # Private helpers

  defp compute_category_score(bid_items, watchlist_items, now) do
    bid_score =
      bid_items
      |> Enum.map(&apply_time_decay(&1, 3.0, now))
      |> Enum.sum()

    watchlist_score =
      watchlist_items
      |> Enum.map(&apply_time_decay(&1, 2.0, now))
      |> Enum.sum()

    bid_score + watchlist_score
  end

  defp apply_time_decay(item, base_weight, now) do
    days_ago = DateTime.diff(now, item.timestamp, :day)

    multiplier =
      cond do
        days_ago <= 7 -> 1.0
        days_ago <= 30 -> 0.7
        days_ago <= 90 -> 0.4
        true -> 0.1
      end

    base_weight * multiplier
  end

  defp normalize_scores(category_scores) do
    if Enum.empty?(category_scores) do
      []
    else
      max_score = category_scores |> Enum.map(&elem(&1, 1)) |> Enum.max()

      if max_score == 0 do
        category_scores
      else
        Enum.map(category_scores, fn {cat_id, score, count, last_interaction} ->
          # Division by max_score (where max_score >= score) ensures result <= 1.0
          normalized = score / max_score
          {cat_id, normalized, count, last_interaction}
        end)
      end
    end
  end

  defp get_user_bids(user_id, since) do
    case Angle.Bidding.list_user_bids_since(
           user_id,
           since,
           authorize?: false,
           load: [item: [:category_id]]
         ) do
      {:ok, bids} ->
        items =
          bids
          |> Enum.reject(&is_nil(&1.item.category_id))
          |> Enum.map(fn bid ->
            %{
              category_id: bid.item.category_id,
              timestamp: bid.bid_time
            }
          end)

        {:ok, items}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_user_watchlist(user_id, since) do
    case Angle.Inventory.list_user_watchlist_since(
           user_id,
           since,
           authorize?: false,
           load: [item: [:category_id]]
         ) do
      {:ok, watchlist_items} ->
        items =
          watchlist_items
          |> Enum.reject(&is_nil(&1.item.category_id))
          |> Enum.map(fn watchlist_item ->
            %{
              category_id: watchlist_item.item.category_id,
              timestamp: watchlist_item.inserted_at
            }
          end)

        {:ok, items}

      {:error, reason} ->
        {:error, reason}
    end
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
    DateTime.utc_now() |> DateTime.add(-days, :day)
  end
end
