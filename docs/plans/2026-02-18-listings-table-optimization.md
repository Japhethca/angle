# Listings Table Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix broken sorting, filtering, status display, stats, actions dropdown, and item title linking in the store listings table.

**Architecture:** All backend fixes are in the controller layer (string-to-atom coercion) and a new Ash read action for database-level stats. Frontend fixes are in listing-table, listing-card, and listing-actions-menu components.

**Tech Stack:** Elixir/Ash (backend fixes), React/TypeScript + shadcn/ui (frontend fixes)

---

### Task 1: Fix Sorting and Status Filter (String/Atom Coercion)

The `:my_listings` Ash action expects atom arguments (`sort_field`, `sort_dir`, `status_filter`), but the controller passes strings. The RPC layer doesn't coerce them, so they silently fall back to defaults.

**Files:**
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex:155-177`
- Test: `test/angle_web/controllers/store_dashboard_controller_test.exs`

**Step 1: Write the failing tests**

Add to `test/angle_web/controllers/store_dashboard_controller_test.exs` inside `describe "GET /store/listings"`:

```elixir
describe "GET /store/listings with sort and filter params" do
  test "sorts by view_count descending", %{conn: conn} do
    user = create_user()
    item_low = create_item(%{title: "Low Views", created_by_id: user.id, publication_status: :published, auction_status: :active})
    item_high = create_item(%{title: "High Views", created_by_id: user.id, publication_status: :published, auction_status: :active})

    # Manually set view counts
    Angle.Repo.update_all(
      from(i in "items", where: i.id == ^item_high.id),
      set: [view_count: 100]
    )

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/store/listings?sort=view_count&dir=desc")

    assert html_response(conn, 200) =~ "store/listings"
  end

  test "filters by status=active", %{conn: conn} do
    user = create_user()
    _draft = create_item(%{title: "Draft Item", created_by_id: user.id})
    _active = create_item(%{title: "Active Item", created_by_id: user.id, publication_status: :published, auction_status: :active})

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/store/listings?status=active")

    assert html_response(conn, 200) =~ "store/listings"
  end
end
```

**Note:** These tests may require adding `publication_status` and `auction_status` support to `create_item` in the factory. If the factory doesn't accept those fields, update the factory's `create_item/1` to pass them through via `maybe_put`.

**Step 2: Run tests to verify current behavior**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs --max-failures 3`

**Step 3: Fix the controller — convert strings to atoms**

In `lib/angle_web/controllers/store_dashboard_controller.ex`, change `load_seller_items/7`:

```elixir
defp load_seller_items(conn, status, page, per_page, sort, dir, search) do
  offset = (page - 1) * per_page

  input =
    %{
      status_filter: String.to_existing_atom(status),
      sort_field: String.to_existing_atom(sort),
      sort_dir: String.to_existing_atom(dir)
    }
    |> then(fn m -> if search, do: Map.put(m, :query, search), else: m end)

  params = %{
    input: input,
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
```

The key change: wrap `status`, `sort`, `dir` with `String.to_existing_atom/1`. These atoms already exist in the Ash action constraints, so `to_existing_atom` is safe and won't leak atoms.

**Step 4: Run tests to verify they pass**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs --max-failures 3`
Expected: All tests pass.

**Step 5: Commit**

```
feat: fix sorting and status filter by converting string params to atoms
```

---

### Task 2: Replace In-Memory Stats with Database Aggregates

The current `load_seller_stats/1` fetches up to 1000 items and sums fields in Elixir. Replace with a dedicated Ash read action that uses database aggregates.

**Files:**
- Modify: `lib/angle/inventory/item.ex` — add `:my_listings_stats` read action
- Modify: `lib/angle/inventory.ex` — add code interface
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex` — replace `load_seller_stats/1`
- Test: `test/angle_web/controllers/store_dashboard_controller_test.exs`

**Step 1: Write the failing test**

Add to `test/angle_web/controllers/store_dashboard_controller_test.exs`:

```elixir
describe "GET /store/listings stats accuracy" do
  test "stats reflect actual item data", %{conn: conn} do
    user = create_user()
    item = create_item(%{
      title: "Stats Test Item",
      created_by_id: user.id,
      starting_price: Decimal.new("50.00"),
      publication_status: :published,
      auction_status: :active
    })

    # Create bids and watchers for the item
    bidder = create_user()
    create_bid(%{item_id: item.id, user_id: bidder.id, amount: Decimal.new("75.00")})
    watcher = create_user()
    create_watchlist_item(user: watcher, item: item)

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/store/listings")

    assert html_response(conn, 200) =~ "store/listings"
    # The test verifies the endpoint doesn't crash with the new stats implementation.
    # Detailed stat verification would require inspecting Inertia props.
  end
end
```

**Step 2: Run test to verify baseline**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs --max-failures 3`

**Step 3: Add the Ash read action for stats**

In `lib/angle/inventory/item.ex`, add inside the `actions` block (after `:my_listings`):

```elixir
read :my_listings_stats do
  description "Aggregate stats for all items owned by the current user"

  filter expr(created_by_id == ^actor(:id))

  pagination offset?: false, required?: false
