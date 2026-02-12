defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  @published_filter %{publication_status: "published"}

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    featured_items = run_item_query(conn, @published_filter, nil, %{limit: 5})
    recommended_items = run_item_query(conn, @published_filter, nil, %{limit: 8})

    ending_soon_items =
      run_item_query(conn, @published_filter, "++end_time", %{limit: 8})

    hot_items =
      run_item_query(conn, @published_filter, "--view_count", %{limit: 8})

    categories = run_category_query(conn)

    conn
    |> assign_prop(:featured_items, featured_items)
    |> assign_prop(:recommended_items, recommended_items)
    |> assign_prop(:ending_soon_items, ending_soon_items)
    |> assign_prop(:hot_items, hot_items)
    |> assign_prop(:categories, categories)
    |> render_inertia(:home)
  end

  defp run_item_query(conn, filter, sort, page) do
    params = %{filter: filter, sort: sort, page: page}

    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_item_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp run_category_query(conn) do
    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_category, %{}, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
