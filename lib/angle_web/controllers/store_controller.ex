defmodule AngleWeb.StoreController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers,
    only: [extract_results: 1, load_watchlisted_map: 1, build_category_summary: 1]

  alias AngleWeb.ImageHelpers

  @items_per_page 20

  @valid_tabs ~w(auctions history reviews)

  def show(conn, %{"identifier" => identifier} = params) do
    case load_seller(conn, identifier) do
      nil ->
        conn
        |> put_flash(:error, "Seller not found")
        |> redirect(to: "/")

      seller ->
        tab = validate_tab(params["tab"])
        category_summary = build_category_summary(seller["id"])
        logo_url = load_seller_logo_url(seller["id"])

        conn =
          conn
          |> assign_prop(:seller, seller)
          |> assign_prop(:logo_url, logo_url)
          |> assign_prop(:category_summary, category_summary)
          |> assign_prop(:active_tab, tab)
          |> assign_prop(:watchlisted_map, load_watchlisted_map(conn))

        case tab do
          "reviews" ->
            reviews = load_seller_reviews(conn, seller["id"])

            conn
            |> assign_prop(:items, [])
            |> assign_prop(:has_more, false)
            |> assign_prop(:reviews, reviews)
            |> render_inertia("store/show")

          _ ->
            {items, has_more} =
              case tab do
                "history" -> load_seller_items(conn, seller["id"], :history)
                _ -> load_seller_items(conn, seller["id"], :active)
              end

            items = ImageHelpers.attach_cover_images(items)

            conn
            |> assign_prop(:items, items)
            |> assign_prop(:has_more, has_more)
            |> assign_prop(:reviews, [])
            |> render_inertia("store/show")
        end
    end
  end

  defp validate_tab(tab) when tab in @valid_tabs, do: tab
  defp validate_tab(_), do: "auctions"

  defp load_seller(conn, identifier) do
    params =
      if uuid?(identifier) do
        %{input: %{user_id: identifier}, page: %{limit: 1}}
      else
        %{input: %{username: identifier}, page: %{limit: 1}}
      end

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

  defp load_seller_items(conn, seller_id, status_filter) do
    params = %{
      input: %{seller_id: seller_id, status_filter: Atom.to_string(status_filter)},
      page: %{limit: @items_per_page, offset: 0, count: false}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_item_card, params, conn) do
      %{"success" => true, "data" => %{"results" => results, "hasMore" => has_more}} ->
        {results, has_more}

      %{"success" => true, "data" => data} when is_list(data) ->
        {data, false}

      _ ->
        {[], false}
    end
  end

  defp load_seller_reviews(conn, seller_id) do
    params = %{
      input: %{seller_id: seller_id},
      page: %{limit: @items_per_page, offset: 0, count: false}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_review_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_seller_logo_url(seller_id) do
    case Angle.Accounts.get_store_profile_by_user(seller_id) do
      {:ok, nil} -> nil
      {:ok, profile} -> ImageHelpers.load_owner_thumbnail_url(:store_logo, profile.id)
      _ -> nil
    end
  end

  defp uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