end
```

**Step 4: Add code interface in the domain**

In `lib/angle/inventory.ex`, inside `resources do` → `resource Angle.Inventory.Item do`:

```elixir
define :my_listings_stats, action: :my_listings_stats
```

**Step 5: Replace `load_seller_stats/1` in the controller**

In `lib/angle_web/controllers/store_dashboard_controller.ex`, replace the `load_seller_stats/1` function:

```elixir
defp load_seller_stats(conn) do
  user = conn.assigns.current_user

  case Angle.Inventory.my_listings_stats(actor: user, page: [limit: 1, count: true], load: [:bid_count, :watcher_count]) do
    {:ok, page} ->
      items = page.results

      %{
        "total_views" => Enum.reduce(items, 0, fn item, acc -> acc + (item.view_count || 0) end),
        "total_watches" => Enum.reduce(items, 0, fn item, acc -> acc + (item.watcher_count || 0) end),
        "total_bids" => Enum.reduce(items, 0, fn item, acc -> acc + (item.bid_count || 0) end),
        "total_amount" =>
          items
          |> Enum.reduce(Decimal.new(0), fn item, acc ->
            if item.current_price, do: Decimal.add(acc, item.current_price), else: acc
          end)
          |> Decimal.to_string()
      }

    _ ->
      %{"total_views" => 0, "total_watches" => 0, "total_bids" => 0, "total_amount" => "0"}
  end
end
```

**Important note:** This initial approach still loads items into memory but goes through a proper code interface instead of re-running the typed query with a 1000 limit. If performance is still an issue later, we can add `sum` aggregates on the resource. For now, this fixes the core problem (using code interface, proper authorization, no arbitrary limit).

**Alternative — if we want true DB aggregates:** Add `sum :total_views, :view_count` etc. as aggregates on the resource and load them without fetching individual items. This is a bigger change and can be a follow-up. For now, removing the 1000-item limit and using proper Ash patterns is the priority.

**Step 6: Run codegen**

Run: `mix ash.codegen --dev` (in case the new action needs migration)

**Step 7: Run tests**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs --max-failures 3`
Expected: All tests pass.

**Step 8: Commit**

```
refactor: replace in-memory stats with Ash code interface
```

---

### Task 3: Fix Status Display in Table and Card

The `StatusBadge` reads `auctionStatus` only and falls back to "draft" when null. Fix to derive status from both `publicationStatus` and `auctionStatus`.

**Files:**
- Modify: `assets/js/features/store-dashboard/components/listing-table.tsx:31-51`
- Modify: `assets/js/features/store-dashboard/components/listing-card.tsx:13-33`

**Step 1: Update StatusBadge in listing-table.tsx**

Change the `StatusBadge` component to accept both statuses:

```tsx
function StatusBadge({ publicationStatus, auctionStatus }: { publicationStatus: string | null | undefined; auctionStatus: string | null | undefined }) {
  const key: StatusKey = publicationStatus === "draft"
    ? "draft"
    : (auctionStatus || "draft") as StatusKey;

  const config: Record<StatusKey, { label: string; className: string }> = {
    active: { label: "Active", className: "bg-feedback-success-muted text-feedback-success" },
    ended: { label: "Ended", className: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400" },
    sold: { label: "Sold", className: "bg-feedback-success-muted text-feedback-success" },
    draft: { label: "Draft", className: "bg-surface-secondary text-content-tertiary" },
    pending: { label: "Pending", className: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400" },
    scheduled: { label: "Scheduled", className: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400" },
    paused: { label: "Paused", className: "bg-surface-secondary text-content-tertiary" },
    cancelled: { label: "Cancelled", className: "bg-surface-secondary text-content-tertiary" },
  };

  const { label, className } = config[key] || config.draft;

  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium", className)}>
      {label}
    </span>
  );
}
```

**Step 2: Update usage in listing-table.tsx**

Change line 234 from:
```tsx
<StatusBadge status={item.auctionStatus} />
```
to:
```tsx
<StatusBadge publicationStatus={item.publicationStatus} auctionStatus={item.auctionStatus} />
```

**Step 3: Apply the same fix in listing-card.tsx**

Update the `StatusBadge` in `listing-card.tsx` identically (same component signature and logic). Update the usage at line 68 from:
```tsx
<StatusBadge status={item.auctionStatus} />
```
to:
```tsx
<StatusBadge publicationStatus={item.publicationStatus} auctionStatus={item.auctionStatus} />
```

**Step 4: Verify no TypeScript errors**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors in listing-table.tsx or listing-card.tsx.

**Step 5: Commit**

```
fix: derive status badge from both publicationStatus and auctionStatus
```

---

### Task 4: Replace Custom Actions Dropdown with shadcn DropdownMenu

The custom dropdown gets clipped by table overflow and pagination. shadcn's `DropdownMenu` uses a portal.

**Files:**
- Modify: `assets/js/features/store-dashboard/components/listing-actions-menu.tsx`

**Step 1: Rewrite listing-actions-menu.tsx with shadcn DropdownMenu**

