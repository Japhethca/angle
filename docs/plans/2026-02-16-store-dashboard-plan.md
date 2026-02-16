# Store Dashboard Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a seller management dashboard at `/store/*` with Listings, Payments, and Store Profile tabs.

**Architecture:** Three Inertia pages sharing a `<StoreLayout>` component (sidebar on desktop, tabs on mobile). Each page has its own controller action loading data via typed queries. Follows the existing `<SettingsLayout>` pattern.

**Tech Stack:** Phoenix controllers + Inertia.js, Ash typed queries, React + shadcn/ui + Tailwind, TanStack Query for mutations.

**Design doc:** `docs/plans/2026-02-16-store-dashboard-design.md`

**Figma nodes (file: `jk9qoWNcSpgUa8lsj7uXa9`):**
- Listings desktop: `662-8377`, `664-12133` | mobile: `722-9486`, `722-11279`
- Payments desktop: `664-12614` | mobile: `722-10717`
- Store Profile desktop: `664-13079` | mobile: `722-10433`

---

## Task 1: Add `seller_orders` read action to Order resource

**Files:**
- Modify: `lib/angle/bidding/order.ex`
- Test: `test/angle/bidding/order_test.exs`

**Step 1: Write the test**

Create `test/angle/bidding/order_test.exs`:

```elixir
defmodule Angle.Bidding.OrderTest do
  use Angle.DataCase, async: true

  describe "seller_orders" do
    test "returns orders where user is the seller" do
      seller = create_user()
      buyer = create_user()
      other_seller = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      item2 = create_item(%{created_by_id: other_seller.id})

      order1 = create_order(%{buyer: buyer, seller: seller, item: item1})
      _order2 = create_order(%{buyer: buyer, seller: other_seller, item: item2})

      results =
        Angle.Bidding.Order
        |> Ash.Query.for_read(:seller_orders, %{}, actor: seller)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == order1.id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/bidding/order_test.exs --max-failures 1`
Expected: FAIL — `:seller_orders` action doesn't exist

**Step 3: Add the `seller_orders` action and policy**

In `lib/angle/bidding/order.ex`, inside the `actions` block after `buyer_orders`:

```elixir
read :seller_orders do
  description "List orders for the current seller"
  filter expr(seller_id == ^actor(:id))
  prepare build(sort: [created_at: :desc])
  pagination offset?: true, required?: false
end
```

In the `policies` block, add:

```elixir
policy action(:seller_orders) do
  authorize_if always()
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/angle/bidding/order_test.exs`
Expected: PASS

**Step 5: Commit**

```
git add lib/angle/bidding/order.ex test/angle/bidding/order_test.exs
git commit -m "feat: add seller_orders read action to Order resource"
```

---

## Task 2: Add `my_listings` read action to Item resource

**Files:**
- Modify: `lib/angle/inventory/item.ex`
- Test: `test/angle/inventory/item_test.exs` (add to existing or create)

**Step 1: Write the test**

Add to or create `test/angle/inventory/item_test.exs`:

```elixir
defmodule Angle.Inventory.ItemTest do
  use Angle.DataCase, async: true

  describe "my_listings" do
    test "returns all items owned by the current user regardless of status" do
      seller = create_user()
      other = create_user()

      item1 = create_item(%{created_by_id: seller.id})
      _item2 = create_item(%{created_by_id: other.id})

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:my_listings, %{}, actor: seller)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == item1.id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/inventory/item_test.exs --max-failures 1`
Expected: FAIL — `:my_listings` action doesn't exist

**Step 3: Add the `my_listings` action**

In `lib/angle/inventory/item.ex`, inside the `actions` block:

```elixir
read :my_listings do
  description "List all items owned by the current user (for seller dashboard)"
  filter expr(created_by_id == ^actor(:id))
  prepare build(sort: [inserted_at: :desc])
  pagination offset?: true, required?: false
end
```

Add a policy for it (in the `policies` block):

```elixir
policy action(:my_listings) do
  authorize_if always()
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/angle/inventory/item_test.exs`
Expected: PASS

**Step 5: Commit**

```
git add lib/angle/inventory/item.ex test/angle/inventory/item_test.exs
git commit -m "feat: add my_listings read action to Item resource"
```

---

## Task 3: Add typed queries and run codegen

**Files:**
- Modify: `lib/angle/inventory.ex` — add `seller_dashboard_card` typed query
- Modify: `lib/angle/bidding.ex` — add `seller_payment_card` typed query and `list_seller_orders` RPC action
- Regenerate: `assets/js/ash_rpc.ts`

**Step 1: Add `seller_dashboard_card` typed query to Inventory domain**

In `lib/angle/inventory.ex`, inside the `resource Angle.Inventory.Item` block within `typescript_rpc`, add after the existing typed queries:

```elixir
rpc_action :list_my_listings, :my_listings

typed_query :seller_dashboard_card, :my_listings do
  ts_result_type_name "SellerDashboardCard"
  ts_fields_const_name "sellerDashboardCardFields"

  fields [
    :id,
    :title,
    :slug,
    :starting_price,
    :current_price,
    :end_time,
    :auction_status,
    :publication_status,
    :condition,
    :sale_type,
    :view_count,
    :bid_count,
    :watcher_count,
    %{category: [:id, :name]}
  ]
end
```

**Step 2: Add `seller_payment_card` typed query to Bidding domain**

In `lib/angle/bidding.ex`, inside the `resource Angle.Bidding.Order` block within `typescript_rpc`, add:

