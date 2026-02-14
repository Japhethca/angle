# Store Profile Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a public store profile page at `/store/:identifier` where guest users can browse a seller's listed items, see contact info, and switch between Auctions/History tabs.

**Architecture:** Hybrid data loading — Phoenix controller loads the seller profile + initial Auctions tab items as Inertia props; client-side RPC handles tab switching (History) and load-more pagination. New fields on User resource (username, store_name, location, whatsapp_number) with a public read action. New `by_seller` read action on Item resource.

**Tech Stack:** Ash Framework (resources, actions, typed queries), Phoenix controller + Inertia.js, React 19 + TanStack Query, Tailwind CSS, shadcn/ui

**Design doc:** `docs/plans/2026-02-14-store-profile-design.md`

---

### Task 1: Add new attributes to User resource

Add `username`, `store_name`, `location`, and `whatsapp_number` fields to the User resource, plus a uniqueness identity for `username`.

**Files:**
- Modify: `lib/angle/accounts/user.ex` (attributes block ~line 437, identities block ~line 579)

**Step 1: Add attributes**

In `lib/angle/accounts/user.ex`, add four new attributes inside the `attributes do` block (after `phone_number`):

```elixir
attribute :username, :string, public?: true
attribute :store_name, :string, public?: true
attribute :location, :string, public?: true
attribute :whatsapp_number, :string, public?: true
```

**Step 2: Add username identity**

In the `identities do` block (after `identity :unique_email, [:email]`):

```elixir
identity :unique_username, [:username], nils_distinct?: false
```

The `nils_distinct?: false` option means NULL usernames are NOT considered unique violations — multiple users can have `nil` username.

**Step 3: Generate migration**

Run: `mix ash.codegen --dev add_store_profile_fields`

Expected: Creates a new migration in `priv/repo/migrations/` that adds the four columns and the unique index.

**Step 4: Run migration and verify compilation**

Run: `mix ash.setup --quiet && mix compile`

Expected: Clean compilation, no errors.

**Step 5: Commit**

```bash
git add lib/angle/accounts/user.ex priv/repo/migrations/
git commit -m "feat: add username, store_name, location, whatsapp_number to User resource"
```

---

### Task 2: Add public profile read action and policy to User

Create a `read_public_profile` read action that allows anyone (including unauthenticated users) to read limited user fields. This action filters by `username` or `id`.

**Files:**
- Modify: `lib/angle/accounts/user.ex` (actions block ~line 83, policies block ~line 378)

**Step 1: Add the read action**

Inside the `actions do` block, add after the existing read-related actions:

```elixir
read :read_public_profile do
  description "Public read action for seller/store profiles"

  argument :username, :string
  argument :user_id, :uuid

  filter expr(
    (not is_nil(^arg(:username)) and username == ^arg(:username)) or
    (not is_nil(^arg(:user_id)) and id == ^arg(:user_id))
  )

  pagination offset?: true, required?: false
end
```

**Step 2: Add the policy**

Inside the `policies do` block, add after the `policy action(:read)` block:

```elixir
policy action(:read_public_profile) do
  authorize_if always()
end
```

**Step 3: Verify compilation**

Run: `mix compile`

Expected: Clean compilation, no errors.

**Step 4: Commit**

```bash
git add lib/angle/accounts/user.ex
git commit -m "feat: add read_public_profile action with public policy on User"
```

---

### Task 3: Add `by_seller` read action to Item resource

Create a read action on Item that filters by seller ID and supports status filtering (active auctions vs history).

**Files:**
- Modify: `lib/angle/inventory/item.ex` (actions block, after `:by_category` ~line 131)

**Step 1: Add the action**

Inside the `actions do` block, after the `read :by_category` action:

```elixir
read :by_seller do
  argument :seller_id, :uuid, allow_nil?: false
  argument :status_filter, :atom do
    default :active
    constraints one_of: [:active, :history]
  end

  filter expr(
    created_by_id == ^arg(:seller_id) and
    publication_status == :published and
    (
      (^arg(:status_filter) == :active and auction_status in [:pending, :scheduled, :active]) or
      (^arg(:status_filter) == :history and auction_status in [:ended, :sold])
    )
  )

  pagination offset?: true, required?: false
end
```

**Step 2: Verify compilation**

Run: `mix compile`

Expected: Clean compilation. The existing policy for `action_type(:read)` already authorizes published items (`authorize_if expr(publication_status == :published)`), so this action is covered.

