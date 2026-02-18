# Item Card Images Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add real item cover images to ActiveBidCard, HistoryBidCard, WonBidCard, and ListingCard.

**Architecture:** Add a new `attach_nested_cover_images/2` helper for bid/order cards where item data is nested, use existing `attach_cover_images/1` for listings. Update 4 React components to render `<ResponsiveImage>` with Gavel icon fallback.

**Tech Stack:** Elixir/Phoenix controllers, React/TypeScript components, existing `ResponsiveImage` component

---

### Task 1: Add `attach_nested_cover_images/2` to ImageHelpers

**Files:**
- Modify: `lib/angle_web/controllers/image_helpers.ex`

**Step 1: Add the new function**

Add after the existing `attach_cover_images/1` function (after line 27):

```elixir
@doc """
Given a list of records with nested item maps (e.g. bids or orders),
loads cover images for the nested items and attaches them.
The `item_key` parameter is the string key where the item map lives
(e.g. "item" for bid["item"]).
"""
@spec attach_nested_cover_images(list(map()), String.t()) :: list(map())
def attach_nested_cover_images([], _item_key), do: []

def attach_nested_cover_images(records, item_key) when is_list(records) do
  item_ids =
    records
    |> Enum.map(fn record -> get_in(record, [item_key, "id"]) end)
    |> Enum.reject(&is_nil/1)

  if item_ids == [] do
    records
  else
    {:ok, images} = Angle.Media.list_cover_images(item_ids, authorize?: false)

    cover_images =
      Map.new(images, fn img ->
        {img.owner_id, serialize_image(img)}
      end)

    Enum.map(records, fn record ->
      item_id = get_in(record, [item_key, "id"])

      case item_id do
        nil ->
          record

        id ->
          item_with_image =
            Map.put(record[item_key], "coverImage", Map.get(cover_images, id))

          Map.put(record, item_key, item_with_image)
      end
    end)
  end
end
```

**Step 2: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles cleanly

**Step 3: Commit**

```bash
git add lib/angle_web/controllers/image_helpers.ex
git commit -m "feat: add attach_nested_cover_images helper for bid/order cards"
```

---

### Task 2: Attach images in BidsController (all 3 tabs)

**Files:**
- Modify: `lib/angle_web/controllers/bids_controller.ex`

**Step 1: Add import**

At line 4, update the import:
```elixir
alias AngleWeb.ImageHelpers
```

**Step 2: Attach images in `load_active_tab`**

After the `bids` are extracted (line 28-30), pipe through the helper:
```elixir
bids =
  case AshTypescript.Rpc.run_typed_query(:angle, :active_bid_card, params, conn) do
    %{"success" => true, "data" => data} -> extract_results(data)
    _ -> []
  end
  |> ImageHelpers.attach_nested_cover_images("item")
```

**Step 3: Attach images in `load_won_tab`**

After orders are extracted (line 41-45), pipe through the helper:
```elixir
orders =
  case AshTypescript.Rpc.run_typed_query(:angle, :won_order_card, params, conn) do
    %{"success" => true, "data" => data} -> extract_results(data)
    _ -> []
  end
  |> ImageHelpers.attach_nested_cover_images("item")
```

**Step 4: Attach images in `load_history_tab`**

After bids are extracted (line 84-88), pipe through the helper:
```elixir
bids =
  case AshTypescript.Rpc.run_typed_query(:angle, :history_bid_card, bid_params, conn) do
    %{"success" => true, "data" => data} -> extract_results(data)
    _ -> []
  end
  |> ImageHelpers.attach_nested_cover_images("item")
```

**Step 5: Run tests**

Run: `mix test test/angle_web/controllers/bids_controller_test.exs`
Expected: All tests pass

**Step 6: Commit**

```bash
git add lib/angle_web/controllers/bids_controller.ex
git commit -m "feat: attach cover images to bid and order cards"
```

---

### Task 3: Attach images in StoreDashboardController (listings)

**Files:**
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex`

**Step 1: Add alias**

Add alias near the top:
```elixir
alias AngleWeb.ImageHelpers
```

**Step 2: Attach images in `listings/2`**

In `listings/2` (line 81), the `items` come from `load_seller_items` which returns `{items, total}`. After that call, attach images:

```elixir
{items, total} = load_seller_items(conn, status, page, per_page, sort, dir)
items = ImageHelpers.attach_cover_images(items)
```

**Step 3: Run tests**

Run: `mix test test/angle_web/controllers/store_dashboard_controller_test.exs`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/store_dashboard_controller.ex
git commit -m "feat: attach cover images to seller listing cards"
```

---

### Task 4: Update ActiveBidCard component

**Files:**
- Modify: `assets/js/features/bidding/components/active-bid-card.tsx`

**Step 1: Add imports**

```typescript
import { Gavel } from "lucide-react";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
```

**Step 2: Replace desktop placeholder (line 28)**

Replace:
```tsx
<div className="aspect-square overflow-hidden rounded-xl bg-surface-muted" />
```

With:
```tsx
<div className="aspect-square overflow-hidden rounded-xl bg-surface-muted">
  {item.coverImage ? (
    <ResponsiveImage
      image={item.coverImage as ImageData}
      sizes="280px"
      alt={item.title}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-10" />
    </div>
  )}
</div>
```

**Step 3: Replace mobile placeholder (line 63)**

