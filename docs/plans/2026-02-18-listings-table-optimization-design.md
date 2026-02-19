# Listings Table Optimization

## Context

The store dashboard listings table (`/store/listings`) has several broken or suboptimal behaviors that need fixing. This is a fix-what's-broken scope, not a redesign.

## Issues & Fixes

### 1. Sorting Not Working

**Problem:** The `:my_listings` Ash action defines `sort_field` and `sort_dir` as `:atom` arguments, but the controller passes string values (`"view_count"`, `"desc"`) via `run_typed_query`. The strings likely fail atom constraint validation silently and fall back to defaults (`:inserted_at`, `:desc`).

**Fix:** Convert string params to atoms in the controller before building the typed query input map, using `String.to_existing_atom/1` — or verify whether `run_typed_query` handles coercion and fix at the appropriate layer.

**Files:** `lib/angle_web/controllers/store_dashboard_controller.ex` (lines 155-177)

### 2. Status Filter Not Working

**Problem:** Same string/atom mismatch. `status_filter` is `:atom` with `one_of: [:all, :active, :ended, :draft]`, but the controller passes `"active"` etc.

**Fix:** Same approach as sorting — convert to atom before passing.

**Files:** `lib/angle_web/controllers/store_dashboard_controller.ex` (line 159)

### 3. Status Display Incorrect

**Problem:** The status badge in the table only reads `auctionStatus` and falls back to "draft" when null. This works for draft items by coincidence but doesn't properly distinguish draft vs published items.

**Fix:** Derive display status from both `publicationStatus` and `auctionStatus`:
- If `publicationStatus == "draft"` → show "Draft"
- Otherwise → show the granular `auctionStatus` (Pending, Scheduled, Active, Paused, Ended, Sold, Cancelled)

**Files:** `assets/js/features/store-dashboard/components/listing-table.tsx` (StatusBadge component, line 31-51)

### 4. Stats Are Inaccurate (In-Memory Aggregation)

**Problem:** `load_seller_stats/1` fetches up to 1000 items via the typed query, then computes `SUM(viewCount)`, `COUNT(bids)`, `COUNT(watchlist_items)`, and `SUM(currentPrice)` in Elixir memory. This caps at 1000 items and re-runs the full query just for aggregation.

**Fix:** Replace with a dedicated Ash read action or code interface that uses database-level aggregates (`sum`/`count`). Single query, no item limit, accurate results.

**Files:**
- `lib/angle/inventory/item.ex` — new read action or aggregates
- `lib/angle/inventory.ex` — new code interface if needed
- `lib/angle_web/controllers/store_dashboard_controller.ex` — replace `load_seller_stats/1`

### 5. Actions Dropdown Clipped by Pagination

**Problem:** The custom actions dropdown (`ListingActionsMenu`) uses `z-10` and `position: absolute` relative to its table cell. For the last rows, the dropdown opens downward and gets clipped by the table's `overflow-x-auto` wrapper or hidden behind the pagination controls.

**Fix:** Replace the custom dropdown with shadcn's `DropdownMenu` component, which renders via a portal outside the table DOM — avoiding all overflow and z-index issues.

**Files:** `assets/js/features/store-dashboard/components/listing-actions-menu.tsx`

### 6. Item Title Should Be a Link

**Problem:** Item titles in the table are plain text. Users can't click to view the item.

**Fix:** Wrap the title in a `<Link>` with conditional navigation:
- Draft items → `/store/listings/{id}/preview`
- Published items → `/items/{slug}`

**Files:** `assets/js/features/store-dashboard/components/listing-table.tsx` (line 212-214), `assets/js/features/store-dashboard/components/listing-card.tsx` (mobile card equivalent)
