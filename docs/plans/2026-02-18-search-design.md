# Search Feature Design

## Overview

Add search functionality to the platform: a global search bar in the navbar for buyers to find published items, a full search results page with filters at `/search`, and a text filter on the seller's My Listings page.

## Requirements

- **Buyers** search the marketplace for published items
- **Sellers** filter their own listings by title on the My Listings page
- Global search bar in the navbar (every page), submit-and-go (no autocomplete)
- Dedicated `/search` results page with full-text search + faceted filters
- Postgres-native: tsvector for relevance-ranked full-text search, pg_trgm for typo tolerance

## Database Layer

### Migration

1. Enable `pg_trgm` extension
2. Add `search_vector tsvector` column to `items`
3. Create a Postgres trigger to auto-populate `search_vector` on INSERT/UPDATE from:
   - `title` (weight A — higher relevance)
   - `description` (weight B — lower relevance)
4. Backfill existing rows
5. Create GIN index on `search_vector` for fast full-text queries
6. Create GIN trigram index on `title` using `gin_trgm_ops` for fuzzy matching

### Query Strategy

- **Primary:** `ts_rank(search_vector, plainto_tsquery('english', query))` — handles stemming, ranking
- **Fuzzy fallback:** `similarity(title, query)` via pg_trgm for typo tolerance (e.g. "iphon" matches "iPhone")
- **Combined scoring:** Results ordered by ts_rank first, similarity as tiebreaker
- Only published items are searchable

## Ash Resource & Domain Layer

### New read action on Item: `:search`

Arguments:
- `query` (string, required) — the search text
- `category_id` (uuid, optional)
- `condition` (atom, optional)
- `min_price` / `max_price` (decimal, optional)
- `sale_type` (atom, optional)
- `auction_status` (atom, optional)
- `sort_by` (atom, optional) — relevance (default), price_asc, price_desc, newest, ending_soon

Behavior:
- Always filters by `publication_status == :published`
- Uses a custom Ash preparation to build the tsvector/trgm query via raw SQL fragment for ranking
- Supports pagination (limit/offset/count)

### New typed query: `:search_items`

Defined in `Angle.Inventory` domain, maps to the `:search` action.

Fields: id, title, slug, description (truncated), starting_price, current_price, end_time, auction_status, condition, sale_type, location, view_count, bid_count, category (id, name, slug), images (thumbnail variant)

### Seller dashboard enhancement

Update `:my_listings` action: add an optional `query` string argument. When present, filter with `ilike(title, "%#{query}%")` — seller's own items are a small set, no need for tsvector.

## Controller & Routing

### New: `SearchController`

- `GET /search` — `index/2` action
- Parses query params: `q`, `category`, `condition`, `min_price`, `max_price`, `sale_type`, `auction_status`, `sort` (default: relevance)
- Calls `run_typed_query(:angle, :search_items, params, conn)`
- Passes results + filters + pagination + categories list as Inertia props
- Renders `"search"` page
- If `q` is blank, renders page with empty results and filter controls only (no DB query)

### Route

`get "/search", SearchController, :index` in the `:browser` scope.

### Seller dashboard update

`StoreDashboardController.listings/2` — add `search` param parsing, pass as `query` input to the existing `seller_dashboard_card` typed query.

### Navigation pattern

Filter changes on the search page trigger `router.get("/search", { ...newParams })` — Inertia handles the round-trip, keeps URL in sync. No client-side RPC calls needed.

## Frontend

### Navbar search input

- Add a search form to the existing React navigation/header component
- Simple text input with search icon, styled to fit current nav
- On submit (Enter key), navigates via `router.get("/search", { q: query })`
- No autocomplete, no dropdown

### New page: `assets/js/pages/search.tsx`

Props: items, pagination, filters (current active filters), query, categories (for dropdown)

Layout:
- Search bar at top (pre-filled with current query)
- Filter sidebar/bar: category dropdown, condition select, price range (min/max), sale type, auction status, sort dropdown
- Results grid reusing existing item card component
- Pagination: desktop page numbers + per-page selector, mobile load more
- Filter changes trigger `router.get("/search", { ...currentParams, ...newFilters })`
- Empty state: "No items found for [query]. Try different keywords or adjust your filters."

### Seller listings update: `assets/js/pages/store/listings.tsx`

- Add a text search input above the existing status tabs
- Smaller visual weight than navbar search (inline filter, not a prominent search bar)
- On change (debounced ~300ms), triggers `router.get` with `search` param
- Filters seller's own listings by title match

## Testing

### Backend

- **Search action test** (`test/angle/inventory/item_search_test.exs`): text search returns matches (exact, partial, stemmed), typo tolerance via trigram, filters narrow results, only published items returned, pagination works
- **Controller test** (`test/angle_web/controllers/search_controller_test.exs`): GET /search returns 200 + correct props, blank query returns empty results, filter combinations work, pagination props correct
- **Seller search test**: add test case to existing store dashboard controller tests — `search` param filters listings by title

### Frontend

No JS tests (consistent with current project).