```elixir
rpc_action :list_seller_orders, :seller_orders

typed_query :seller_payment_card, :seller_orders do
  ts_result_type_name "SellerPaymentCard"
  ts_fields_const_name "sellerPaymentCardFields"

  fields [
    :id,
    :status,
    :amount,
    :payment_reference,
    :created_at,
    %{
      item: [
        :id,
        :title
      ]
    }
  ]
end
```

**Step 3: Run Ash codegen**

Run: `mix ash.codegen --dev`
Then: `mix ash_typescript.codegen`

Verify `assets/js/ash_rpc.ts` now contains `SellerDashboardCard` and `SellerPaymentCard` types.

**Step 4: Commit**

```
git add lib/angle/inventory.ex lib/angle/bidding.ex assets/js/ash_rpc.ts
git commit -m "feat: add seller dashboard and payment typed queries"
```

---

## Task 4: Add StoreDashboardController and routes

**Files:**
- Create: `lib/angle_web/controllers/store_dashboard_controller.ex`
- Modify: `lib/angle_web/router.ex`
- Test: `test/angle_web/controllers/store_dashboard_controller_test.exs`

**Step 1: Write the test**

Create `test/angle_web/controllers/store_dashboard_controller_test.exs`:

```elixir
defmodule AngleWeb.StoreDashboardControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /store" do
    test "redirects to /store/listings", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store")

      assert redirected_to(conn) == ~p"/store/listings"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/payments" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/payments")

      assert html_response(conn, 200) =~ "store/payments"
    end
  end

  describe "GET /store/profile" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/profile")

      assert html_response(conn, 200) =~ "store/profile"
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs --max-failures 1`
Expected: FAIL — routes/controller don't exist

**Step 3: Create the controller**

Create `lib/angle_web/controllers/store_dashboard_controller.ex`:

```elixir
defmodule AngleWeb.StoreDashboardController do
  use AngleWeb, :controller

  require Ash.Query

  def index(conn, _params) do
    redirect(conn, to: ~p"/store/listings")
  end

  def listings(conn, _params) do
    items = load_seller_items(conn)
    stats = compute_stats(items)

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:stats, stats)
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

  # Data loading

  defp load_seller_items(conn) do
    params = %{
      page: %{limit: 100, offset: 0, count: true}
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :seller_dashboard_card, params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp load_seller_orders(conn) do
    params = %{}

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

  # Stats computation

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

  defp sum_decimal_field(items, field) when is_list(items) do
    items
    |> Enum.reduce(Decimal.new(0), fn item, acc ->
      value = item[field]

      cond do
        is_binary(value) -> Decimal.add(acc, Decimal.new(value))
        true -> acc
      end
    end)
    |> Decimal.to_string()
  end

  defp sum_decimal_field(items, field) do
    Enum.reduce(items, Decimal.new(0), fn item, acc ->
      value = item[field]

      cond do
        is_binary(value) -> Decimal.add(acc, Decimal.new(value))
        true -> acc
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
      "createdAt" => user.inserted_at && DateTime.to_iso8601(user.inserted_at)
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

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
```

**Step 4: Add routes**

In `lib/angle_web/router.ex`, inside the protected routes scope (`scope "/", AngleWeb do pipe_through [:browser, :require_auth]`), add before the existing settings routes:

```elixir
get "/store", StoreDashboardController, :index
get "/store/listings", StoreDashboardController, :listings
get "/store/payments", StoreDashboardController, :payments
get "/store/profile", StoreDashboardController, :profile
```

**IMPORTANT:** These must be placed BEFORE the public `get "/store/:identifier"` route in the public scope, OR (better) placed in the protected scope. Since they're in the protected scope already, they'll match first due to route ordering. However, verify that the router processes the protected scope before the public one for `/store` paths. If there's a conflict with the public `/store/:identifier`, the protected routes should be listed first in the router file.

**Step 5: Create placeholder React pages**

Create minimal placeholder pages so the controller can render them:

`assets/js/pages/store/listings.tsx`:
```tsx
import { Head } from "@inertiajs/react";

export default function StoreListings() {
  return (
    <>
      <Head title="Store - Listings" />
      <div>Store Listings placeholder</div>
    </>
  );
}
```

`assets/js/pages/store/payments.tsx`:
```tsx
import { Head } from "@inertiajs/react";

export default function StorePayments() {
  return (
    <>
      <Head title="Store - Payments" />
      <div>Store Payments placeholder</div>
    </>
  );
}
```

`assets/js/pages/store/profile.tsx`:
```tsx
import { Head } from "@inertiajs/react";

export default function StoreProfile() {
  return (
    <>
      <Head title="Store - Profile" />
      <div>Store Profile placeholder</div>
    </>
  );
}
```

**Step 6: Run tests**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs`
Expected: PASS

**Step 7: Commit**

```
git add lib/angle_web/controllers/store_dashboard_controller.ex lib/angle_web/router.ex test/angle_web/controllers/store_dashboard_controller_test.exs assets/js/pages/store/listings.tsx assets/js/pages/store/payments.tsx assets/js/pages/store/profile.tsx
git commit -m "feat: add StoreDashboardController with routes and placeholder pages"
```

---

## Task 5: Create StoreLayout component

**Files:**
- Create: `assets/js/features/store-dashboard/components/store-layout.tsx`
- Create: `assets/js/features/store-dashboard/index.ts`

**Reference:** `assets/js/features/settings/components/settings-layout.tsx` for the pattern.

**Step 1: Create the StoreLayout component**

Create `assets/js/features/store-dashboard/components/store-layout.tsx`:

```tsx
import { Link, usePage } from "@inertiajs/react";
import {
  ArrowLeft,
  ChevronRight,
  Package,
  Wallet,
  Store,
  HelpCircle,
} from "lucide-react";
import { cn } from "@/lib/utils";

