defmodule AngleWeb.BidsController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]

  alias AngleWeb.ImageHelpers

  def index(conn, params) do
    tab = Map.get(params, "tab", "active")
    user = conn.assigns.current_user

    case tab do
      "won" -> load_won_tab(conn, user)
      "history" -> load_history_tab(conn, user)
      _ -> load_active_tab(conn, user)
    end
  end

  defp load_active_tab(conn, user) do
    params = %{
      filter: %{
        user_id: %{eq: user.id},
        item: %{auction_status: %{in: ["active", "scheduled"]}}
      },
      sort: "--bid_time"
    }

    bids =
      case AshTypescript.Rpc.run_typed_query(:angle, :active_bid_card, params, conn) do
        %{"success" => true, "data" => data} -> extract_results(data)
        _ -> []
      end
      |> ImageHelpers.attach_nested_cover_images("item")

    conn
    |> assign_prop(:bids, bids)
    |> assign_prop(:tab, "active")
    |> render_inertia("bids")
  end

  defp load_won_tab(conn, _user) do
    params = %{sort: "--created_at"}

    orders =
      case AshTypescript.Rpc.run_typed_query(:angle, :won_order_card, params, conn) do
        %{"success" => true, "data" => data} -> extract_results(data)
        _ -> []
      end
      |> ImageHelpers.attach_nested_cover_images("item")

    # Load existing reviews for the buyer's orders
    order_ids = Enum.map(orders, fn o -> o["id"] end)

    reviews_by_order =
      if order_ids != [] do
        reviews = Angle.Bidding.list_reviews_by_order_ids!(order_ids, authorize?: false)

        Map.new(reviews, fn r ->
          {r.order_id,
           %{
             "id" => r.id,
             "orderId" => r.order_id,
             "rating" => r.rating,
             "comment" => r.comment,
             "insertedAt" => r.inserted_at && DateTime.to_iso8601(r.inserted_at)
           }}
        end)
      else
        %{}
      end

    conn
    |> assign_prop(:orders, orders)
    |> assign_prop(:reviews_by_order, reviews_by_order)
    |> assign_prop(:tab, "won")
    |> render_inertia("bids")
  end

  defp load_history_tab(conn, user) do
    bid_params = %{
      filter: %{
        user_id: %{eq: user.id},
        item: %{auction_status: %{in: ["ended", "sold", "cancelled"]}}
      },
      sort: "--bid_time"
    }

    bids =
      case AshTypescript.Rpc.run_typed_query(:angle, :history_bid_card, bid_params, conn) do
        %{"success" => true, "data" => data} -> extract_results(data)
        _ -> []
      end
      |> ImageHelpers.attach_nested_cover_images("item")

    # Load won item IDs so frontend can determine outcome
    orders = Angle.Bidding.list_buyer_won_item_ids!(actor: user, authorize?: false)
    won_item_ids = Enum.map(orders, & &1.item_id)

    conn
    |> assign_prop(:bids, bids)
    |> assign_prop(:won_item_ids, won_item_ids)
    |> assign_prop(:tab, "history")
    |> render_inertia("bids")
  end
end
