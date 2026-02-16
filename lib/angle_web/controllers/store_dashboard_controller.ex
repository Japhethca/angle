defmodule AngleWeb.StoreDashboardController do
  use AngleWeb, :controller

  require Ash.Query

  @valid_statuses ~w(all active ended draft)
  @valid_per_page [10, 25, 50]
  @default_per_page 10

  def index(conn, _params) do
    redirect(conn, to: ~p"/store/listings")
  end

  def listings(conn, params) do
    status = validate_status(params["status"])
    page = parse_positive_int(params["page"], 1)
    per_page = validate_per_page(params["per_page"])

    {items, total} = load_seller_items(conn, status, page, per_page)
    stats = load_seller_stats(conn)
    total_pages = max(1, ceil(total / per_page))

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:stats, stats)
    |> assign_prop(:pagination, %{
      page: page,
      per_page: per_page,
      total: total,
      total_pages: total_pages
    })
    |> assign_prop(:status, status)
    |> render_inertia("store/listings")
  end

  def payments(conn, _params) do
    orders = load_seller_orders(conn)
    balance = compute_balance(orders)

    conn
    |> assign_prop(:orders, orders)
    |> assign_prop(:balance, balance)
    |> render_inertia("store/payments")
  end

  def profile(conn, _params) do
    user = conn.assigns.current_user
    store_profile = load_store_profile(user)
    category_summary = build_category_summary(user.id)

    conn
    |> assign_prop(:store_profile, store_profile)
    |> assign_prop(:category_summary, category_summary)
    |> assign_prop(:user, serialize_user(user))
    |> render_inertia("store/profile")
  end

  defp load_seller_items(conn, status, page, per_page) do
    offset = (page - 1) * per_page

    params = %{
      input: %{status_filter: status},
      page: %{limit: per_page, offset: offset, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_dashboard_card, params, conn) do
      %{"success" => true, "data" => %{"results" => results, "count" => count}} ->
        {results, count}

      %{"success" => true, "data" => data} when is_list(data) ->
        {data, length(data)}

      _ ->
        {[], 0}
    end
  end

  # Stats are computed from up to 1000 items in memory (unfiltered).
  # For sellers with more items, consider a dedicated aggregate query.
  defp load_seller_stats(conn) do
    params = %{
      page: %{limit: 1000, offset: 0, count: false}
    }

    items =
      case AshTypescript.Rpc.run_typed_query(:angle, :seller_dashboard_card, params, conn) do
        %{"success" => true, "data" => data} -> extract_results(data)
        _ -> []
      end

    compute_stats(items)
  end

  defp load_seller_orders(conn) do
    params = %{
      page: %{limit: 100, offset: 0, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_payment_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_store_profile(user) do
    case Angle.Accounts.StoreProfile
         |> Ash.Query.filter(user_id == ^user.id)
         |> Ash.read_one(authorize?: false) do
      {:ok, nil} -> nil
      {:ok, profile} -> serialize_store_profile(profile)
      _ -> nil
    end
  end

  defp build_category_summary(user_id) do
    item_query =
      Angle.Inventory.Item
      |> Ash.Query.filter(created_by_id == ^user_id and publication_status == :published)

    Angle.Catalog.Category
    |> Ash.Query.aggregate(:item_count, :count, :items, query: item_query, default: 0)
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

  defp compute_stats(items) do
    %{
      "total_views" => sum_field(items, "viewCount"),
      "total_watches" => sum_field(items, "watcherCount"),
      "total_bids" => sum_field(items, "bidCount"),
      "total_amount" => sum_decimal_field(items, "currentPrice")
    }
  end

  defp compute_balance(orders) do
    paid_statuses = ["paid", "dispatched", "completed"]

    paid_total =
      orders
      |> Enum.filter(fn o -> o["status"] in paid_statuses end)
      |> sum_decimal_field("amount")

    pending_total =
      orders
      |> Enum.filter(fn o -> o["status"] == "payment_pending" end)
      |> sum_decimal_field("amount")

    %{"balance" => paid_total, "pending" => pending_total}
  end

  defp sum_field(items, field) do
    Enum.reduce(items, 0, fn item, acc ->
      acc + (item[field] || 0)
    end)
  end

  defp sum_decimal_field(items, field) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      case item[field] do
        value when is_binary(value) -> Decimal.add(acc, Decimal.new(value))
        _ -> acc
      end
    end)
    |> Decimal.to_string()
  end

  defp serialize_user(user) do
    %{
      "id" => user.id,
      "email" => user.email,
      "fullName" => user.full_name,
      "username" => user.username,
      "phoneNumber" => user.phone_number,
      "location" => user.location,
      "createdAt" => user.created_at && DateTime.to_iso8601(user.created_at)
    }
  end

  defp serialize_store_profile(nil), do: nil

  defp serialize_store_profile(profile) do
    %{
      "id" => profile.id,
      "storeName" => profile.store_name,
      "contactPhone" => profile.contact_phone,
      "whatsappLink" => profile.whatsapp_link,
      "location" => profile.location,
      "address" => profile.address,
      "deliveryPreference" => profile.delivery_preference
    }
  end

  defp validate_status(status) when status in @valid_statuses, do: status
  defp validate_status(_), do: "all"

  defp validate_per_page(per_page) do
    case parse_positive_int(per_page, @default_per_page) do
      val when val in @valid_per_page -> val
      _ -> @default_per_page
    end
  end

  defp parse_positive_int(nil, default), do: default

  defp parse_positive_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, ""} when n > 0 -> n
      _ -> default
    end
  end

  defp parse_positive_int(val, _default) when is_integer(val) and val > 0, do: val
  defp parse_positive_int(_, default), do: default

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
