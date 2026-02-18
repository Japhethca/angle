defmodule AngleWeb.WatchlistController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1, load_watchlisted_map: 1]

  alias AngleWeb.ImageHelpers

  def index(conn, params) do
    category_id = params["category"]

    all_items =
      load_watchlist_items(conn)
      |> ImageHelpers.attach_cover_images()

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
end
