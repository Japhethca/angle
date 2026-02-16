defmodule AngleWeb.WatchlistController do
  use AngleWeb, :controller

  require Ash.Query

  def index(conn, params) do
    category_id = params["category"]

    all_items = load_watchlist_items(conn)
    categories = extract_categories(all_items)
    items = filter_by_category(all_items, category_id)
    watchlisted_map = load_watchlisted_map(conn)

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:categories, categories)
    |> assign_prop(:active_category, category_id)
    |> assign_prop(:watchlisted_map, watchlisted_map)
    |> render_inertia("watchlist")
  end

  defp load_watchlist_items(conn) do
    case AshTypescript.Rpc.run_typed_query(:angle, :watchlist_item_card, %{}, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp extract_categories(items) do
    items
    |> Enum.map(& &1["category"])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["id"])
    |> Enum.sort_by(& &1["name"])
  end

  defp filter_by_category(items, nil), do: items

  defp filter_by_category(items, category_id) do
    Enum.filter(items, fn item ->
      get_in(item, ["category", "id"]) == category_id
    end)
  end

  defp load_watchlisted_map(conn) do
    case conn.assigns[:current_user] do
      nil ->
        %{}

      user ->
        Angle.Inventory.WatchlistItem
        |> Ash.Query.for_read(:by_user, %{}, actor: user)
        |> Ash.read!(authorize?: false)
        |> Map.new(fn entry -> {entry.item_id, entry.id} end)
    end
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
