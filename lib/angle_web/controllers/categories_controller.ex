defmodule AngleWeb.CategoriesController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]

  alias AngleWeb.ImageHelpers

  @items_per_page 20

  def index(conn, _params) do
    categories = load_top_level_categories(conn)

    conn
    |> assign_prop(:categories, categories)
    |> render_inertia("categories/index")
  end

  def show(conn, %{"slug" => slug}) do
    case load_parent_category(conn, slug) do
      nil ->
        conn |> put_flash(:error, "Category not found") |> redirect(to: "/categories")

      category ->
        subcategories = Map.get(category, "categories", [])
        subcategory_ids = Enum.map(subcategories, & &1["id"])
        all_ids = [category["id"] | subcategory_ids]

        {items, has_more} = load_items_by_category(conn, all_ids)
        items = ImageHelpers.attach_cover_images(items)

        conn
        |> assign_prop(:category, category)
        |> assign_prop(:subcategories, subcategories)
        |> assign_prop(:items, items)
        |> assign_prop(:has_more, has_more)
        |> assign_prop(:active_subcategory, nil)
        |> assign_prop(:watchlisted_map, load_watchlisted_map(conn))
        |> render_inertia("categories/show")
    end
  end

  def show_subcategory(conn, %{"slug" => slug, "sub_slug" => sub_slug}) do
    case load_parent_category(conn, slug) do
      nil ->
        conn |> put_flash(:error, "Category not found") |> redirect(to: "/categories")

      category ->
        subcategories = Map.get(category, "categories", [])
        subcategory = Enum.find(subcategories, &(&1["slug"] == sub_slug))

        if subcategory do
          {items, has_more} = load_items_by_category(conn, [subcategory["id"]])
          items = ImageHelpers.attach_cover_images(items)

          conn
          |> assign_prop(:category, category)
          |> assign_prop(:subcategories, subcategories)
          |> assign_prop(:items, items)
          |> assign_prop(:has_more, has_more)
          |> assign_prop(:active_subcategory, sub_slug)
          |> assign_prop(:watchlisted_map, load_watchlisted_map(conn))
          |> render_inertia("categories/show")
        else
          conn
          |> put_flash(:error, "Subcategory not found")
          |> redirect(to: "/categories/#{slug}")
        end
    end
  end

  defp load_top_level_categories(conn) do
    params = %{filter: %{parent_id: %{isNil: true}}}

    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_category, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_parent_category(conn, slug) do
    params = %{filter: %{slug: slug}, page: %{limit: 1}}

    case AshTypescript.Rpc.run_typed_query(:angle, :nav_category, params, conn) do
      %{"success" => true, "data" => data} ->
        case extract_results(data) do
          [category | _] -> category
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp load_items_by_category(conn, category_ids) do
    params = %{
      input: %{category_ids: category_ids},
      page: %{limit: @items_per_page, offset: 0, count: false}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :category_item_card, params, conn) do
      %{"success" => true, "data" => %{"results" => results, "hasMore" => has_more}} ->
        {results, has_more}

      %{"success" => true, "data" => data} when is_list(data) ->
        {data, false}

      _ ->
        {[], false}
    end
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
end