**Step 3: Commit**

```bash
git add lib/angle/inventory/item.ex
git commit -m "feat: add by_seller read action to Item resource"
```

---

### Task 4: Add typed queries for seller profile and seller items

Add `seller_profile` typed query to the Accounts domain and `seller_item_card` typed query to the Inventory domain.

**Files:**
- Modify: `lib/angle/accounts.ex` (~line 10, inside `typescript_rpc`)
- Modify: `lib/angle/inventory.ex` (~line 54, inside `typescript_rpc`)

**Step 1: Add seller_profile typed query to Accounts**

In `lib/angle/accounts.ex`, inside the `typescript_rpc do` block, inside `resource Angle.Accounts.User do`, add after the `rpc_action` line:

```elixir
typed_query :seller_profile, :read_public_profile do
  ts_result_type_name "SellerProfile"
  ts_fields_const_name "sellerProfileFields"

  fields [
    :id,
    :username,
    :full_name,
    :store_name,
    :location,
    :phone_number,
    :whatsapp_number,
    :inserted_at
  ]
end
```

Note: `:inserted_at` is the Ash timestamp field (join date).

**Step 2: Add seller_item_card typed query to Inventory**

In `lib/angle/inventory.ex`, inside the `typescript_rpc do` block, inside `resource Angle.Inventory.Item do`, add after the `category_item_card` typed query:

```elixir
typed_query :seller_item_card, :by_seller do
  ts_result_type_name "SellerItemCard"
  ts_fields_const_name "sellerItemCardFields"

  fields [
    :id,
    :title,
    :slug,
    :starting_price,
    :current_price,
    :end_time,
    :auction_status,
    :condition,
    :sale_type,
    :view_count,
    :bid_count,
    %{category: [:id, :name, :slug]}
  ]
end
```

**Step 3: Verify compilation**

Run: `mix compile`

Expected: Clean compilation, no errors.

**Step 4: Commit**

```bash
git add lib/angle/accounts.ex lib/angle/inventory.ex
git commit -m "feat: add seller_profile and seller_item_card typed queries"
```

---

### Task 5: Run codegen and verify TypeScript types

Generate the Ash migration snapshots and TypeScript RPC types.

**Files:**
- Auto-generated: `assets/js/ash_rpc.ts`

**Step 1: Run Ash codegen**

Run: `mix ash.codegen --dev`

Expected: No pending changes (migration was already generated in Task 1).

**Step 2: Run TypeScript codegen**

Run: `mix ash_typescript.codegen`

