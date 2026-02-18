# Ash Patterns Implementation Design

**Goal:** Apply the documented Ash Framework patterns across the codebase — extract shared helpers, add code interfaces to all domains, and refactor controllers to use them instead of direct Ash calls.

**Motivation:** 43 direct Ash calls across 8 controllers + 1 helper module bypass domain boundaries. 7 copies of `extract_results`, 4 copies of `load_watchlisted_map`, and 2 copies of `build_category_summary` create maintenance burden.

## Architecture

Three phases executed in order:

### Phase 1: Foundation

1. **Shared helpers module** (`AngleWeb.Helpers.QueryHelpers`)
   - `extract_results/1` — normalize typed query responses (replaces 7 copies)
   - `load_watchlisted_map/1` — build item_id → watchlist_item_id map for current user
   - `build_category_summary/1` — category list with per-seller item counts

2. **~20 new code interfaces** across 6 domains (all domain-level `define` entries)

### Phase 2: Migration

Refactor all controllers to replace direct `Ash.Query`/`Ash.read!`/`Ash.get`/`Ash.create`/`Ash.destroy` calls with code interfaces or shared helpers.

### Phase 3: Standardization

- Move User's resource-level `code_interface do` block to domain-level defines in `Angle.Accounts`
- Port the patterns doc from stale `docs/ash-patterns-guidelines` branch to this branch
- Update the doc to reflect the completed state

## Convention: Domain-Level Code Interfaces

All code interfaces use `define` in the domain's `resources do` block:

```elixir
# In domain module (e.g., lib/angle/media.ex)
resources do
  resource Angle.Media.Image do
    define :get_image, action: :read, get_by: [:id]
    define :destroy_image, action: :destroy
  end
end
```

This generates: `Angle.Media.get_image(id, opts)`, `Angle.Media.destroy_image(record, opts)`

## Code Interfaces Needed Per Domain

### Angle.Media (Image)
- `get_image` — get by id
- `list_images_by_owner` — action `:by_owner`
- `create_image` — action `:create`
- `destroy_image` — action `:destroy`
- `reorder_image` — action `:reorder`
- `count_images_by_owner` — new action needed (count by owner_type + owner_id)
- `list_cover_images` — new action needed (filter position=0, owner_type=item, owner_id in list)

### Angle.Payments (PaymentMethod + PayoutMethod)
- `get_payment_method` / `get_payout_method` — get by id
- `list_payment_methods_by_user` / `list_payout_methods_by_user` — action `:list_by_user`
- `create_payment_method` / `create_payout_method` — action `:create`
- `destroy_payment_method` / `destroy_payout_method` — action `:destroy`

### Angle.Bidding (Order + Review)
- `get_order` — get by id
- `pay_order` — action `:pay_order`
- `list_buyer_item_ids` — new read action (buyer_id filter, select item_id)
- `list_reviews_by_orders` — new read action (order_id in list filter, select fields)

### Angle.Inventory (WatchlistItem)
- `list_watchlist_by_user` — action `:by_user`

### Angle.Accounts (User + StoreProfile)
- `get_user` — get by id (for auth flows)
- `confirm_user` — action `:confirm`
- `get_store_profile` — get by id (for upload ownership check)

### Angle.Catalog (Category)
- `list_categories_with_item_counts` — new read action with dynamic aggregate

## Testing

No new tests — existing 213 tests validate behavior. We're only changing how controllers call Ash, not what they do.
