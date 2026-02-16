defmodule AngleWeb.BidsController do
  use AngleWeb, :controller

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

    conn
    |> assign_prop(:orders, orders)
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

    # Load won item IDs so frontend can determine outcome
    order_params = %{}

    won_item_ids =
      case AshTypescript.Rpc.run_typed_query(:angle, :won_order_card, order_params, conn) do
        %{"success" => true, "data" => data} ->
          extract_results(data) |> Enum.map(& &1["item"]["id"])

        _ ->
          []
      end

    conn
    |> assign_prop(:bids, bids)
    |> assign_prop(:won_item_ids, won_item_ids)
    |> assign_prop(:tab, "history")
    |> render_inertia("bids")
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
