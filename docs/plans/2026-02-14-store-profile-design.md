# Store Profile Page — Design Document

## Goal

Allow guest users to view a seller's public store profile, including their listed items, contact info, and category breakdown. This is a V1 with placeholders for reviews, ratings, and followers.

## Decisions

- **Scope:** V1 essentials with real data + placeholders for reviews/ratings/followers
- **URL format:** `/store/:identifier` where identifier is a username (preferred) or UUID (fallback)
- **Tabs:** Auctions (real data), History (real data), Reviews (placeholder)
- **Data loading:** Hybrid — controller loads profile + initial Auctions tab; client-side RPC for tab switching and load-more
- **Entry points:** Seller link on item detail page + direct URL access

## Backend — User Resource Changes

New fields on `Angle.Accounts.User`:

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `username` | `:string` | No | URL slug, unique, lowercase alphanumeric + hyphens |
| `location` | `:string` | No | Free text, e.g. "Ikeja, Lagos" |
| `whatsapp_number` | `:string` | No | WhatsApp contact number |
| `store_name` | `:string` | No | Display name for store (falls back to `full_name`) |

New read action: `read_public_profile` — public, accepts username or id, returns limited public fields only.

No changes to reviews, ratings, or followers in V1.

## Backend — Items & Typed Queries

**New read action on Item:** `by_seller`
- Argument: `seller_id` (UUID, required)
- Argument: `status_filter` (atom, defaults to `:active`)
  - `:active` — `publication_status == :published` AND `auction_status in [:active, :scheduled, :pending]`
  - `:history` — `publication_status == :published` AND `auction_status in [:ended, :sold]`
- Pagination: offset-based

**New typed queries:**

1. `seller_profile` (Accounts domain) — id, username, full_name, store_name, location, phone_number, whatsapp_number, inserted_at
2. `seller_item_card` (Inventory domain) — same shape as `category_item_card`: id, title, slug, starting_price, current_price, end_time, auction_status, condition, sale_type, view_count, bid_count, category (id, name, slug)

**Category summary:** Loaded as a separate query or derived in the controller by grouping seller's items by category.

## Routing & Controller

New public route (no auth required):

```
GET /store/:identifier    StoreController, :show
```

Controller `AngleWeb.StoreController` — `show/2`:
1. Determine if identifier is UUID or username
2. Load seller profile via `seller_profile` typed query
3. Not found → redirect to `/` with flash error
4. Load initial items (Auctions tab) via `seller_item_card` typed query
5. Load category summary
6. Pass Inertia props: seller, items, has_more, category_summary, active_tab
7. Render `"store/show"`

## Frontend — Store Profile Page

**Page:** `assets/js/pages/store/show.tsx`

**Header:**
- Avatar placeholder (generic icon)
- Store name (or full_name fallback) with item count
- Verification badge placeholder (static)
- Stats row: rating, reviews, followers — all placeholder
- Join date, contact info (location, phone, WhatsApp — shown if data exists)
- Category chips with counts
- Follow button (placeholder) + Share button (copies URL)

**Tabs:**
- **Auctions** — item grid using existing `CategoryItemCard`. Server-loaded initially, load-more via RPC.
- **History** — same grid, fetched client-side via `useAshQuery` on tab activation. Items with ended/sold status.
- **Reviews** — "Coming soon" placeholder

**Responsive:** Desktop 4-column grid, mobile 2-column grid (per Figma).

**Item detail page link:** Seller card on `pages/items/show.tsx` links to `/store/:username` (or `/store/:id`).

## Testing

Controller tests:
- Renders store/show for valid seller by username
- Renders store/show for valid seller by UUID
- Redirects to `/` when not found
- Includes published items, excludes drafts
- Shows category summary

Error handling:
- Seller not found → redirect to `/`
- No items → "No items listed yet" empty state
- Missing optional fields → simply not rendered
