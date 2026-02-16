# Watchlist Feature Design

## Overview

Allow authenticated users to save items to a watchlist for tracking prices, monitoring bids, and bidding later. The watchlist page displays saved items with category filtering. Heart buttons on item cards throughout the app toggle watchlist membership.

## Data Model

### WatchlistItem Resource (new)
- **Domain:** Inventory
- **Table:** `watchlist_items`
- **Fields:** id (uuid PK), user_id (uuid FK), item_id (uuid FK), inserted_at
- **Identity:** unique on [user_id, item_id] (prevent duplicates)
- **Relationships:** belongs_to User, belongs_to Item
- **Actions:**
  - `add` (create) — accepts item_id, sets user_id from actor
  - `remove` (destroy) — removes a watchlist entry
  - `by_user` (read) — lists current user's watchlist items

### Item Resource Updates
- Add `has_many :watchlist_items, WatchlistItem`
- Add `count :watcher_count, :watchlist_items` aggregate (public? true)
- Add `watchlisted` read action — filters to items in current user's watchlist, with optional category_id argument

### Inventory Domain Updates
- Register WatchlistItem resource
- Add `watchlist_item_card` typed query on Item's `watchlisted` action
- Add RPC actions: `add_to_watchlist` (create), `remove_from_watchlist` (destroy)

## Page Design

### Empty State
- Illustration image (centered)
- "Your Watchlist is empty."
- "Save items you like to compare prices, monitor bids, or bid for later."
- "Browse Items" button linking to homepage

### Populated State (Desktop)
- Left sidebar: Category filters (All + top-level categories with icons)
- Main area: "Watchlist" title with item count
- Horizontal item cards showing: image, title, price, time left, condition badge, bid count, watcher count, vendor name, Bid button

### Populated State (Mobile)
- "Watchlist" title with search icon + "All" category dropdown + filter icon
- Full-width vertical item cards with same data as desktop

### Category Filter
- Desktop: Sidebar nav with category icons (All, Artifacts, Gadgets, Collectibles, Appliances)
- Mobile: Dropdown selector
- Implemented as query parameter (`?category=<slug>`), server-side filtering
- Categories shown are top-level categories from the system

## Heart Button Integration
- Existing heart buttons on ItemCard and CategoryItemCard become functional
- On click: RPC call to add_to_watchlist or remove_from_watchlist
- Filled heart = in watchlist, outline heart = not in watchlist
- Controllers that render pages with item cards load user's watchlisted item IDs as prop

## Files

**New:**
- `lib/angle/inventory/watchlist_item.ex`
- `assets/js/features/watchlist/` (components + barrel export)
- `test/angle/inventory/watchlist_item_test.exs`
- `test/angle_web/controllers/watchlist_controller_test.exs`
- Migration file (auto-generated)

**Modified:**
- `lib/angle/inventory/item.ex` (relationship, aggregate, action)
- `lib/angle/inventory.ex` (resource registration, typed query, RPC)
- `lib/angle_web/controllers/watchlist_controller.ex` (real data loading)
- `assets/js/pages/watchlist.tsx` (replace placeholder)
- `assets/js/features/items/components/item-card.tsx` (functional heart)
- `assets/js/features/items/components/category-item-card.tsx` (functional heart)
- `test/support/factory.ex` (add create_watchlist_item)