Replace:
```tsx
<div className="aspect-square overflow-hidden rounded-xl bg-surface-muted" />
```

With:
```tsx
<div className="aspect-square overflow-hidden rounded-xl bg-surface-muted">
  {item.coverImage ? (
    <ResponsiveImage
      image={item.coverImage as ImageData}
      sizes="(max-width: 1024px) 50vw, 280px"
      alt={item.title}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-8" />
    </div>
  )}
</div>
```

**Step 4: Commit**

```bash
git add assets/js/features/bidding/components/active-bid-card.tsx
git commit -m "feat: show real images in ActiveBidCard"
```

---

### Task 5: Update HistoryBidCard component

**Files:**
- Modify: `assets/js/features/bidding/components/history-bid-card.tsx`

**Step 1: Add imports**

```typescript
import { Gavel } from "lucide-react";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
```

**Step 2: Replace desktop placeholder (line 43)**

Replace:
```tsx
<div className="size-full rounded-lg bg-surface-muted" />
```

With:
```tsx
<div className="size-full overflow-hidden rounded-lg bg-surface-muted">
  {item?.coverImage ? (
    <ResponsiveImage
      image={item.coverImage as ImageData}
      sizes="80px"
      alt={item?.title || ""}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-6" />
    </div>
  )}
</div>
```

**Step 3: Replace mobile placeholder (line 77)**

Replace:
```tsx
<div className="size-full rounded-lg bg-surface-muted" />
```

With:
```tsx
<div className="size-full overflow-hidden rounded-lg bg-surface-muted">
  {item?.coverImage ? (
    <ResponsiveImage
      image={item.coverImage as ImageData}
      sizes="80px"
      alt={item?.title || ""}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-6" />
    </div>
  )}
</div>
```

**Step 4: Commit**

```bash
git add assets/js/features/bidding/components/history-bid-card.tsx
git commit -m "feat: show real images in HistoryBidCard"
```

---

### Task 6: Update WonBidCard component

**Files:**
- Modify: `assets/js/features/bidding/components/won-bid-card.tsx`

**Step 1: Add imports**

```typescript
import { Gavel } from "lucide-react";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
```

**Step 2: Replace desktop placeholder (line 93)**

Replace:
```tsx
<div className="size-full rounded-lg bg-surface-muted" />
```

With:
```tsx
<div className="size-full overflow-hidden rounded-lg bg-surface-muted">
  {order.item?.coverImage ? (
    <ResponsiveImage
      image={order.item.coverImage as ImageData}
      sizes="80px"
      alt={order.item?.title || ""}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-6" />
    </div>
  )}
</div>
```

**Step 3: Replace mobile placeholder (line 191)**

Replace:
```tsx
<div className="size-full rounded-lg bg-surface-muted" />
```

With:
```tsx
<div className="size-full overflow-hidden rounded-lg bg-surface-muted">
  {order.item?.coverImage ? (
    <ResponsiveImage
      image={order.item.coverImage as ImageData}
      sizes="80px"
      alt={order.item?.title || ""}
    />
  ) : (
    <div className="flex h-full items-center justify-center text-content-placeholder">
      <Gavel className="size-6" />
    </div>
  )}
</div>
```

**Step 4: Commit**

```bash
git add assets/js/features/bidding/components/won-bid-card.tsx
git commit -m "feat: show real images in WonBidCard"
```

---

### Task 7: Update ListingCard component

**Files:**
- Modify: `assets/js/features/store-dashboard/components/listing-card.tsx`

**Step 1: Add imports**

```typescript
import { Gavel } from "lucide-react";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
```

**Step 2: Add image to the card layout**

The ListingCard currently has no image area. Add a thumbnail to the left side of the card content. Replace the card's inner div structure:

Before:
```tsx
<div className="rounded-xl border border-surface-muted bg-surface p-4">
  <div className="flex items-start justify-between">
    <div className="min-w-0 flex-1">
```

After:
```tsx
<div className="rounded-xl border border-surface-muted bg-surface p-4">
  <div className="flex items-start gap-3">
    <div className="size-16 shrink-0 overflow-hidden rounded-lg bg-surface-muted">
      {(item as any).coverImage ? (
        <ResponsiveImage
          image={(item as any).coverImage as ImageData}
          sizes="64px"
          alt={item.title || ""}
        />
      ) : (
        <div className="flex h-full items-center justify-center text-content-placeholder">
          <Gavel className="size-5" />
        </div>
      )}
    </div>
    <div className="min-w-0 flex-1">
```

Note: Close the wrapping div structure appropriately. The `justify-between` changes to `gap-3` since the menu is inside the flex-1 content area.

**Step 3: Commit**

```bash
git add assets/js/features/store-dashboard/components/listing-card.tsx
git commit -m "feat: show real images in ListingCard"
```

---

### Task 8: Final verification

**Step 1: Run full test suite**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 2: Build assets for SSR**

Run: `mix assets.build`
Expected: Builds successfully

**Step 3: Visual QA**

Start server and verify each page:
- `localhost:<port>/bids?tab=active` — ActiveBidCard shows item images
- `localhost:<port>/bids?tab=history` — HistoryBidCard shows item images
- `localhost:<port>/bids?tab=won` — WonBidCard shows item images
- `localhost:<port>/store/listings` — ListingCard shows item thumbnails
