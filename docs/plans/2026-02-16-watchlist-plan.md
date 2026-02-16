# Watchlist Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a full watchlist feature — backend resource, watchlist page with empty/populated states and category filtering, and functional heart buttons on item cards.

**Architecture:** WatchlistItem Ash resource in Inventory domain, `watchlisted` read action on Item for typed queries, Inertia controller loads data as props, React page with responsive layout.

**Tech Stack:** Ash Framework, AshPostgres, AshTypescript RPC, Phoenix controllers, Inertia.js, React, shadcn/ui, Lucide icons, Tailwind CSS

---

### Task 1: Create WatchlistItem Ash resource

**Files:**
- Create: `lib/angle/inventory/watchlist_item.ex`

Create a new Ash resource for watchlist entries:

```elixir
defmodule Angle.Inventory.WatchlistItem do
  use Ash.Resource,
    domain: Angle.Inventory,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "watchlist_items"
    repo Angle.Repo
  end

  typescript do
    type_name "WatchlistItem"
  end

  actions do
    defaults []

    create :add do
      description "Add an item to the user's watchlist"
      accept [:item_id]
      change set_attribute(:user_id, actor(:id))
    end

    destroy :remove do
      description "Remove an item from the user's watchlist"
      primary? true
    end

    read :by_user do
      description "List watchlist items for the current user"
      filter expr(user_id == ^actor(:id))
    end

    read :read do
      primary? true
    end
  end

  policies do
    policy action(:add) do
      authorize_if actor_present()
    end

    policy action(:remove) do
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action(:by_user) do
      authorize_if actor_present()
    end

    policy action(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :item_id, :uuid do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      source_attribute :user_id
      public? true
    end

    belongs_to :item, Angle.Inventory.Item do
      source_attribute :item_id
      public? true
    end
  end

  identities do
    identity :unique_user_item, [:user_id, :item_id]
  end
end
```

**Verify:** `mix compile`

**Commit:** `feat: add WatchlistItem Ash resource`

---

### Task 2: Update Item resource and Inventory domain

**Files:**
- Modify: `lib/angle/inventory/item.ex`
- Modify: `lib/angle/inventory.ex`

**Step 1: Add relationship and aggregate to Item**

In `lib/angle/inventory/item.ex`, in the `relationships` block, add:

```elixir
has_many :watchlist_items, Angle.Inventory.WatchlistItem do
  destination_attribute :item_id
end
```

In the `aggregates` block, add:

```elixir
count :watcher_count, :watchlist_items do
  public? true
end
```

**Step 2: Add `watchlisted` read action to Item**

In the `actions` block, add:

```elixir
read :watchlisted do
  description "List items in the current user's watchlist"

  argument :category_id, :uuid do
    description "Optional category filter"
  end

  filter expr(
    exists(watchlist_items, user_id == ^actor(:id)) and
      publication_status == :published and
      (is_nil(^arg(:category_id)) or category_id == ^arg(:category_id))
  )

  pagination offset?: true, required?: false
end
```

**Step 3: Add `user_watchlist_ids` read action to Item**

This action returns just the IDs of items in the user's watchlist (for heart button state on other pages):

```elixir
read :user_watchlist_ids do
  description "Get IDs of items in the current user's watchlist"
  filter expr(exists(watchlist_items, user_id == ^actor(:id)) and publication_status == :published)
end
```

**Step 4: Update Inventory domain**

In `lib/angle/inventory.ex`:

Add to `resources` block:
```elixir
resource Angle.Inventory.WatchlistItem
```

Add RPC actions for WatchlistItem in the `typescript_rpc` block:
```elixir
resource Angle.Inventory.WatchlistItem do
  rpc_action :add_to_watchlist, :add
  rpc_action :remove_from_watchlist, :remove
end
```

Add typed query for watchlist page (on Item resource, inside the existing `resource Angle.Inventory.Item do` block):

```elixir
typed_query :watchlist_item_card, :watchlisted do
  ts_result_type_name "WatchlistItemCard"
  ts_fields_const_name "watchlistItemCardFields"

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
    :bid_count,
    :watcher_count,
    %{category: [:id, :name, :slug]},
    %{user: [:id, :full_name]}
  ]
end
```

Also add typed query for watchlist IDs:
```elixir
typed_query :user_watchlist_ids, :user_watchlist_ids do
  ts_result_type_name "UserWatchlistId"
  ts_fields_const_name "userWatchlistIdFields"

  fields [:id]
end
```

**Step 5: Add policy for new read actions on Item**

The existing Item read policy already covers `action_type(:read)` with `authorize_if expr(publication_status == :published)`, so the `watchlisted` and `user_watchlist_ids` actions should work since they filter to published items.

**Verify:** `mix compile`

**Commit:** `feat: update Item resource and Inventory domain for watchlist`

---

### Task 3: Generate migration and codegen

**Step 1:** Run `mix ash.codegen add_watchlist_items`
**Step 2:** Run `mix ash_typescript.codegen`
**Step 3:** Run `mix ecto.migrate`
**Step 4:** Verify migration creates `watchlist_items` table with user_id, item_id, unique index
**Step 5:** Verify `ash_rpc.ts` has `addToWatchlist`, `removeFromWatchlist` functions and `WatchlistItemCard` type

