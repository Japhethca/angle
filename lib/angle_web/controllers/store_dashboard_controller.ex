defmodule AngleWeb.StoreDashboardController do
  use AngleWeb, :controller

  require Logger

  import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1, build_category_summary: 1]

  alias AngleWeb.ImageHelpers

  @valid_statuses ~w(all active ended draft)
  @valid_per_page [10, 25, 50]
  @default_per_page 10
  @valid_sort_fields ~w(inserted_at view_count bid_count watcher_count current_price)
  @default_sort_field "inserted_at"
  @valid_sort_dirs ~w(asc desc)
  @default_sort_dir "desc"

  def index(conn, _params) do
    redirect(conn, to: ~p"/store/listings")
  end

  def new(conn, _params) do
    categories = load_listing_form_categories(conn)
    store_profile = load_store_profile(conn)

    conn
    |> assign_prop(:categories, categories)
    |> assign_prop(:store_profile, store_profile)
    |> render_inertia("store/listings/new")
  end

  def preview(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    case load_draft_item(conn, id, user.id) do
      {:ok, item, images} ->
        seller = serialize_preview_seller(user)

        conn
        |> assign_prop(:item, item)
        |> assign_prop(:images, images)
        |> assign_prop(:seller, seller)
        |> render_inertia("store/listings/preview")

      :not_found ->
        conn
        |> put_flash(:error, "Draft not found")
        |> redirect(to: ~p"/store/listings")
    end
  end

  def edit(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    step = parse_positive_int(params["step"], 1)

    case load_draft_item(conn, id, user.id) do
      {:ok, item, images} ->
        categories = load_listing_form_categories(conn)
        store_profile_data = load_store_profile(conn)

        conn
        |> assign_prop(:item, item)
        |> assign_prop(:images, images)
        |> assign_prop(:categories, categories)
        |> assign_prop(:store_profile, store_profile_data)
        |> assign_prop(:step, step)
        |> render_inertia("store/listings/edit")

      :not_found ->
        conn
        |> put_flash(:error, "Draft not found")
        |> redirect(to: ~p"/store/listings")
    end
  end

  def listings(conn, params) do
    status = validate_status(params["status"])
    page = parse_positive_int(params["page"], 1)
    per_page = validate_per_page(params["per_page"])
    sort = validate_sort_field(params["sort"])
    dir = validate_sort_dir(params["dir"])

    {items, total} = load_seller_items(conn, status, page, per_page, sort, dir)
    items = ImageHelpers.attach_cover_images(items)
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
    |> assign_prop(:sort, sort)
    |> assign_prop(:dir, dir)
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

  def delete_item(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {:ok, item} <- Angle.Inventory.get_item(id, actor: user),
         :ok <- Angle.Inventory.destroy_item(item, actor: user) do
      conn
      |> put_flash(:success, "Item deleted successfully")
      |> redirect(to: ~p"/store/listings")
    else
      {:error, reason} ->
        if not_found_error?(reason) do
          conn
          |> put_flash(:error, "Item not found")
          |> redirect(to: ~p"/store/listings")
        else
          Logger.warning("Failed to delete item #{id}: #{inspect(reason)}")

          conn
          |> put_flash(:error, "Failed to delete item")
          |> redirect(to: ~p"/store/listings")
        end
    end
  end

  def profile(conn, _params) do
    user = conn.assigns.current_user
    {store_profile, logo_url} = load_store_profile_with_logo(user)
    category_summary = build_category_summary(user.id)
    reviews = load_seller_reviews(conn, user.id)

    conn
    |> assign_prop(:store_profile, store_profile)
    |> assign_prop(:logo_url, logo_url)
    |> assign_prop(:category_summary, category_summary)
    |> assign_prop(:user, serialize_user(user))
    |> assign_prop(:reviews, reviews)
    |> render_inertia("store/profile")
  end

  defp load_seller_items(conn, status, page, per_page, sort, dir) do
    offset = (page - 1) * per_page

    params = %{
      input: %{status_filter: status, sort_field: sort, sort_dir: dir},
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

  defp load_seller_reviews(conn, seller_id) do
    params = %{
      input: %{seller_id: seller_id},
      page: %{limit: 100, offset: 0, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_review_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_store_profile_with_logo(user) do
    case Angle.Accounts.get_store_profile_by_user(user.id, not_found_error?: false) do
      {:ok, nil} ->
        {nil, nil}

      {:ok, profile} ->
        logo_url = load_logo_url_for_profile(profile.id)
        {serialize_store_profile(profile), logo_url}

      _ ->
        {nil, nil}
    end
  end

  defp load_logo_url_for_profile(profile_id) do
    AngleWeb.ImageHelpers.load_owner_thumbnail_url(:store_logo, profile_id)
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
    user = Ash.load!(user, [:avg_rating, :review_count], authorize?: false)

    %{
      "id" => user.id,
      "email" => user.email,
      "fullName" => user.full_name,
      "username" => user.username,
      "phoneNumber" => user.phone_number,
      "location" => user.location,
      "createdAt" => user.created_at && DateTime.to_iso8601(user.created_at),
      "avgRating" => user.avg_rating,
      "reviewCount" => user.review_count
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

  defp validate_sort_field(field) when field in @valid_sort_fields, do: field
  defp validate_sort_field(_), do: @default_sort_field

  defp validate_sort_dir(dir) when dir in @valid_sort_dirs, do: dir
  defp validate_sort_dir(_), do: @default_sort_dir

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

  defp load_listing_form_categories(conn) do
    case AshTypescript.Rpc.run_typed_query(:angle, :listing_form_category, %{}, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  # Uses code interface instead of run_typed_query — only a single field is needed,
  # no typed query exists for this use case, and the result is trivially serialized.
  defp load_store_profile(conn) do
    case conn.assigns[:current_user] do
      nil ->
        nil

      user ->
        case Angle.Accounts.get_store_profile_by_user(user.id, not_found_error?: false) do
          {:ok, profile} when not is_nil(profile) ->
            %{"deliveryPreference" => profile.delivery_preference}

          _ ->
            nil
        end
    end
  end

  defp load_draft_item(conn, id, user_id) do
    params = %{
      filter: %{id: id, created_by_id: user_id, publication_status: "draft"},
      page: %{limit: 1}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :item_detail, params, conn) do
      %{"success" => true, "data" => data} ->
        case extract_results(data) do
          [item | _] ->
            images = AngleWeb.ImageHelpers.load_item_images(id)
            {:ok, item, images}

          _ ->
            :not_found
        end

      _ ->
        :not_found
    end
  end

  defp serialize_preview_seller(user) do
    %{
      "id" => user.id,
      "fullName" => user.full_name,
      "username" => user.username
    }
  end

  defp not_found_error?(%Ash.Error.Invalid{errors: errors}) do
    Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1))
  end

  defp not_found_error?(_), do: false
end
