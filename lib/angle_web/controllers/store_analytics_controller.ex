defmodule AngleWeb.StoreAnalyticsController do
  use AngleWeb, :controller

  require Logger

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]

  def show(conn, %{"id" => item_id}) do
    user = conn.assigns.current_user

    with {:ok, item} <- load_item(item_id, user.id),
         bids <- load_item_bids(conn, item_id),
         blacklist <- load_seller_blacklist(conn),
         stats <- compute_item_stats(item) do
      # Get blacklisted user IDs for easy lookup in frontend
      blacklisted_user_ids = Enum.map(blacklist, & &1["blockedUserId"])

      conn
      |> assign_prop(:item, serialize_item(item))
      |> assign_prop(:bids, bids)
      |> assign_prop(:blacklisted_user_ids, blacklisted_user_ids)
      |> assign_prop(:stats, stats)
      |> render_inertia("store/listings/analytics")
    else
      :not_found ->
        conn
        |> put_flash(:error, "Item not found")
        |> redirect(to: ~p"/store/listings")

      :unauthorized ->
        conn
        |> put_flash(:error, "You are not authorized to view this item's analytics")
        |> redirect(to: ~p"/store/listings")
    end
  end

  defp load_item(item_id, user_id) do
    case Angle.Inventory.get_item(item_id, actor: %{id: user_id}, authorize?: true) do
      {:ok, item} ->
        # Verify the item belongs to the current seller
        if item.created_by_id == user_id do
          {:ok, item}
        else
          :unauthorized
        end

      {:error, %Ash.Error.Query.NotFound{}} ->
        :not_found

      {:error, _} ->
        :unauthorized
    end
  end

  defp load_item_bids(conn, item_id) do
    params = %{
      filter: %{item_id: item_id},
      page: %{limit: 1000, offset: 0, count: false}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :item_analytics_bid, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_seller_blacklist(conn) do
    params = %{
      page: %{limit: 1000, offset: 0, count: false}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_blacklist_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp serialize_item(item) do
    item = Ash.load!(item, [:bid_count, :watcher_count], authorize?: false)

    %{
      "id" => item.id,
      "title" => item.title,
      "slug" => item.slug,
      "currentPrice" => item.current_price && Decimal.to_string(item.current_price),
      "startingPrice" => Decimal.to_string(item.starting_price),
      "auctionStatus" => item.auction_status,
      "publicationStatus" => item.publication_status,
      "startTime" => item.start_time && DateTime.to_iso8601(item.start_time),
      "endTime" => item.end_time && DateTime.to_iso8601(item.end_time),
      "viewCount" => item.view_count || 0,
      "bidCount" => item.bid_count || 0,
      "watcherCount" => item.watcher_count || 0
    }
  end

  defp compute_item_stats(item) do
    item = Ash.load!(item, [:bid_count, :watcher_count], authorize?: false)

    highest_bid =
      if item.current_price do
        Decimal.to_string(item.current_price)
      else
        Decimal.to_string(item.starting_price)
      end

    %{
      "views" => item.view_count || 0,
      "watchers" => item.watcher_count || 0,
      "totalBids" => item.bid_count || 0,
      "highestBid" => highest_bid
    }
  end
end