**Commit:** `feat: add watchlist migration and regenerate TypeScript types`

---

### Task 4: Add test factory and backend tests

**Files:**
- Modify: `test/support/factory.ex`
- Create: `test/angle/inventory/watchlist_item_test.exs`

**Step 1: Add factory function**

In `test/support/factory.ex`, add:

```elixir
def create_watchlist_item(opts \\ []) do
  user = Keyword.get_lazy(opts, :user, fn -> create_user() end)
  item = Keyword.get_lazy(opts, :item, fn -> create_item() end)

  Angle.Inventory.WatchlistItem
  |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user, authorize?: false)
  |> Ash.create!()
end
```

**Step 2: Write resource tests**

```elixir
defmodule Angle.Inventory.WatchlistItemTest do
  use Angle.DataCase, async: true

  describe "add to watchlist" do
    test "user can add an item to their watchlist" do
      user = create_user()
      item = create_item()

      {:ok, entry} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
        |> Ash.create()

      assert entry.user_id == user.id
      assert entry.item_id == item.id
    end

    test "cannot add same item twice" do
      user = create_user()
      item = create_item()

      {:ok, _} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
        |> Ash.create()

      assert {:error, _} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user)
        |> Ash.create()
    end
  end

  describe "remove from watchlist" do
    test "user can remove an item from their watchlist" do
      user = create_user()
      item = create_item()

      {:ok, entry} =
        Angle.Inventory.WatchlistItem
        |> Ash.Changeset.for_create(:add, %{item_id: item.id}, actor: user, authorize?: false)
        |> Ash.create()

      assert :ok =
        entry
        |> Ash.Changeset.for_destroy(:remove, %{}, actor: user)
        |> Ash.destroy()
    end
  end

  describe "watchlisted items query" do
    test "returns items in user's watchlist" do
      user = create_user()
      item1 = create_item()
      item2 = create_item()
      _item3 = create_item()

      create_watchlist_item(user: user, item: item1)
      create_watchlist_item(user: user, item: item2)

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:watchlisted, %{}, actor: user)
        |> Ash.read!()

      assert length(results) == 2
      ids = Enum.map(results, & &1.id)
      assert item1.id in ids
      assert item2.id in ids
    end

    test "filters by category" do
      user = create_user()
      cat1 = create_category()
      cat2 = create_category()
      item1 = create_item(category_id: cat1.id)
      item2 = create_item(category_id: cat2.id)

      create_watchlist_item(user: user, item: item1)
      create_watchlist_item(user: user, item: item2)

      results =
        Angle.Inventory.Item
        |> Ash.Query.for_read(:watchlisted, %{category_id: cat1.id}, actor: user)
        |> Ash.read!()

      assert length(results) == 1
      assert hd(results).id == item1.id
    end
  end

  describe "watcher_count aggregate" do
    test "counts users watching an item" do
      item = create_item()
      user1 = create_user()
      user2 = create_user()

      create_watchlist_item(user: user1, item: item)
      create_watchlist_item(user: user2, item: item)

      item = Ash.load!(item, :watcher_count, authorize?: false)
      assert item.watcher_count == 2
    end
  end
end
```

**Verify:** `mix test test/angle/inventory/watchlist_item_test.exs`

**Commit:** `test: add watchlist resource tests and factory function`

---

### Task 5: Update WatchlistController

**Files:**
- Modify: `lib/angle_web/controllers/watchlist_controller.ex`

Replace the stub controller with real data loading:

```elixir
defmodule AngleWeb.WatchlistController do
  use AngleWeb, :controller

  def index(conn, params) do
    category_id = params["category"]

    items = load_watchlist_items(conn, category_id)
    categories = load_top_categories()

    conn
    |> assign_prop(:items, items)
    |> assign_prop(:categories, categories)
    |> assign_prop(:active_category, category_id)
    |> render_inertia("watchlist")
  end

  defp load_watchlist_items(conn, category_id) do
    query_params = %{
      filter: build_filter(category_id)
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :watchlist_item_card, query_params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end
  end

  defp build_filter(nil), do: %{}
  defp build_filter(category_id), do: %{category_id: category_id}

  defp load_top_categories do
    Angle.Catalog.Category
    |> Ash.Query.filter(is_nil(parent_id))
    |> Ash.Query.sort(:name)
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn cat -> %{id: cat.id, name: cat.name, slug: cat.slug} end)
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
```

Note: The `run_typed_query` for `watchlist_item_card` uses the `watchlisted` action which already filters by `actor(:id)` and the `category_id` argument. The filter params need to map correctly. If the typed query argument approach doesn't work directly via `run_typed_query`, we may need to pass the `category_id` as an argument instead of a filter.

**Verify:** `mix compile`

**Commit:** `feat: update WatchlistController with real data loading`

---

### Task 6: Create watchlist frontend components