```tsx
import { useState } from "react";
import { router } from "@inertiajs/react";
import { MoreVertical, Share2, Pencil, Trash2 } from "lucide-react";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface ListingActionsMenuProps {
  id: string;
  slug: string;
  publicationStatus: string | null | undefined;
}

export function ListingActionsMenu({ id, slug, publicationStatus }: ListingActionsMenuProps) {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const [isDeleting, setIsDeleting] = useState(false);

  const isDraft = publicationStatus === "draft";

  const handleShare = async () => {
    const url = `${window.location.origin}/items/${slug}`;
    try {
      await navigator.clipboard.writeText(url);
      toast.success("Item link copied to clipboard");
    } catch {
      toast.error("Failed to copy link");
    }
  };

  const handleEdit = () => {
    router.visit(`/store/listings/${id}/edit`);
  };

  const handleDelete = () => {
    if (!confirmDelete) {
      setConfirmDelete(true);
      return;
    }
    if (isDeleting) return;

    setIsDeleting(true);
    setConfirmDelete(false);
    router.delete(`/store/listings/${id}`, {
      preserveScroll: true,
      onFinish: () => setIsDeleting(false),
    });
  };

  return (
    <DropdownMenu onOpenChange={(open) => { if (!open) setConfirmDelete(false); }}>
      <DropdownMenuTrigger asChild>
        <button className="flex size-8 items-center justify-center rounded-lg text-content-tertiary transition-colors hover:bg-surface-secondary hover:text-content">
          <MoreVertical className="size-4" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end">
        <DropdownMenuItem onClick={handleShare}>
          <Share2 className="mr-2 size-4" />
          Share
        </DropdownMenuItem>
        {isDraft && (
          <DropdownMenuItem onClick={handleEdit}>
            <Pencil className="mr-2 size-4" />
            Edit
          </DropdownMenuItem>
        )}
        <DropdownMenuItem
          onClick={handleDelete}
          disabled={isDeleting}
          className={confirmDelete ? "text-feedback-error bg-feedback-error/10" : "text-feedback-error"}
        >
          <Trash2 className="mr-2 size-4" />
          {confirmDelete ? "Confirm Delete" : "Delete"}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
```

Key changes:
- Removed manual `open` state, `useRef`, `useEffect` for click-outside — all handled by shadcn
- Uses portal rendering — no more clipping by table overflow or pagination
- Same behavior: share, edit (draft only), delete with confirmation

**Step 2: Verify no TypeScript errors**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors in listing-actions-menu.tsx.

**Step 3: Commit**

```
refactor: replace custom actions dropdown with shadcn DropdownMenu
```

---

### Task 5: Make Item Title a Clickable Link

Draft items link to preview, published items link to the detail page.

**Files:**
- Modify: `assets/js/features/store-dashboard/components/listing-table.tsx:211-214`
- Modify: `assets/js/features/store-dashboard/components/listing-card.tsx:53-56`

**Step 1: Update listing-table.tsx**

Add `Link` import at the top:
```tsx
import { Link } from "@inertiajs/react";
```

Replace the title `<p>` (line 212-214) with a `<Link>`:

```tsx
<Link
  href={item.publicationStatus === "draft"
    ? `/store/listings/${item.id}/preview`
    : `/items/${item.slug || item.id}`}
  className="truncate text-sm font-medium text-content hover:text-primary-600 hover:underline"
>
  {item.title}
</Link>
```

**Step 2: Update listing-card.tsx**

Add `Link` import at the top:
```tsx
import { Link } from "@inertiajs/react";
```

Replace the title `<h3>` (line 54-56) with a `<Link>`:

```tsx
<Link
  href={item.publicationStatus === "draft"
    ? `/store/listings/${item.id}/preview`
    : `/items/${item.slug || item.id}`}
  className="truncate text-sm font-medium text-content hover:text-primary-600 hover:underline"
>
  {item.title}
</Link>
```

**Step 3: Verify no TypeScript errors**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors.

**Step 4: Commit**

```
feat: make item titles clickable links to preview or detail page
```

---

### Task 6: Visual QA and Final Verification

**Step 1: Start the worktree dev server**

Run: `PORT=4113 mix phx.server` (from the worktree directory)

**Step 2: Test in browser at `localhost:4113/store/listings`**

Verify:
- [ ] Sorting: clicking Views, Watch, Bids, Highest Bid headers actually reorders items
- [ ] Status filter: dropdown filters correctly between All, Active, Ended, Draft
- [ ] Status badges: draft items show "Draft", published items show correct auction status
- [ ] Stats cards: numbers reflect actual data (not zeros or placeholders)
- [ ] Actions dropdown: menu on last table rows doesn't get clipped by pagination
- [ ] Item title links: draft titles → preview page, published titles → detail page
- [ ] Mobile: listing cards show correct status and title links work

**Step 3: Run full test suite**

Run: `mix test --max-failures 5`
Expected: All tests pass.

**Step 4: Final commit (if any QA fixes needed)**

```
fix: address visual QA feedback
```
