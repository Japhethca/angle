defmodule AngleWeb.WatchlistController do
  use AngleWeb, :controller

  require Ash.Query

  def index(conn, params) do
    category_id = params["category"]

    items = load_watchlist_items(conn, category_id)
    categories = load_top_categories()
    watchlisted_map = load_watchlisted_map(conn)

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:categories, categories)
    |> assign_prop(:active_category, category_id)
    |> assign_prop(:watchlisted_map, watchlisted_map)
    |> render_inertia("watchlist")
  end

  defp load_watchlist_items(conn, category_id) do
    query_params = %{
      filter: build_filter(category_id)
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :watchlist_item_card, query_params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp build_filter(nil), do: %{}
  defp build_filter(category_id), do: %{category_id: category_id}

  defp load_top_categories do
    Angle.Catalog.Category
    |> Ash.Query.filter(is_nil(parent_id))
    |> Ash.Query.sort(:name)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn cat -> %{id: cat.id, name: cat.name, slug: cat.slug} end)
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