const storeMenuItems = [
  { label: "Listings", href: "/store/listings", icon: Package },
  { label: "Payments", href: "/store/payments", icon: Wallet },
  { label: "Store Profile", href: "/store/profile", icon: Store },
];

interface StoreLayoutProps {
  title: string;
  children: React.ReactNode;
}

export function StoreLayout({ title, children }: StoreLayoutProps) {
  const { url } = usePage();

  return (
    <>
      {/* Mobile: horizontal tabs */}
      <div className="px-4 pt-4 lg:hidden">
        <div className="flex rounded-lg border border-surface-muted bg-surface-secondary p-1">
          {storeMenuItems.map((item) => {
            const isActive = url.startsWith(item.href);
            return (
              <Link
                key={item.label}
                href={item.href}
                className={cn(
                  "flex-1 rounded-md px-3 py-2 text-center text-sm font-medium transition-colors",
                  isActive
                    ? "bg-white text-content shadow-sm"
                    : "text-content-tertiary hover:text-content",
                )}
              >
                {item.label}
              </Link>
            );
          })}
        </div>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        {/* Sidebar */}
        <aside className="w-[240px] shrink-0">
          <nav className="space-y-1">
            {storeMenuItems.map((item) => {
              const isActive = url.startsWith(item.href);
              return (
                <Link
                  key={item.label}
                  href={item.href}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary-600/10 text-primary-600"
                      : "text-content-tertiary hover:text-content",
                  )}
                >
                  <item.icon className="size-5" />
                  {item.label}
                </Link>
              );
            })}
          </nav>

          {/* Support link at bottom */}
          <Link
            href="/settings/support"
            className="mt-6 flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-content-tertiary transition-colors hover:text-content"
          >
            <HelpCircle className="size-5" />
            Support
          </Link>
        </aside>

        {/* Content area */}
        <div className="min-w-0 flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-content-tertiary">
            <span>Store</span>
            <ChevronRight className="size-3" />
            <span className="text-content">{title}</span>
          </nav>

          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 pt-4 lg:hidden">{children}</div>
    </>
  );
}
```

**Step 2: Create barrel export**

Create `assets/js/features/store-dashboard/index.ts`:

```ts
export { StoreLayout } from "./components/store-layout";
```

**Step 3: Commit**

```
git add assets/js/features/store-dashboard/
git commit -m "feat: add StoreLayout component with sidebar and mobile tabs"
```

---

## Task 6: Build Listings page (full implementation)

**Files:**
- Create: `assets/js/features/store-dashboard/components/stats-card.tsx`
- Create: `assets/js/features/store-dashboard/components/listing-table.tsx`
- Create: `assets/js/features/store-dashboard/components/listing-card.tsx`
- Create: `assets/js/features/store-dashboard/components/listing-actions-menu.tsx`
- Modify: `assets/js/pages/store/listings.tsx`
- Modify: `assets/js/features/store-dashboard/index.ts`

**Reference Figma:** Desktop `662-8377` / `664-12133`, Mobile `722-9486` / `722-11279`

**Step 1: Create StatsCard component**

Create `assets/js/features/store-dashboard/components/stats-card.tsx`:

```tsx
import type { LucideIcon } from "lucide-react";

interface StatsCardProps {
  label: string;
  value: string | number;
  icon: LucideIcon;
  trend?: string;
  trendDirection?: "up" | "down";
}

export function StatsCard({
  label,
  value,
  icon: Icon,
  trend,
  trendDirection = "up",
}: StatsCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted p-4">
      <div className="flex items-center justify-between">
        <span className="text-sm text-content-tertiary">{label}</span>
        <Icon className="size-4 text-content-placeholder" />
      </div>
      <p className="mt-2 text-2xl font-semibold text-content">{value}</p>
      {trend && (
        <p
          className={cn(
            "mt-2 text-xs",
            trendDirection === "up"
              ? "text-feedback-success"
              : "text-feedback-error",
          )}
        >
          {trendDirection === "up" ? "↗" : "↘"} {trend}
        </p>
      )}
    </div>
  );
}