Expected: Updates `assets/js/ash_rpc.ts` with new types: `SellerProfile`, `sellerProfileFields`, `SellerItemCard`, `sellerItemCardFields`, plus the new `by_seller` and `read_public_profile` action types.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit && cd ..`

Expected: Clean TypeScript compilation (ignore any pre-existing errors).

**Step 4: Commit**

```bash
git add assets/js/ash_rpc.ts
git commit -m "chore: regenerate TypeScript RPC types for store profile"
```

---

### Task 6: Write controller tests for StoreController

Write tests first (TDD), then implement the controller and route.

**Files:**
- Create: `test/angle_web/controllers/store_controller_test.exs`

**Step 1: Write the test file**

Reference pattern from `test/angle_web/controllers/categories_controller_test.exs`.

```elixir
defmodule AngleWeb.StoreControllerTest do
  use AngleWeb.ConnCase

  describe "GET /store/:identifier" do
    test "renders store/show page for a valid seller by username", %{conn: conn} do
      user = create_user(%{full_name: "Test Seller"})
      # Set username directly since factory doesn't support it yet
      Ash.update!(user, %{username: "test-seller"}, authorize?: false)

      item =
        create_item(%{
          title: "Seller Widget",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/test-seller")
      response = html_response(conn, 200)
      assert response =~ "store/show"
      assert response =~ "Test Seller"
    end

    test "renders store/show page for a valid seller by UUID", %{conn: conn} do
      user = create_user(%{full_name: "UUID Seller"})

      item =
        create_item(%{
          title: "UUID Widget",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "store/show"
      assert response =~ "UUID Seller"
    end

    test "includes published items in the response", %{conn: conn} do
      user = create_user()

      item =
        create_item(%{
          title: "Published Store Item",
          created_by_id: user.id
        })

      Ash.update!(item, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "Published Store Item"
    end

    test "does not include draft items in the response", %{conn: conn} do
      user = create_user()

      _draft = create_item(%{
        title: "Draft Secret Item",
        created_by_id: user.id
      })

      published =
        create_item(%{
          title: "Visible Item",
          created_by_id: user.id
        })

      Ash.update!(published, %{}, action: :publish_item, authorize?: false)

      conn = get(conn, ~p"/store/#{user.id}")
      response = html_response(conn, 200)
      assert response =~ "Visible Item"
      refute response =~ "Draft Secret Item"
    end

    test "redirects to / when seller not found", %{conn: conn} do
      conn = get(conn, ~p"/store/nonexistent-seller")
      assert redirected_to(conn) == "/"
    end

    test "redirects to / when UUID not found", %{conn: conn} do
      fake_uuid = Ecto.UUID.generate()
      conn = get(conn, ~p"/store/#{fake_uuid}")
      assert redirected_to(conn) == "/"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/angle_web/controllers/store_controller_test.exs`

Expected: All tests fail (controller and route don't exist yet). Errors like `(UndefinedFunctionError) function AngleWeb.StoreController.init/1 is undefined`.

---

### Task 7: Create StoreController and add route

Implement the controller to make the tests pass.

**Files:**
- Create: `lib/angle_web/controllers/store_controller.ex`
- Modify: `lib/angle_web/router.ex` (~line 69, public routes scope)

**Step 1: Create the controller**

Create `lib/angle_web/controllers/store_controller.ex`:

```elixir
defmodule AngleWeb.StoreController do
  use AngleWeb, :controller

  @items_per_page 20

  def show(conn, %{"identifier" => identifier}) do
    case load_seller(conn, identifier) do
      nil ->
        conn
        |> put_flash(:error, "Seller not found")
        |> redirect(to: "/")

      seller ->
        {items, has_more} = load_seller_items(conn, seller["id"], :active)
        category_summary = build_category_summary(conn, seller["id"])

        conn
        |> assign_prop(:seller, seller)
        |> assign_prop(:items, items)
        |> assign_prop(:has_more, has_more)
        |> assign_prop(:category_summary, category_summary)
        |> assign_prop(:active_tab, "auctions")
        |> render_inertia("store/show")
    end
  end

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

  defp build_category_summary(conn, seller_id) do
    # Load ALL seller's published items to count by category
    # Use a large limit to get all items for grouping
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
```

**Step 2: Add route**

In `lib/angle_web/router.ex`, inside the public routes scope (`scope "/", AngleWeb do`, ~line 65), add after the categories routes:

```elixir
get "/store/:identifier", StoreController, :show
```

**Step 3: Run the tests**

Run: `mix test test/angle_web/controllers/store_controller_test.exs`

Expected: All 6 tests pass.

**Step 4: Run full test suite**

Run: `mix test`

Expected: All tests pass (existing + new).

**Step 5: Commit**

```bash
git add lib/angle_web/controllers/store_controller.ex lib/angle_web/router.ex test/angle_web/controllers/store_controller_test.exs
git commit -m "feat: add StoreController with route and tests"
```

---

### Task 8: Update SellerCard to link to store profile

Make the seller card on the item detail page link to the seller's store profile.

**Files:**
- Modify: `assets/js/features/items/components/seller-card.tsx`

**Step 1: Update the component**

Replace the current seller-card.tsx content. Key changes:
- Add `Link` from Inertia
- Add `username` to the seller interface
- Make the chevron button a `<Link>` to `/store/:username` (or `/store/:id`)

```tsx
import { Link } from "@inertiajs/react";
import { User, ChevronRight, BadgeCheck } from "lucide-react";

interface SellerCardProps {
  seller: {
    id: string;
    email: string;
    fullName: string | null;
    username?: string | null;
  } | null;
}

export function SellerCard({ seller }: SellerCardProps) {
  if (!seller) return null;

  const displayName = seller.fullName || seller.email;
  const storeUrl = `/store/${seller.username || seller.id}`;

  return (
    <div className="rounded-2xl bg-neutral-08 p-4 lg:p-5">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-3">
          {/* Avatar placeholder */}
          <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-12">
            <User className="size-5 text-neutral-04 lg:size-6" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="text-sm font-medium text-neutral-01 lg:text-base">
                {displayName}
              </span>
              <BadgeCheck className="size-4 text-primary-600" />
            </div>
            <p className="text-xs text-neutral-04">Seller</p>
          </div>
        </div>

        {/* Visit seller store */}
        <Link
          href={storeUrl}
          className="flex size-9 items-center justify-center rounded-full border border-neutral-06 transition-colors hover:bg-neutral-07"
        >
          <ChevronRight className="size-4 text-neutral-03" />
        </Link>
      </div>
    </div>
  );
}
```

**Step 2: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit && cd ..`

Expected: Clean compilation. The `username` field is optional so it won't break existing usage where `item_detail` returns `user` without `username`.

**Step 3: Commit**

```bash
git add assets/js/features/items/components/seller-card.tsx
git commit -m "feat: link SellerCard to store profile page"
```

---

### Task 9: Create store/show.tsx page

Build the main store profile page with header, category chips, tabs (Auctions/History/Reviews), item grid with load-more, and responsive layout.

**Files:**
- Create: `assets/js/pages/store/show.tsx`

**Step 1: Create the page**

Create `assets/js/pages/store/show.tsx`. This is the largest file — it follows the pattern from `pages/categories/show.tsx` closely.

```tsx
import { useState, useCallback, useMemo } from "react";
import { Head, Link } from "@inertiajs/react";
import {
  ChevronLeft,
  User,
  BadgeCheck,
  MapPin,
  Phone,
  MessageCircle,
  LayoutGrid,
  List,
  Loader2,
  Star,
  UserPlus,
  Share2,
  Calendar,
} from "lucide-react";
import type { SellerProfile, SellerItemCard as SellerItemCardType } from "@/ash_rpc";
import { listItems, sellerItemCardFields, buildCSRFHeaders } from "@/ash_rpc";
import type { ListItemsFields } from "@/ash_rpc";
import { CategoryItemCard, CategoryItemListCard } from "@/features/items";
import type { CategoryItem } from "@/features/items";

type Seller = SellerProfile[number];
type SellerItem = SellerItemCardType[number];

type ViewMode = "grid" | "list";
type TabId = "auctions" | "history" | "reviews";

const ITEMS_PER_PAGE = 20;
const VIEW_MODE_KEY = "store-view-mode";

interface CategorySummary {
  id: string;
  name: string;
  slug: string;
  count: number;
}

interface StoreShowProps {
  seller: Seller;
  items: SellerItem[];
  has_more: boolean;
  category_summary: CategorySummary[];
  active_tab: string;
}

function getInitialViewMode(): ViewMode {
  if (typeof window === "undefined") return "grid";
  const stored = localStorage.getItem(VIEW_MODE_KEY);
  return stored === "list" ? "list" : "grid";
}

function formatDate(dateString: string | null) {
  if (!dateString) return null;
  try {
    return new Date(dateString).toLocaleDateString("en-GB", {
      day: "2-digit",
      month: "2-digit",
      year: "2-digit",
    });
  } catch {
    return null;
  }
}

export default function StoreShow({
  seller,
  items: initialItems = [],
  has_more: initialHasMore = false,
  category_summary = [],
}: StoreShowProps) {
  const [activeTab, setActiveTab] = useState<TabId>("auctions");
  const [viewMode, setViewMode] = useState<ViewMode>(getInitialViewMode);

  // Auctions tab state (server-loaded initially)
  const [auctionItems, setAuctionItems] = useState<SellerItem[]>(initialItems);
  const [auctionHasMore, setAuctionHasMore] = useState(initialHasMore);
  const [isLoadingMoreAuctions, setIsLoadingMoreAuctions] = useState(false);

  // History tab state (client-loaded on demand)
  const [historyItems, setHistoryItems] = useState<SellerItem[]>([]);
  const [historyHasMore, setHistoryHasMore] = useState(false);
  const [historyLoaded, setHistoryLoaded] = useState(false);
  const [isLoadingHistory, setIsLoadingHistory] = useState(false);
  const [isLoadingMoreHistory, setIsLoadingMoreHistory] = useState(false);

  const displayName = seller.storeName || seller.fullName || "Store";
  const storeIdentifier = seller.username || seller.id;
  const joinDate = formatDate(seller.insertedAt);

  const handleViewModeChange = (mode: ViewMode) => {
    setViewMode(mode);
    localStorage.setItem(VIEW_MODE_KEY, mode);
  };

  // Load more auctions
  const loadMoreAuctions = useCallback(async () => {
    if (isLoadingMoreAuctions) return;
    setIsLoadingMoreAuctions(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["pending", "scheduled", "active"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: auctionItems.length },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as { results: SellerItem[]; hasMore: boolean };
        setAuctionItems((prev) => [...prev, ...data.results]);
        setAuctionHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingMoreAuctions(false);
    }
  }, [seller.id, auctionItems.length, isLoadingMoreAuctions]);

  // Load history tab items
  const loadHistory = useCallback(async () => {
    if (historyLoaded || isLoadingHistory) return;
    setIsLoadingHistory(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["ended", "sold"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: 0 },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as { results: SellerItem[]; hasMore: boolean };
        setHistoryItems(data.results);
        setHistoryHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingHistory(false);
      setHistoryLoaded(true);
    }
  }, [seller.id, historyLoaded, isLoadingHistory]);

  // Load more history items
  const loadMoreHistory = useCallback(async () => {
    if (isLoadingMoreHistory) return;
    setIsLoadingMoreHistory(true);
    try {
      const fields = sellerItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          createdById: { eq: seller.id },
          publicationStatus: { eq: "published" },
          auctionStatus: { in: ["ended", "sold"] },
        },
        page: { limit: ITEMS_PER_PAGE, offset: historyItems.length },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as { results: SellerItem[]; hasMore: boolean };
        setHistoryItems((prev) => [...prev, ...data.results]);
        setHistoryHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingMoreHistory(false);
    }
  }, [seller.id, historyItems.length, isLoadingMoreHistory]);

  const handleTabChange = (tab: TabId) => {
    setActiveTab(tab);
    if (tab === "history" && !historyLoaded) {
      loadHistory();
    }
  };

  // Current tab data
  const currentItems = activeTab === "auctions" ? auctionItems : historyItems;
  const currentHasMore = activeTab === "auctions" ? auctionHasMore : historyHasMore;
  const currentLoadMore = activeTab === "auctions" ? loadMoreAuctions : loadMoreHistory;
  const isCurrentLoading = activeTab === "auctions" ? isLoadingMoreAuctions : isLoadingMoreHistory;
  const isTabLoading = activeTab === "history" && isLoadingHistory;

  const handleShare = () => {
    const url = `${window.location.origin}/store/${storeIdentifier}`;
    navigator.clipboard.writeText(url);
  };

  const tabs: { id: TabId; label: string }[] = [
    { id: "auctions", label: "Auctions" },
    { id: "history", label: "History" },
    { id: "reviews", label: "Reviews" },
  ];

  return (
    <>
      <Head title={`${displayName} - Store Profile`} />

      <div className="pb-8">
        {/* Mobile header */}
        <div className="flex items-center justify-between px-4 py-4 lg:hidden">
          <div className="flex items-center gap-3">
            <button
              onClick={() => window.history.back()}
              className="flex size-9 items-center justify-center"
            >
              <ChevronLeft className="size-5 text-neutral-01" />
            </button>
            <h1 className="text-xl font-medium text-neutral-01">Store Profile</h1>
          </div>
          <button className="flex size-9 items-center justify-center rounded-full border border-neutral-06">
            <UserPlus className="size-4 text-neutral-03" />
          </button>
        </div>

        {/* Desktop breadcrumb */}
        <div className="hidden px-10 pt-8 lg:block">
          <nav className="mb-4 text-sm text-neutral-04">
            <Link href="/" className="hover:text-neutral-01">Home</Link>
            <span className="mx-2">/</span>
            <span className="text-neutral-01">Store Profile</span>
          </nav>
        </div>

        {/* Seller profile header */}
        <div className="px-4 lg:px-10">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            {/* Seller info */}
            <div className="flex items-start gap-4">
              {/* Avatar */}
              <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-14">
                <User className="size-6 text-neutral-04 lg:size-7" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <h2 className="text-lg font-semibold text-neutral-01 lg:text-xl">
                    {displayName}
                  </h2>
                  <BadgeCheck className="size-5 text-primary-600" />
                </div>
                {/* Stats row — placeholders for V1 */}
                <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-neutral-04">
                  <span className="inline-flex items-center gap-0.5">
                    <Star className="size-3 fill-current text-yellow-500" />
                    5
                  </span>
                  <span className="text-neutral-06">·</span>
                  <span>95%</span>
                  <span className="text-neutral-06">·</span>
                  <span>0 Reviews</span>
                  <span className="text-neutral-06">·</span>
                  <span>0 followers</span>
                </div>
              </div>
            </div>

            {/* Action buttons (desktop) */}
            <div className="hidden items-center gap-3 lg:flex">
              <button className="flex items-center gap-2 rounded-lg border border-neutral-06 px-5 py-2.5 text-sm font-medium text-neutral-02 transition-colors hover:bg-neutral-09">
                <UserPlus className="size-4" />
                Follow
              </button>
              <button
                onClick={handleShare}
                className="flex size-10 items-center justify-center rounded-full border border-neutral-06 transition-colors hover:bg-neutral-09"
              >
                <Share2 className="size-4 text-neutral-03" />
              </button>
            </div>
          </div>

          {/* Seller details */}
          <div className="mt-4 rounded-xl bg-neutral-09 p-4">
            {joinDate && (
              <div className="mb-2 flex items-center gap-2 text-sm text-neutral-03">
                <span className="text-neutral-05">Date Joined:</span>
                <span className="font-medium">{joinDate}</span>
              </div>
            )}

            {/* Contact info */}
            {(seller.location || seller.phoneNumber || seller.whatsappNumber) && (
              <div className="flex flex-wrap items-center gap-4 text-sm text-neutral-03">
                {seller.location && (
                  <span className="inline-flex items-center gap-1.5">
                    <MapPin className="size-3.5 text-neutral-05" />
                    {seller.location}
                  </span>
                )}
                {seller.phoneNumber && (
                  <span className="inline-flex items-center gap-1.5">
                    <Phone className="size-3.5 text-neutral-05" />
                    {seller.phoneNumber}
                  </span>
                )}
                {seller.whatsappNumber && (
                  <span className="inline-flex items-center gap-1.5">
                    <MessageCircle className="size-3.5 text-neutral-05" />
                    {seller.whatsappNumber}
                  </span>
                )}
              </div>
            )}

            {/* Category chips */}
            {category_summary.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {category_summary.map((cat) => (
                  <span
                    key={cat.id}
                    className="inline-flex items-center gap-1.5 rounded-lg border border-neutral-07 bg-white px-3 py-1 text-xs text-neutral-03"
                  >
                    {cat.name}
                    <span className="font-medium text-neutral-01">{cat.count}</span>
                  </span>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* Tabs + View toggle */}
        <div className="mt-6 flex items-center justify-between border-b border-neutral-07 px-4 lg:px-10">
          <div className="flex">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => handleTabChange(tab.id)}
                className={`border-b-2 px-6 pb-3 text-sm font-medium transition-colors ${
                  activeTab === tab.id
                    ? "border-primary-600 text-primary-600"
                    : "border-transparent text-neutral-04 hover:text-neutral-02"
                }`}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* View toggle */}
          <div className="flex items-center gap-1 pb-3">
            <button
              onClick={() => handleViewModeChange("grid")}
              aria-label="Grid view"
              className={`flex size-8 items-center justify-center rounded transition-colors ${
                viewMode === "grid" ? "text-primary-600" : "text-neutral-05 hover:text-neutral-03"
              }`}
            >
              <LayoutGrid className="size-4" />
            </button>
            <button
              onClick={() => handleViewModeChange("list")}
              aria-label="List view"
              className={`flex size-8 items-center justify-center rounded transition-colors ${
                viewMode === "list" ? "text-primary-600" : "text-neutral-05 hover:text-neutral-03"
              }`}
            >
              <List className="size-4" />
            </button>
          </div>
        </div>

        {/* Tab content */}
        <div className="mt-6">
          {activeTab === "reviews" ? (
            <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
              <p className="text-lg text-neutral-04">Reviews coming soon</p>
              <p className="mt-1 text-sm text-neutral-05">
                This feature is under development
              </p>
            </div>
          ) : isTabLoading ? (
            <div className="flex justify-center py-16">
              <Loader2 className="size-8 animate-spin text-neutral-04" />
            </div>
          ) : currentItems.length > 0 ? (
            <>
              {viewMode === "grid" ? (
                <div className="grid grid-cols-2 gap-4 px-4 lg:grid-cols-4 lg:gap-6 lg:px-10">
                  {currentItems.map((item) => (
                    <CategoryItemCard key={item.id} item={item as CategoryItem} />
                  ))}
                </div>
              ) : (
                <div className="flex flex-col gap-4 px-4 lg:px-10">
                  {currentItems.map((item) => (
                    <CategoryItemListCard key={item.id} item={item as CategoryItem} />
                  ))}
                </div>
              )}

              {/* Load More button */}
              {currentHasMore && (
                <div className="flex justify-center px-4 pt-8 lg:px-10">
                  <button
                    onClick={currentLoadMore}
                    disabled={isCurrentLoading}
                    className="flex items-center gap-2 rounded-full border border-neutral-06 px-8 py-3 text-sm font-medium text-neutral-03 transition-colors hover:bg-neutral-09 disabled:opacity-50"
                  >
                    {isCurrentLoading ? (
                      <>
                        <Loader2 className="size-4 animate-spin" />
                        Loading...
                      </>
                    ) : (
                      "Load More"
                    )}
                  </button>
                </div>
              )}
            </>
          ) : (
            <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
              <p className="text-lg text-neutral-04">
                {activeTab === "auctions"
                  ? "No active auctions"
                  : "No auction history yet"}
              </p>
              <p className="mt-1 text-sm text-neutral-05">Check back later</p>
            </div>
          )}
        </div>
      </div>
    </>
  );
}
```

**Step 2: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit && cd ..`

Expected: Clean compilation.

**Step 3: Commit**

```bash
git add assets/js/pages/store/show.tsx
git commit -m "feat: create store profile page with tabs, grid/list view, and load-more"
```

---

### Task 10: Add username support to factory and update item_detail typed query

The item detail page's SellerCard now expects an optional `username` field on the user. Update the `item_detail` typed query to include `username`, and add `username` support to the test factory.

**Files:**
- Modify: `lib/angle/inventory.ex` (item_detail typed query, ~line 56)
- Modify: `test/support/factory.ex` (create_user function)

**Step 1: Add username to item_detail user fields**

In `lib/angle/inventory.ex`, find the `item_detail` typed query's fields list. Change:

```elixir
%{user: [:id, :email, :full_name]}
```

to:

```elixir
%{user: [:id, :email, :full_name, :username]}
```

**Step 2: Add username support to factory**

In `test/support/factory.ex`, in the `create_user/1` function, add `username` to the `maybe_put` chain (after `phone_number`):

```elixir
|> maybe_put(:username, Map.get(attrs, :username))
```

**Step 3: Regenerate TypeScript types**

Run: `mix ash_typescript.codegen`

Expected: Updates `ash_rpc.ts` with `username` added to the `ItemDetail` user type.

**Step 4: Verify everything compiles and tests pass**

Run: `mix compile && mix test && cd assets && npx tsc --noEmit && cd ..`

Expected: All tests pass, clean compilation on both sides.

**Step 5: Commit**

```bash
git add lib/angle/inventory.ex test/support/factory.ex assets/js/ash_rpc.ts
git commit -m "feat: add username to item_detail user fields and factory"
```

---

### Task 11: Final verification

Run all checks to confirm the feature is complete and working.

**Step 1: Run full test suite**

Run: `mix test`

Expected: All tests pass (existing + 6 new store controller tests).

**Step 2: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit && cd ..`

Expected: Clean compilation.

**Step 3: Verify Elixir compilation**

Run: `mix compile --warnings-as-errors`

Expected: Clean compilation.

**Step 4: Start the server and verify in browser**

Run: `mix phx.server`

Test URLs:
- `/store/<any-user-uuid>` — should show the store profile page
- `/store/nonexistent` — should redirect to `/` with flash
- Item detail page → seller card → click chevron → navigates to store profile

---

## Summary

| Task | What | Files |
|------|------|-------|
| 1 | User attributes + migration | `user.ex`, migration |
| 2 | Public profile read action + policy | `user.ex` |
| 3 | `by_seller` Item action | `item.ex` |
| 4 | Typed queries (seller_profile, seller_item_card) | `accounts.ex`, `inventory.ex` |
| 5 | Codegen (Ash + TypeScript) | `ash_rpc.ts` |
| 6 | Controller tests (TDD) | `store_controller_test.exs` |
| 7 | StoreController + route | `store_controller.ex`, `router.ex` |
| 8 | SellerCard link update | `seller-card.tsx` |
| 9 | Store profile page | `store/show.tsx` |
| 10 | username in item_detail + factory | `inventory.ex`, `factory.ex`, `ash_rpc.ts` |
| 11 | Final verification | — |