**Files:**
- Create: `assets/js/features/watchlist/components/empty-watchlist.tsx`
- Create: `assets/js/features/watchlist/components/watchlist-item-card.tsx`
- Create: `assets/js/features/watchlist/components/watchlist-category-sidebar.tsx`
- Create: `assets/js/features/watchlist/index.ts`

**Step 1: Empty state component**

`empty-watchlist.tsx` — centered layout with:
- Illustration placeholder (use a div with the same dimensions as empty state, or an SVG placeholder)
- "Your Watchlist is empty." (text-lg font-semibold text-content)
- "Save items you like to compare prices, monitor bids, or bid for later." (text-sm text-content-tertiary)
- "Browse Items" button (outline style) linking to "/"

**Step 2: Watchlist item card**

`watchlist-item-card.tsx` — horizontal card (desktop) / vertical card (mobile):
- Desktop: flex row — image (left, ~300px) + details (right)
- Mobile: flex column — image (top, full width) + details (below)
- Details: title, price (₦ formatted), time left (countdown or badge), condition badge, "X bids · Y watching", vendor name, "Bid" button (primary orange)
- Use existing design tokens and patterns from other item cards
- Props: item data matching `WatchlistItemCard` type from ash_rpc.ts

**Step 3: Category sidebar**

`watchlist-category-sidebar.tsx` — desktop sidebar with:
- "All" option (active by default, with icon)
- Category list from props (each with icon and name)
- Active state: orange text + left border/background
- Clicking a category navigates via Inertia with `?category=<id>` query param

**Step 4: Barrel export**

`index.ts` — export all components

**Verify:** `cd assets && npx tsc --noEmit`

**Commit:** `feat: add watchlist page components`

---

### Task 7: Build the full watchlist page

**Files:**
- Modify: `assets/js/pages/watchlist.tsx`

Replace the placeholder page with the full implementation:

- If `items` is empty and no category filter is active → show empty state
- If items exist or a category filter is active → show populated state:
  - Desktop: sidebar (left) + items grid (right)
  - Mobile: filter dropdown (top) + items list
- "Watchlist" title
- Category filtering via Inertia router.visit with query params
- Mobile: search icon + "All" dropdown + filter icon in header

**Verify:** `cd assets && npx tsc --noEmit`

**Commit:** `feat: build full watchlist page with empty and populated states`

---

### Task 8: Integrate heart button on item cards

**Files:**
- Modify: `assets/js/features/items/components/item-card.tsx`
- Modify: `assets/js/features/items/components/category-item-card.tsx`
- Modify: `lib/angle_web/controllers/page_controller.ex` (load watchlisted IDs)
- Modify: `lib/angle_web/controllers/categories_controller.ex` (load watchlisted IDs)

**Step 1: Update item card components**

Add `isWatchlisted` and `onToggleWatchlist` props to ItemCard and CategoryItemCard:
- Heart button: filled (red) when in watchlist, outline when not
- On click: call `addToWatchlist` or `removeFromWatchlist` RPC function
- Use `useAshMutation` for the RPC call
- Optimistic update: toggle heart immediately, rollback on error

**Step 2: Update controllers to load watchlisted IDs**

In `page_controller.ex` and `categories_controller.ex`, if user is authenticated, load their watchlisted item IDs and pass as prop:

```elixir
defp load_watchlisted_ids(conn) do
  case conn.assigns[:current_user] do
    nil -> []
    _user ->
      case AshTypescript.Rpc.run_typed_query(:angle, :user_watchlist_ids, %{}, conn) do
        %{"success" => true, "data" => data} ->
          data
          |> extract_results()
          |> Enum.map(& &1["id"])
        _ -> []
      end
  end
end
```

Pass as: `assign_prop(conn, :watchlisted_ids, load_watchlisted_ids(conn))`

**Verify:** TypeScript compiles, heart button toggles in browser

**Commit:** `feat: integrate functional heart button on item cards`

---

### Task 9: Add controller tests

**Files:**
- Create: `test/angle_web/controllers/watchlist_controller_test.exs`

```elixir
defmodule AngleWeb.WatchlistControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /watchlist" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/watchlist")

      assert html_response(conn, 200) =~ "watchlist"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/watchlist")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
```

**Verify:** `mix test test/angle_web/controllers/watchlist_controller_test.exs`

**Commit:** `test: add watchlist controller tests`

---

### Task 10: Verification

**Step 1:** Run full test suite: `mix test`
**Step 2:** TypeScript compilation: `cd assets && npx tsc --noEmit`
**Step 3:** Browser verification:
- Navigate to `/watchlist` when empty → empty state shows
- Add items to watchlist via heart button on homepage
- Navigate to `/watchlist` → items appear
- Click category filter → items filter
- Remove from watchlist → item disappears
- Heart button shows filled state on pages where items are watchlisted

## Verification Checklist

After all tasks:
1. `mix test` — all tests pass
2. `cd assets && npx tsc --noEmit` — no new errors
3. `mix compile` — no warnings
4. Browser: empty state, populated state, category filter, heart toggle all work
5. Mobile: responsive layout matches Figma designs