function cn(...classes: (string | undefined | false)[]) {
  return classes.filter(Boolean).join(" ");
}
```

**Step 2: Create ListingActionsMenu component**

Create `assets/js/features/store-dashboard/components/listing-actions-menu.tsx`:

```tsx
import { useState, useRef, useEffect } from "react";
import { MoreVertical, Share2, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";

interface ListingActionsMenuProps {
  itemSlug: string;
  itemId: string;
  onDelete?: (itemId: string) => void;
}

export function ListingActionsMenu({
  itemSlug,
  itemId,
  onDelete,
}: ListingActionsMenuProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    if (open) {
      document.addEventListener("mousedown", handleClickOutside);
      return () =>
        document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [open]);

  const handleShare = async () => {
    const url = `${window.location.origin}/items/${itemSlug}`;
    try {
      await navigator.clipboard.writeText(url);
      toast.success("Item link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
    setOpen(false);
  };

  const handleEdit = () => {
    toast.info("Edit feature coming soon");
    setOpen(false);
  };

  const handleDelete = () => {
    if (onDelete) {
      onDelete(itemId);
    }
    setOpen(false);
  };

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen(!open)}
        className="flex size-8 items-center justify-center rounded-md text-content-tertiary hover:bg-surface-secondary hover:text-content"
      >
        <MoreVertical className="size-4" />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-10 mt-1 w-36 rounded-lg border border-surface-muted bg-white py-1 shadow-lg">
          <button
            onClick={handleShare}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary hover:bg-surface-secondary"
          >
            <Share2 className="size-4" />
            Share
          </button>
          <button
            onClick={handleEdit}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-content-secondary hover:bg-surface-secondary"
          >
            <Pencil className="size-4" />
            Edit
          </button>
          <button
            onClick={handleDelete}
            className="flex w-full items-center gap-2 px-3 py-2 text-sm text-feedback-error hover:bg-surface-secondary"
          >
            <Trash2 className="size-4" />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}
```

**Step 3: Create ListingTable component (desktop)**

Create `assets/js/features/store-dashboard/components/listing-table.tsx`:

```tsx
import { useState } from "react";
import { Clock, ChevronLeft, ChevronRight, ChevronsLeft, ChevronsRight } from "lucide-react";
import type { SellerDashboardCard } from "@/ash_rpc";
import { ListingActionsMenu } from "./listing-actions-menu";

type Item = SellerDashboardCard[number];

interface ListingTableProps {
  items: Item[];
  onDelete?: (itemId: string) => void;
}

function formatTimeLeft(endTime: string | null): string {
  if (!endTime) return "--";
  const end = new Date(endTime);
  const now = new Date();
  const diff = end.getTime() - now.getTime();
  if (diff <= 0) return "Ended";
  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  return `${days}d ${hours} hrs left`;
}

function formatCurrency(value: string | null): string {
  if (!value) return "₦0";
  const num = parseFloat(value);
  return `₦${num.toLocaleString()}`;
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    active: "bg-feedback-success-muted text-feedback-success",
    scheduled: "bg-blue-50 text-blue-600",
    ended: "bg-orange-50 text-orange-600",
    sold: "bg-feedback-success-muted text-feedback-success",
    cancelled: "bg-surface-secondary text-content-tertiary",
    pending: "bg-yellow-50 text-yellow-600",
    draft: "bg-surface-secondary text-content-tertiary",
  };

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium capitalize ${styles[status] || styles.draft}`}
    >
      {status}
    </span>
  );
}

const ROWS_PER_PAGE_OPTIONS = [10, 25, 50];

export function ListingTable({ items, onDelete }: ListingTableProps) {
  const [currentPage, setCurrentPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);

  const totalPages = Math.max(1, Math.ceil(items.length / rowsPerPage));
  const startIndex = (currentPage - 1) * rowsPerPage;
  const pageItems = items.slice(startIndex, startIndex + rowsPerPage);

  return (
    <div>
      <table className="w-full">
        <thead>
          <tr className="border-b border-surface-muted text-left text-sm text-content-tertiary">
            <th className="pb-3 pl-4 font-medium">Item</th>
            <th className="pb-3 font-medium">Views</th>
            <th className="pb-3 font-medium">Watch</th>
            <th className="pb-3 font-medium">Bids</th>
            <th className="pb-3 font-medium">Highest bid</th>
            <th className="pb-3 font-medium">Status</th>
            <th className="pb-3 pr-4"></th>
          </tr>
        </thead>
        <tbody>
          {pageItems.map((item) => (
            <tr
              key={item.id}
              className="border-b border-surface-muted last:border-0"
            >
              <td className="py-4 pl-4">
                <div className="flex items-center gap-3">
                  <div className="size-12 shrink-0 rounded-lg bg-surface-secondary" />
                  <div>
                    <p className="text-sm font-medium text-content">
                      {item.title}
                    </p>
                    <p className="flex items-center gap-1 text-xs text-content-placeholder">
                      <Clock className="size-3" />
                      {formatTimeLeft(item.endTime)}
                    </p>
                  </div>
                </div>
              </td>
              <td className="text-sm text-content-secondary">
                {item.viewCount ?? 0}
              </td>
              <td className="text-sm text-content-secondary">
                {item.watcherCount ?? 0}
              </td>
              <td className="text-sm text-content-secondary">
                {item.bidCount ?? 0}
              </td>
              <td className="text-sm font-medium text-content">
                {formatCurrency(item.currentPrice)}
              </td>
              <td>
                <StatusBadge status={item.auctionStatus} />
              </td>
              <td className="pr-4">
                <ListingActionsMenu
                  itemSlug={item.slug}
                  itemId={item.id}
                  onDelete={onDelete}
                />
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {/* Pagination */}
      <div className="flex items-center justify-center gap-6 border-t border-surface-muted px-4 py-3">
        <div className="flex items-center gap-2 text-sm text-content-tertiary">
          <span>Rows per page</span>
          <select
            value={rowsPerPage}
            onChange={(e) => {
              setRowsPerPage(Number(e.target.value));
              setCurrentPage(1);
            }}
            className="rounded border border-surface-muted bg-white px-2 py-1 text-sm"
          >
            {ROWS_PER_PAGE_OPTIONS.map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </div>

        <span className="text-sm text-content-tertiary">
          Page {currentPage} of {totalPages}
        </span>

        <div className="flex items-center gap-1">
          <button
            onClick={() => setCurrentPage(1)}
            disabled={currentPage === 1}
            className="flex size-8 items-center justify-center rounded text-content-tertiary hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronsLeft className="size-4" />
          </button>
          <button
            onClick={() => setCurrentPage((p) => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="flex size-8 items-center justify-center rounded text-content-tertiary hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronLeft className="size-4" />
          </button>
          <button
            onClick={() => setCurrentPage((p) => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="flex size-8 items-center justify-center rounded text-content-tertiary hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronRight className="size-4" />
          </button>
          <button
            onClick={() => setCurrentPage(totalPages)}
            disabled={currentPage === totalPages}
            className="flex size-8 items-center justify-center rounded text-content-tertiary hover:bg-surface-secondary disabled:opacity-30"
          >
            <ChevronsRight className="size-4" />
          </button>
        </div>
      </div>
    </div>
  );
}
```

**Step 4: Create ListingCard component (mobile)**

Create `assets/js/features/store-dashboard/components/listing-card.tsx`:

```tsx
import type { SellerDashboardCard } from "@/ash_rpc";
import { ListingActionsMenu } from "./listing-actions-menu";

type Item = SellerDashboardCard[number];

function formatCurrency(value: string | null): string {
  if (!value) return "₦0";
  const num = parseFloat(value);
  return `₦${num.toLocaleString()}`;
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    active: "bg-feedback-success-muted text-feedback-success",
    ended: "bg-orange-50 text-orange-600",
    sold: "bg-feedback-success-muted text-feedback-success",
    draft: "bg-surface-secondary text-content-tertiary",
    pending: "bg-yellow-50 text-yellow-600",
  };

  return (
    <span
      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${styles[status] || styles.draft}`}
    >
      {status}
    </span>
  );
}

