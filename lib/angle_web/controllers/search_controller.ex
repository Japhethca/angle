defmodule AngleWeb.SearchController do
  use AngleWeb, :controller

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]

  alias AngleWeb.ImageHelpers

  @per_page 20

  def index(conn, params) do
    query = params["q"] |> to_string() |> String.trim()
    category = params["category"]
    condition = validate_enum(params["condition"], ~w(new used refurbished))
    sale_type = validate_enum(params["sale_type"], ~w(auction buy_now hybrid))

    auction_status =
      validate_enum(params["auction_status"], ~w(pending scheduled active ended sold))

    min_price = parse_decimal(params["min_price"])
    max_price = parse_decimal(params["max_price"])

    sort =
      validate_enum(params["sort"], ~w(relevance price_asc price_desc newest ending_soon)) ||
        "relevance"

    page = parse_positive_int(params["page"], 1)

    {items, total} =
      if query == "" do
        {[], 0}
      else
        load_search_results(
          conn,
          query,
          %{
            category_id: category,
            condition: condition,
            sale_type: sale_type,
            auction_status: auction_status,
            min_price: min_price,
            max_price: max_price,
            sort_by: sort
          },
          page
        )
      end

    items = ImageHelpers.attach_cover_images(items)
    categories = load_filter_categories(conn)
    total_pages = if total > 0, do: max(1, ceil(total / @per_page)), else: 0

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:query, query)
    |> assign_prop(:pagination, %{
      page: page,
      per_page: @per_page,
      total: total,
      total_pages: total_pages
    })
    |> assign_prop(:filters, %{
      category: category,
      condition: condition,
      sale_type: sale_type,
      auction_status: auction_status,
      min_price: min_price,
      max_price: max_price,
      sort: sort
    })
    |> assign_prop(:categories, categories)
    |> render_inertia("search")
  end

  defp load_search_results(conn, query, filters, page) do
    offset = (page - 1) * @per_page

    input =
      %{query: query}
      |> maybe_put(:category_id, filters.category_id)
      |> maybe_put(:condition, filters.condition)
      |> maybe_put(:sale_type, filters.sale_type)
      |> maybe_put(:auction_status, filters.auction_status)
      |> maybe_put(:min_price, filters.min_price)
      |> maybe_put(:max_price, filters.max_price)
      |> maybe_put(:sort_by, filters.sort_by)

    params = %{
      input: input,
      page: %{limit: @per_page, offset: offset, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :search_item_card, params, conn) do
      %{"success" => true, "data" => %{"results" => results, "count" => count}} ->
        {results, count}

      %{"success" => true, "data" => data} when is_list(data) ->
        {data, length(data)}

      _ ->
        {[], 0}
    end
  end

  defp load_filter_categories(conn) do
    params = %{filter: %{parent_id: %{isNil: true}}}

    case AshTypescript.Rpc.run_typed_query(:angle, :homepage_category, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp validate_enum(nil, _allowed), do: nil

  defp validate_enum(value, allowed) when is_binary(value) do
    if value in allowed, do: value, else: nil
  end

  defp validate_enum(_, _), do: nil

  defp parse_decimal(nil), do: nil

  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> Decimal.to_string(decimal)
      _ -> nil
    end
  end

  defp parse_decimal(_), do: nil

  defp parse_positive_int(nil, default), do: default

  defp parse_positive_int(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_positive_int(_, default), do: default

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
