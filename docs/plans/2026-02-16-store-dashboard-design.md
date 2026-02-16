# Store Dashboard Design

## Overview

A seller management dashboard at `/store/*` with three tabs: Listings, Payments, and Store Profile. Allows sellers to manage their items, view payment history, and maintain their store profile.

## Figma References

| Screen | Desktop Node | Mobile Node |
|--------|-------------|-------------|
| Listings | `662-8377`, `664-12133` | `722-9486`, `722-11279` |
| Payments | `664-12614` | `722-10717` |
| Store Profile | `664-13079` | `722-10433` |

## URL Structure

- `/store` → redirects to `/store/listings`
- `/store/listings` — Item management dashboard
- `/store/payments` — Payment history and balance
- `/store/profile` — Seller's own store profile with reviews

All routes require authentication.

## Layout: `<StoreLayout>`

Follows the existing `<SettingsLayout>` pattern.

**Desktop:** Left sidebar (240px) with navigation items (Listings, Payments, Store Profile) using Lucide icons. Breadcrumb above content area ("Store > Listings").

**Mobile:** Horizontal tabs at top (Listings | Payments | Store Profile). No sidebar.

**Header CTA:** Desktop navbar shows "Sell Item" button on Listings tab, "Withdraw" button on Payments tab.

## Tab 1: Listings (`/store/listings`)

### Stats Cards

Four cards in a row (desktop) or 2x2 grid (mobile):

| Card | Icon | Data Source |
|------|------|-------------|
| Views | Eye | Sum of `view_count` from seller's items |
| Watch | Heart | Sum of `watcher_count` from seller's items |
| Bid | Gavel | Sum of `bid_count` from seller's items |
| Amount | Money | Sum of `current_price` from seller's items |

Trend percentages: Placeholder ("--") for now — requires historical data comparison not yet available.

### Item Listings

**Desktop:** Table with columns: Item (thumbnail + title + time remaining), Views, Watch, Bids, Highest bid, Status (sortable), Actions (3-dot menu).

**Mobile:** Card list showing: title, highest bid amount, stats line (Views, Bids, Watchers), status badge, 3-dot actions menu.

**Pagination (desktop):** "Rows per page" selector (10/25/50) + "Page X of Y" + navigation arrows (first, prev, next, last). Server-side pagination via typed query offset/limit.

**Mobile:** FAB (+) orange button in bottom-right corner for "Sell Item" (navigates to `/items/new`).

**Actions menu:** Share (copy link), Edit (navigate to edit page), Delete (confirm dialog → destroy RPC).

**Status badges:** Active (green bg), Ended (orange/red bg), Draft (gray bg) — maps to `auction_status`.

### Data Requirements

New typed query: `seller_listing_card` using `:by_seller` action.

Fields: `id`, `title`, `slug`, `end_time`, `auction_status`, `publication_status`, `view_count`, `bid_count`, `watcher_count`, `current_price`, `starting_price`, `condition`, `sale_type`, `category` (id, name).

Stats are aggregated in the controller from query results (or a separate aggregate query if performance requires).

## Tab 2: Payments (`/store/payments`)

### Balance Cards

Two cards side by side:

| Card | Data Source |
|------|-------------|
| Balance | Sum of `amount` from seller's orders where status is `paid` or `completed` |
| Pending | Sum of `amount` from seller's orders where status is `payment_pending` |

"Next Payout" date: Placeholder text.
"Withdraw" button: Placeholder (shows "Coming soon" toast).

### Payments List

**Desktop:** Table with columns: Item (name), Amount, Ref ID (`payment_reference`), Status (sortable), Date.

**Mobile:** Card list showing: item name, amount, ref ID + date on same line, status badge.

**Status badges:** Paid (green), Pending (yellow/orange).

### Data Requirements

New read action on Order: `seller_orders` filtered by `seller_id == actor(:id)`.

New typed query: `seller_payment_card` using `:seller_orders` action.

Fields: `id`, `status`, `amount`, `payment_reference`, `created_at`, `item` (id, title).

Balance/Pending amounts computed in controller from order data.

## Tab 3: Store Profile (`/store/profile`)

### Profile Header

- Store avatar/logo, store name, verification badge (placeholder)
- Stats row: Star rating, satisfaction %, review count, follower count — all placeholder values
- "Edit" button → navigates to store profile edit (inline or `/settings/store-profile`)
- Share button → copies public store URL (`/store/:slug`)

### Details Section

- Date Joined: From user's `inserted_at`
- Contact: Location, phone, WhatsApp — from StoreProfile resource
- Category badges with item counts — derived from seller's published items grouped by category (reuse existing `category_summary` pattern from store controller)

### Reviews Section

- Placeholder empty state: "No reviews yet" with illustration
- UI structure for review cards (avatar, name, rating, date, comment) built but non-functional
- Reviews resource to be built as a separate future feature

### Data Requirements

Reuse existing `seller_profile` typed query for store info. Load `category_summary` same as public store page. User join date from `current_user` assigns.

## New Backend Resources

### Order: `seller_orders` action

```
read :seller_orders do
  filter expr(seller_id == ^actor(:id))
  prepare build(sort: [created_at: :desc])
end
```

### Inventory Domain: New typed queries

- `seller_listing_card` — seller's items for dashboard management
- `seller_dashboard_stats` (optional) — aggregate stats if needed

### Bidding Domain: New typed query

- `seller_payment_card` — seller's orders for payment history

## Component Structure

```
assets/js/
  features/store-dashboard/
    components/
      store-layout.tsx          # Shared sidebar/tabs layout
      stats-card.tsx            # Reusable stat card with icon and trend
      listing-table.tsx         # Desktop item table
      listing-card.tsx          # Mobile item card
      listing-actions-menu.tsx  # Share/Edit/Delete dropdown
      payment-table.tsx         # Desktop payment table
      payment-card.tsx          # Mobile payment card
      balance-card.tsx          # Balance/Pending display
      profile-header.tsx        # Store profile header with actions
      profile-details.tsx       # Contact details and category badges
      reviews-section.tsx       # Reviews placeholder
  pages/
    store/
      listings.tsx              # Listings tab page
      payments.tsx              # Payments tab page
      profile.tsx               # Store Profile tab page
```

## Controller

New `StoreDashboardController` with three actions:

- `listings/2` — loads seller items + stats, renders `store/listings`
- `payments/2` — loads seller orders + balance, renders `store/payments`
- `profile/2` — loads store profile + categories + user info, renders `store/profile`

## Routes

```elixir
# In authenticated scope
get "/store", StoreDashboardController, :index  # redirects to /store/listings
get "/store/listings", StoreDashboardController, :listings
get "/store/payments", StoreDashboardController, :payments
get "/store/profile", StoreDashboardController, :profile
```

Note: Existing `/store/:slug` route for public store pages remains unchanged.

## Out of Scope

- "Sell Item" form (separate feature, `/items/new`)
- Actual payment processing / Withdraw functionality
- Reviews resource and CRUD
- Real trend percentages (requires historical data tracking)
- Item edit page (can navigate to existing item detail or future edit page)