interface ListingCardProps {
  item: Item;
  onDelete?: (itemId: string) => void;
}

export function ListingCard({ item, onDelete }: ListingCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted p-4">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-medium text-content">
            {item.title}
          </p>
          <p className="mt-1 text-sm text-content-secondary">
            Highest bid:{" "}
            <span className="font-semibold text-content">
              {formatCurrency(item.currentPrice)}
            </span>
          </p>
        </div>
        <ListingActionsMenu
          itemSlug={item.slug}
          itemId={item.id}
          onDelete={onDelete}
        />
      </div>

      <div className="mt-3 flex items-center justify-between">
        <p className="text-xs text-content-placeholder">
          {item.viewCount ?? 0} Views &bull; {item.bidCount ?? 0} Bids &bull;{" "}
          {item.watcherCount ?? 0} Watchers
        </p>
        <StatusBadge status={item.auctionStatus} />
      </div>
    </div>
  );
}
```

**Step 5: Build the full Listings page**

Update `assets/js/pages/store/listings.tsx`:

```tsx
import { Head, Link } from "@inertiajs/react";
import { Eye, Heart, Gavel, Banknote, Plus } from "lucide-react";
import type { SellerDashboardCard } from "@/ash_rpc";
import { StoreLayout } from "@/features/store-dashboard";
import { StatsCard } from "@/features/store-dashboard/components/stats-card";
import { ListingTable } from "@/features/store-dashboard/components/listing-table";
import { ListingCard } from "@/features/store-dashboard/components/listing-card";

interface Stats {
  total_views: number;
  total_watches: number;
  total_bids: number;
  total_amount: string;
}

interface StoreListingsProps {
  items: SellerDashboardCard;
  stats: Stats;
}

function formatCurrency(value: string): string {
  const num = parseFloat(value);
  if (isNaN(num)) return "₦0";
  return `₦${num.toLocaleString()}`;
}

export default function StoreListings({ items = [], stats }: StoreListingsProps) {
  return (
    <>
      <Head title="Store - Listings" />
      <StoreLayout title="Listings">
        {/* Stats cards */}
        <div className="grid grid-cols-2 gap-4 lg:grid-cols-4">
          <StatsCard label="Views" value={stats?.total_views ?? 0} icon={Eye} />
          <StatsCard
            label="Watch"
            value={stats?.total_watches ?? 0}
            icon={Heart}
          />
          <StatsCard label="Bid" value={stats?.total_bids ?? 0} icon={Gavel} />
          <StatsCard
            label="Amount"
            value={formatCurrency(stats?.total_amount ?? "0")}
            icon={Banknote}
          />
        </div>

        {/* Item Listings */}
        <div className="mt-8">
          <h2 className="text-lg font-semibold text-content">Item Listings</h2>

          {items.length === 0 ? (
            <div className="mt-8 flex flex-col items-center justify-center py-16 text-center">
              <p className="text-lg text-content-tertiary">No listings yet</p>
              <p className="mt-1 text-sm text-content-placeholder">
                Create your first listing to start selling
              </p>
              <Link
                href="/items/new"
                className="mt-4 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700"
              >
                Sell Item
              </Link>
            </div>
          ) : (
            <>
              {/* Desktop table */}
              <div className="mt-4 hidden lg:block">
                <ListingTable items={items} />
              </div>

              {/* Mobile cards */}
              <div className="mt-4 flex flex-col gap-3 lg:hidden">
                {items.map((item) => (
                  <ListingCard key={item.id} item={item} />
                ))}
              </div>
            </>
          )}
        </div>

        {/* Mobile FAB */}
        <Link
          href="/items/new"
          className="fixed bottom-20 right-4 z-20 flex size-14 items-center justify-center rounded-full bg-primary-600 text-white shadow-lg lg:hidden"
        >
          <Plus className="size-6" />
        </Link>
      </StoreLayout>
    </>
  );
}
```

**Step 6: Update barrel export**

Update `assets/js/features/store-dashboard/index.ts`:

```ts
export { StoreLayout } from "./components/store-layout";
export { StatsCard } from "./components/stats-card";
export { ListingTable } from "./components/listing-table";
export { ListingCard } from "./components/listing-card";
export { ListingActionsMenu } from "./components/listing-actions-menu";
```

**Step 7: Verify in browser**

Visit `http://localhost:4111/store/listings` — should see stats cards and listings table (or empty state).

**Step 8: Commit**

