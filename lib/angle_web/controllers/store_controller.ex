defmodule AngleWeb.StoreController do
  use AngleWeb, :controller
  require Ash.Query

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

        {items, has_more} =
          case tab do
            "reviews" -> {[], false}
            "history" -> load_seller_items(conn, seller["id"], :history)
            _ -> load_seller_items(conn, seller["id"], :active)
          end

        category_summary = build_category_summary(seller["id"])

        conn
        |> assign_prop(:seller, seller)
        |> assign_prop(:items, items)
        |> assign_prop(:has_more, has_more)
        |> assign_prop(:category_summary, category_summary)
        |> assign_prop(:active_tab, tab)
        |> render_inertia("store/show")
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

  defp build_category_summary(seller_id) do
    item_query =
      Angle.Inventory.Item
      |> Ash.Query.filter(created_by_id == ^seller_id and publication_status == :published)

    Angle.Catalog.Category
    |> Ash.Query.aggregate(:item_count, :count, :items, query: item_query)
    |> Ash.read!(authorize?: false)
    |> Enum.filter(fn cat -> cat.aggregates[:item_count] > 0 end)
    |> Enum.sort_by(fn cat -> -cat.aggregates[:item_count] end)
    |> Enum.map(fn cat ->
      %{
        "id" => cat.id,
        "name" => cat.name,
        "slug" => cat.slug,
        "count" => cat.aggregates[:item_count]
      }
    end)
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []

  defp uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
