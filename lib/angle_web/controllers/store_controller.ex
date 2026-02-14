defmodule AngleWeb.StoreController do
  use AngleWeb, :controller

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
        status_filter = if tab == "history", do: :history, else: :active
        {items, has_more} = load_seller_items(conn, seller["id"], status_filter)
        category_summary = build_category_summary(conn, seller["id"])

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

  # NOTE: Fetches up to 200 items for category grouping. For sellers with
  # more than 200 published items, counts may be approximate. Consider
  # replacing with a dedicated aggregate query in a future iteration.
  defp build_category_summary(conn, seller_id) do
    params = %{
      input: %{seller_id: seller_id},
      page: %{limit: 200, offset: 0, count: false}
    }

    items =
      case AshTypescript.Rpc.run_typed_query(:angle, :seller_item_card, params, conn) do
        %{"success" => true, "data" => %{"results" => results}} -> results
        %{"success" => true, "data" => data} when is_list(data) -> data
        _ -> []
      end

    items
    |> Enum.group_by(fn item -> item["category"] end)
    |> Enum.map(fn {category, items} ->
      %{
        "id" => category && category["id"],
        "name" => category && category["name"],
        "slug" => category && category["slug"],
        "count" => length(items)
      }
    end)
    |> Enum.reject(fn cat -> is_nil(cat["id"]) end)
    |> Enum.sort_by(fn cat -> -cat["count"] end)
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