```
git add assets/js/features/store-dashboard/ assets/js/pages/store/listings.tsx
git commit -m "feat: build store listings page with stats and item table"
```

---

## Task 7: Build Payments page

**Files:**
- Create: `assets/js/features/store-dashboard/components/balance-card.tsx`
- Create: `assets/js/features/store-dashboard/components/payment-table.tsx`
- Create: `assets/js/features/store-dashboard/components/payment-card.tsx`
- Modify: `assets/js/pages/store/payments.tsx`

**Reference Figma:** Desktop `664-12614`, Mobile `722-10717`

**Step 1: Create BalanceCard component**

Create `assets/js/features/store-dashboard/components/balance-card.tsx`:

```tsx
interface BalanceCardProps {
  label: string;
  amount: string;
}

export function BalanceCard({ label, amount }: BalanceCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted p-4">
      <span className="text-sm text-content-tertiary">{label}</span>
      <p className="mt-2 text-2xl font-semibold text-content">{amount}</p>
    </div>
  );
}
```

**Step 2: Create PaymentTable component (desktop)**

Create `assets/js/features/store-dashboard/components/payment-table.tsx`:

```tsx
import type { SellerPaymentCard } from "@/ash_rpc";

type Order = SellerPaymentCard[number];

function formatCurrency(value: string | null): string {
  if (!value) return "₦0";
  const num = parseFloat(value);
  return `₦${num.toLocaleString()}`;
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "2-digit",
    year: "2-digit",
  });
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    paid: "bg-feedback-success-muted text-feedback-success",
    completed: "bg-feedback-success-muted text-feedback-success",
    dispatched: "bg-feedback-success-muted text-feedback-success",
    payment_pending: "bg-orange-50 text-orange-600",
  };

  const labels: Record<string, string> = {
    paid: "Paid",
    completed: "Paid",
    dispatched: "Paid",
    payment_pending: "Pending",
  };

  return (
    <span
      className={`inline-flex rounded-full px-3 py-1 text-xs font-medium ${styles[status] || "bg-surface-secondary text-content-tertiary"}`}
    >
      {labels[status] || status}
    </span>
  );
}

interface PaymentTableProps {
  orders: Order[];
}

export function PaymentTable({ orders }: PaymentTableProps) {
  return (
    <table className="w-full">
      <thead>
        <tr className="border-b border-surface-muted text-left text-sm text-content-tertiary">
          <th className="pb-3 pl-4 font-medium">Item</th>
          <th className="pb-3 font-medium">Amount</th>
          <th className="pb-3 font-medium">Ref ID</th>
          <th className="pb-3 font-medium">Status</th>
          <th className="pb-3 pr-4 font-medium">Date</th>
        </tr>
      </thead>
      <tbody>
        {orders.map((order) => (
          <tr
            key={order.id}
            className="border-b border-surface-muted last:border-0"
          >
            <td className="py-4 pl-4 text-sm text-content">
              {order.item?.title ?? "--"}
            </td>
            <td className="text-sm font-medium text-content">
              {formatCurrency(order.amount)}
            </td>
            <td className="text-sm text-content-secondary">
              {order.paymentReference
                ? `#${order.paymentReference}`
                : "--"}
            </td>
            <td>
              <StatusBadge status={order.status} />
            </td>
            <td className="pr-4 text-sm text-content-secondary">
              {formatDate(order.createdAt)}
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

**Step 3: Create PaymentCard component (mobile)**

Create `assets/js/features/store-dashboard/components/payment-card.tsx`:

```tsx
import type { SellerPaymentCard } from "@/ash_rpc";

type Order = SellerPaymentCard[number];

function formatCurrency(value: string | null): string {
  if (!value) return "₦0";
  const num = parseFloat(value);
  return `₦${num.toLocaleString()}`;
}

function formatDate(dateStr: string | null): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "2-digit",
    year: "2-digit",
  });
}

function StatusBadge({ status }: { status: string }) {
  const styles: Record<string, string> = {
    paid: "bg-feedback-success-muted text-feedback-success",
    completed: "bg-feedback-success-muted text-feedback-success",
    dispatched: "bg-feedback-success-muted text-feedback-success",
    payment_pending: "bg-orange-50 text-orange-600",
  };

  const labels: Record<string, string> = {
    paid: "Paid",
    completed: "Paid",
    dispatched: "Paid",
    payment_pending: "Pending",
  };

  return (
    <span
      className={`inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium ${styles[status] || "bg-surface-secondary text-content-tertiary"}`}
    >
      {labels[status] || status}
    </span>
  );
}

interface PaymentCardProps {
  order: Order;
}

export function PaymentCard({ order }: PaymentCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted p-4">
      <div className="flex items-start justify-between">
        <div>
          <p className="text-sm font-medium text-content">
            {order.item?.title ?? "--"}
          </p>
          <p className="mt-1 text-lg font-semibold text-content">
            {formatCurrency(order.amount)}
          </p>
        </div>
        <StatusBadge status={order.status} />
      </div>
      <p className="mt-2 text-xs text-content-placeholder">
        {order.paymentReference ? `#${order.paymentReference}` : "--"}{" "}
        {formatDate(order.createdAt)}
      </p>
    </div>
  );
}
```

**Step 4: Build the full Payments page**

Update `assets/js/pages/store/payments.tsx`:

```tsx
import { Head } from "@inertiajs/react";
import { toast } from "sonner";
import type { SellerPaymentCard } from "@/ash_rpc";
import { StoreLayout } from "@/features/store-dashboard";
import { BalanceCard } from "@/features/store-dashboard/components/balance-card";
import { PaymentTable } from "@/features/store-dashboard/components/payment-table";
import { PaymentCard } from "@/features/store-dashboard/components/payment-card";

