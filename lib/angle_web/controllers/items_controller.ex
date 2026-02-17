defmodule AngleWeb.ItemsController do
  use AngleWeb, :controller
  require Ash.Query

  alias AngleWeb.ImageHelpers

  @published_filter %{publication_status: "published"}

  def new(conn, _params) do
    categories = load_listing_form_categories(conn)
    store_profile = load_store_profile(conn)

    conn
    |> assign_prop(:categories, categories)
    |> assign_prop(:store_profile, store_profile)
    |> render_inertia("items/new")
  end

  def show(conn, %{"slug" => slug_or_id}) do
    filter = build_item_filter(slug_or_id)

    case run_item_detail_query(conn, filter) do
      {:ok, item} ->
        similar_items =
          load_similar_items(conn, item["id"], item["category"] && item["category"]["id"])
          |> ImageHelpers.attach_cover_images()

        seller = load_seller(conn, item["createdById"])
        images = ImageHelpers.load_item_images(item["id"])

        item =
          item
          |> Map.put("user", seller)
          |> Map.put("images", images)

        conn
        |> assign_prop(:item, item)
        |> assign_prop(:similar_items, similar_items)
        |> assign_prop(:watchlist_entry_id, load_watchlist_entry_id(conn, item["id"]))
        |> render_inertia("items/show")

      :not_found ->
        conn
        |> put_flash(:error, "Item not found")
        |> redirect(to: "/")
    end
  end

  defp build_item_filter(slug_or_id) do
    base = @published_filter

    if uuid?(slug_or_id) do
      Map.put(base, :id, slug_or_id)
    else
      Map.put(base, :slug, slug_or_id)
    end
  end

  defp run_item_detail_query(conn, filter) do
    params = %{filter: filter, page: %{limit: 1}}

    case AshTypescript.Rpc.run_typed_query(:angle, :item_detail, params, conn) do
      %{"success" => true, "data" => data} ->
        case extract_results(data) do
          [item | _] -> {:ok, item}
          _ -> :not_found
        end

      _ ->
        :not_found
    end
  end

  defp load_seller(conn, user_id) when is_binary(user_id) do
    params = %{input: %{user_id: user_id}, page: %{limit: 1}}

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_profile, params, conn) do
      %{"success" => true, "data" => data} ->
        case extract_results(data) do
          [seller | _] -> seller
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp load_seller(_conn, _user_id), do: nil

  defp load_similar_items(conn, current_item_id, category_id)
       when is_binary(current_item_id) and is_binary(category_id) do
    filter =
      Map.merge(@published_filter, %{
        category_id: %{eq: category_id},
        id: %{notEq: current_item_id}
      })

    params = %{filter: filter, page: %{limit: 6}}

    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_item_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_similar_items(_conn, _current_item_id, _category_id), do: []

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []

  defp load_watchlist_entry_id(conn, item_id) when is_binary(item_id) do
    case conn.assigns[:current_user] do
      nil ->
        nil

      user ->
        Angle.Inventory.WatchlistItem
        |> Ash.Query.for_read(:by_user, %{}, actor: user)
        |> Ash.Query.filter(item_id == ^item_id)
        |> Ash.read!(authorize?: false)
        |> case do
          [entry | _] -> entry.id
          _ -> nil
        end
    end
  end

  defp load_watchlist_entry_id(_conn, _item_id), do: nil

  defp uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp load_listing_form_categories(conn) do
    case AshTypescript.Rpc.run_typed_query(:angle, :listing_form_category, %{}, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_store_profile(conn) do
    case conn.assigns[:current_user] do
      nil ->
        nil

      user ->
        case Angle.Accounts.StoreProfile
             |> Ash.Query.filter(user_id == ^user.id)
             |> Ash.read_one(authorize?: false) do
          {:ok, nil} ->
            nil

          {:ok, profile} ->
            %{"deliveryPreference" => profile.delivery_preference}

          _ ->
            nil
        end
    end
  end
end
