defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1, load_watchlisted_map: 1]

  alias AngleWeb.ImageHelpers

  @published_filter %{publication_status: "published"}

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    featured_items =
      run_item_query(conn, @published_filter, nil, %{limit: 5})
      |> ImageHelpers.attach_cover_images()

    recommended_items = load_recommended_items(conn)

    ending_soon_items =
      run_item_query(conn, @published_filter, "++end_time", %{limit: 8})
      |> ImageHelpers.attach_cover_images()

    hot_items =
      run_item_query(conn, @published_filter, "--view_count", %{limit: 8})
      |> ImageHelpers.attach_cover_images()

    categories = run_category_query(conn)

    conn
    |> assign_prop(:featured_items, featured_items)
    |> assign_prop(:recommended_items, recommended_items)
    |> assign_prop(:ending_soon_items, ending_soon_items)
    |> assign_prop(:hot_items, hot_items)
    |> assign_prop(:categories, categories)
    |> assign_prop(:watchlisted_map, load_watchlisted_map(conn))
    |> render_inertia(:home)
  end

  def terms(conn, _params) do
    conn |> render_inertia(:terms)
  end

  def privacy(conn, _params) do
    conn |> render_inertia(:privacy)
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

  defp load_recommended_items(conn) do
    items =
      if Map.has_key?(conn.assigns, :current_user) and conn.assigns.current_user do
        # Authenticated users: personalized recommendations based on interests
        user_id = conn.assigns.current_user.id
        Angle.Recommendations.get_homepage_recommendations(user_id, limit: 8)
      else
        # Guest users: popular items based on bids/watchers
        Angle.Recommendations.get_popular_items(limit: 8)
      end

    ImageHelpers.attach_cover_images(items)
  end
end