interface Balance {
  balance: string;
  pending: string;
}

interface StorePaymentsProps {
  orders: SellerPaymentCard;
  balance: Balance;
}

function formatCurrency(value: string): string {
  const num = parseFloat(value);
  if (isNaN(num)) return "₦0";
  return `₦${num.toLocaleString()}`;
}

export default function StorePayments({
  orders = [],
  balance,
}: StorePaymentsProps) {
  const handleWithdraw = () => {
    toast.info("Withdraw feature coming soon");
  };

  return (
    <>
      <Head title="Store - Payments" />
      <StoreLayout title="Payments">
        {/* Balance cards */}
        <div className="grid grid-cols-2 gap-4">
          <BalanceCard
            label="Balance"
            amount={formatCurrency(balance?.balance ?? "0")}
          />
          <BalanceCard
            label="Pending"
            amount={formatCurrency(balance?.pending ?? "0")}
          />
        </div>

        <p className="mt-3 text-sm text-content-placeholder">
          Next Payout: --
        </p>

        <button
          onClick={handleWithdraw}
          className="mt-4 rounded-full border-2 border-primary-600 px-6 py-2.5 text-sm font-medium text-primary-600 hover:bg-primary-600/5"
        >
          Withdraw
        </button>

        {/* Payments list */}
        <div className="mt-8">
          <h2 className="text-lg font-semibold text-content">Payments</h2>

          {orders.length === 0 ? (
            <div className="mt-8 flex flex-col items-center justify-center py-16 text-center">
              <p className="text-lg text-content-tertiary">
                No payments yet
              </p>
              <p className="mt-1 text-sm text-content-placeholder">
                Payments will appear here when buyers complete orders
              </p>
            </div>
          ) : (
            <>
              {/* Desktop table */}
              <div className="mt-4 hidden lg:block">
                <PaymentTable orders={orders} />
              </div>

              {/* Mobile cards */}
              <div className="mt-4 flex flex-col gap-3 lg:hidden">
                {orders.map((order) => (
                  <PaymentCard key={order.id} order={order} />
                ))}
              </div>
            </>
          )}
        </div>
      </StoreLayout>
    </>
  );
}
```

**Step 5: Commit**

```
git add assets/js/features/store-dashboard/components/balance-card.tsx assets/js/features/store-dashboard/components/payment-table.tsx assets/js/features/store-dashboard/components/payment-card.tsx assets/js/pages/store/payments.tsx
git commit -m "feat: build store payments page with balance cards and payment table"
```

---

## Task 8: Build Store Profile page

**Files:**
- Create: `assets/js/features/store-dashboard/components/profile-header.tsx`
- Create: `assets/js/features/store-dashboard/components/profile-details.tsx`
- Create: `assets/js/features/store-dashboard/components/reviews-section.tsx`
- Modify: `assets/js/pages/store/profile.tsx`

**Reference Figma:** Desktop `664-13079`, Mobile `722-10433`

**Step 1: Create ProfileHeader component**

Create `assets/js/features/store-dashboard/components/profile-header.tsx`:

```tsx
import { Link } from "@inertiajs/react";
import { Store, BadgeCheck, Star, Share2 } from "lucide-react";
import { toast } from "sonner";

interface ProfileHeaderProps {
  storeName: string;
  username?: string | null;
  userId: string;
}

