defmodule Angle.Recommendations.Queries do
  @moduledoc """
  Query helpers for recommendations domain.

  Encapsulates cross-domain interactions and complex queries
  used by scoring modules. Centralizes all direct Ash calls
  that cross domain boundaries.

  TODO: Refactor to use code interfaces per Ash patterns. Currently makes direct
  Ash calls to Bidding.Bid and Inventory.WatchlistItem - these should be replaced
  with code interfaces defined in their respective domains (e.g.,
  Angle.Bidding.list_user_bids_since/2, Angle.Inventory.list_user_watchlist_since/2).
  """

  require Ash.Query

  @doc """
  Get user's bids within a time window, with item and category loaded.
  """
  def get_user_bids(user_id, since) do
    Angle.Bidding.Bid
    |> Ash.Query.filter(user_id == ^user_id and bid_time > ^since)
    |> Ash.Query.load(item: [:category_id])
    |> Ash.read(authorize?: false)
  end

  @doc """
  Get user's watchlist items within a time window, with item and category loaded.
  """
  def get_user_watchlist(user_id, since) do
    Angle.Inventory.WatchlistItem
    |> Ash.Query.filter(user_id == ^user_id and inserted_at > ^since)
    |> Ash.Query.load(item: [:category_id])
    |> Ash.read(authorize?: false)
  end

  @doc """
  Get engaged users (bidders + watchers) for a single item.
  Returns a MapSet of user IDs.
  """
  def get_engaged_users(item_id) do
    with {:ok, bidders} <- get_single_item_bidders(item_id),
         {:ok, watchers} <- get_single_item_watchers(item_id) do
      {:ok, MapSet.union(bidders, watchers)}
    end
  end

  @doc """
  Get engaged users (bidders + watchers) for multiple items in a single query.
  Returns a map of item_id => MapSet(user_ids).
  Avoids N+1 queries when checking multiple items.
  """
  def get_engaged_users_batch(item_ids) do
    with {:ok, bidders_map} <- get_batch_bidders(item_ids),
         {:ok, watchers_map} <- get_batch_watchers(item_ids) do
      engaged_map = merge_engaged_users(bidders_map, watchers_map, item_ids)
      {:ok, engaged_map}
    end
  end

  # Private helpers

  defp get_single_item_bidders(item_id) do
    case Angle.Bidding.Bid
         |> Ash.Query.filter(item_id == ^item_id)
         |> Ash.Query.select([:user_id])
         |> Ash.read(authorize?: false) do
      {:ok, bids} ->
        user_ids = Enum.map(bids, & &1.user_id) |> MapSet.new()
        {:ok, user_ids}

      error ->
        error
    end
  end

  defp get_single_item_watchers(item_id) do
    case Angle.Inventory.WatchlistItem
         |> Ash.Query.filter(item_id == ^item_id)
         |> Ash.Query.select([:user_id])
         |> Ash.read(authorize?: false) do
      {:ok, items} ->
        user_ids = Enum.map(items, & &1.user_id) |> MapSet.new()
        {:ok, user_ids}

      error ->
        error
    end
  end

  defp get_batch_bidders(item_ids) do
    case Angle.Bidding.Bid
         |> Ash.Query.filter(item_id in ^item_ids)
         |> Ash.Query.select([:item_id, :user_id])
         |> Ash.read(authorize?: false) do
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
    case Angle.Inventory.WatchlistItem
         |> Ash.Query.filter(item_id in ^item_ids)
         |> Ash.Query.select([:item_id, :user_id])
         |> Ash.read(authorize?: false) do
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