export function ProfileHeader({
  storeName,
  username,
  userId,
}: ProfileHeaderProps) {
  const handleShare = async () => {
    const slug = username || userId;
    const url = `${window.location.origin}/store/${slug}`;
    try {
      await navigator.clipboard.writeText(url);
      toast.success("Store link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
  };

  return (
    <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
      <div className="flex items-start gap-4">
        {/* Store avatar */}
        <div className="flex size-16 shrink-0 items-center justify-center rounded-xl bg-surface-secondary">
          <Store className="size-8 text-content-placeholder" />
        </div>

        <div>
          {/* Name + badge */}
          <div className="flex items-center gap-2">
            <h2 className="text-xl font-semibold text-content">
              {storeName}
            </h2>
            <BadgeCheck className="size-5 text-content-placeholder" />
          </div>

          {/* Stats (placeholder) */}
          <div className="mt-1 flex items-center gap-3 text-sm text-content-tertiary">
            <span className="flex items-center gap-1">
              <Star className="size-3.5 fill-yellow-400 text-yellow-400" />
              5
            </span>
            <span>&bull;</span>
            <span>95%</span>
            <span>&bull;</span>
            <span>0 Reviews</span>
            <span>&bull;</span>
            <span>0 followers</span>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="flex items-center gap-3">
        <Link
          href="/settings/store"
          className="rounded-full border border-strong px-6 py-2 text-sm font-medium text-content-secondary hover:bg-surface-secondary"
        >
          Edit
        </Link>
        <button
          onClick={handleShare}
          className="flex size-10 items-center justify-center rounded-full border border-strong text-content-secondary hover:bg-surface-secondary"
        >
          <Share2 className="size-4" />
        </button>
      </div>
    </div>
  );
}
```

**Step 2: Create ProfileDetails component**

Create `assets/js/features/store-dashboard/components/profile-details.tsx`:

```tsx
import { MapPin, Phone, MessageCircle } from "lucide-react";

interface StoreProfileData {
  storeName: string;
  contactPhone?: string | null;
  whatsappLink?: string | null;
  location?: string | null;
  address?: string | null;
}

interface CategorySummary {
  id: string;
  name: string;
  slug: string;
  count: number;
}

interface ProfileDetailsProps {
  storeProfile: StoreProfileData | null;
  categorySummary: CategorySummary[];
  joinDate: string | null;
}

function formatJoinDate(dateStr: string | null): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  return date.toLocaleDateString("en-GB", {
    day: "2-digit",
    month: "2-digit",
    year: "2-digit",
  });
}

export function ProfileDetails({
  storeProfile,
  categorySummary,
  joinDate,
}: ProfileDetailsProps) {
  return (
    <div className="mt-6 space-y-4 rounded-xl border border-surface-muted p-4">
      <div className="text-sm text-content-tertiary">
        <span>Date Joined: </span>
        <span className="text-content">{formatJoinDate(joinDate)}</span>
      </div>

      {storeProfile && (
        <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-content-tertiary">
          {storeProfile.location && (
            <span className="flex items-center gap-1.5">
              <MapPin className="size-4 text-content-placeholder" />
              {storeProfile.location}
            </span>
          )}
          {storeProfile.contactPhone && (
            <span className="flex items-center gap-1.5">
              <Phone className="size-4 text-content-placeholder" />
              {storeProfile.contactPhone}
            </span>
          )}
          {storeProfile.whatsappLink && (
            <span className="flex items-center gap-1.5">
              <MessageCircle className="size-4 text-content-placeholder" />
              {storeProfile.whatsappLink}
            </span>
          )}
        </div>
      )}

      {categorySummary.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {categorySummary.map((cat) => (
            <span
              key={cat.id}
              className="rounded-lg border border-surface-muted bg-surface-secondary px-3 py-1.5 text-xs text-content-secondary"
            >
              {cat.name}{" "}
              <span className="text-content-placeholder">{cat.count}</span>
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
```

**Step 3: Create ReviewsSection component (placeholder)**

Create `assets/js/features/store-dashboard/components/reviews-section.tsx`:

```tsx
import { Star } from "lucide-react";

export function ReviewsSection() {
  return (
    <div className="mt-8">
      <h2 className="text-lg font-semibold text-content">Reviews</h2>

      <div className="mt-8 flex flex-col items-center justify-center py-12 text-center">
        <Star className="mb-3 size-12 text-surface-emphasis" />
        <p className="text-content-tertiary">No reviews yet</p>
        <p className="mt-1 text-sm text-content-placeholder">
          Reviews will appear here once buyers leave feedback
        </p>
      </div>
    </div>
  );
}
```

**Step 4: Build the full Store Profile page**

Update `assets/js/pages/store/profile.tsx`:

```tsx
import { Head } from "@inertiajs/react";
import { StoreLayout } from "@/features/store-dashboard";
import { ProfileHeader } from "@/features/store-dashboard/components/profile-header";
import { ProfileDetails } from "@/features/store-dashboard/components/profile-details";
import { ReviewsSection } from "@/features/store-dashboard/components/reviews-section";

interface StoreProfileData {
  id: string;
  storeName: string;
  contactPhone?: string | null;
  whatsappLink?: string | null;
  location?: string | null;
  address?: string | null;
  deliveryPreference?: string;
}

interface UserData {
  id: string;
  email: string;
  fullName?: string | null;
  username?: string | null;
  phoneNumber?: string | null;
  location?: string | null;
  createdAt?: string | null;
}

interface CategorySummary {
  id: string;
  name: string;
  slug: string;
  count: number;
}

interface StoreProfileProps {
  store_profile: StoreProfileData | null;
  user: UserData;
  category_summary: CategorySummary[];
}

export default function StoreProfile({
  store_profile: storeProfile,
  user,
  category_summary: categorySummary = [],
}: StoreProfileProps) {
  const storeName =
    storeProfile?.storeName || user.fullName || "My Store";

  return (
    <>
      <Head title="Store - Profile" />
      <StoreLayout title="Store Profile">
        <ProfileHeader
          storeName={storeName}
          username={user.username}
          userId={user.id}
        />

        <ProfileDetails
          storeProfile={storeProfile}
          categorySummary={categorySummary}
          joinDate={user.createdAt}
        />

        <ReviewsSection />
      </StoreLayout>
    </>
  );
}
```

**Step 5: Commit**

```
git add assets/js/features/store-dashboard/components/profile-header.tsx assets/js/features/store-dashboard/components/profile-details.tsx assets/js/features/store-dashboard/components/reviews-section.tsx assets/js/pages/store/profile.tsx
git commit -m "feat: build store profile page with header, details, and reviews placeholder"
```

---

## Task 9: Visual QA against Figma designs

**Step 1: Take browser screenshots of all 3 pages**

Visit each page and compare with Figma:
- `http://localhost:4111/store/listings` — compare with Figma `662-8377` (desktop) and `722-9486` (mobile)
- `http://localhost:4111/store/payments` — compare with Figma `664-12614` (desktop) and `722-10717` (mobile)
- `http://localhost:4111/store/profile` — compare with Figma `664-13079` (desktop) and `722-10433` (mobile)

**Step 2: Fix any visual discrepancies**

Adjust spacing, colors, typography, and layout to match Figma as closely as possible.

**Step 3: Run all tests**

Run: `mix test`
Expected: All tests pass

**Step 4: Commit fixes**

```
git commit -am "fix: align store dashboard UI with Figma designs"
```

---

## Task 10: Final PR review and push

**Step 1: Review all changes**

Use the code-reviewer skill to review the complete feature branch against the design doc.

**Step 2: Push and create PR**

Target branch: `master`
PR title: `feat: add store dashboard with listings, payments, and profile tabs`
