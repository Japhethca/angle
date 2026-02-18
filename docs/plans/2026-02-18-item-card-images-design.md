# Item Card Images Design

## Goal

Add real item cover images to the 4 card components that currently show grey placeholders: ActiveBidCard, HistoryBidCard, WonBidCard, and ListingCard.

## Current State

6 card components show real images via `ImageHelpers.attach_cover_images()` in their controllers. 4 card components don't:

| Card | Page | Data shape | Item ID location |
|------|------|-----------|-----------------|
| ActiveBidCard | Bids (Active tab) | `bid.item.id` | nested |
| HistoryBidCard | Bids (History tab) | `bid.item.id` | nested |
| WonBidCard | Bids (Won tab) | `order.item.id` | nested |
| ListingCard | Store Dashboard (Listings) | `item.id` | top-level |

## Approach

### Backend: Add helper + controller calls

**ListingCard** is straightforward — the items are top-level maps, so we call `ImageHelpers.attach_cover_images(items)` directly in `StoreDashboardController.listings/2`.

**Bid/Order cards** have items nested inside bids/orders. Add a new helper `ImageHelpers.attach_nested_cover_images(records, item_key)` that:
1. Extracts item IDs from `record[item_key]["id"]` for each record
2. Batch-fetches cover images using `Angle.Media.list_cover_images/2`
3. Attaches `"coverImage"` to each `record[item_key]` sub-map

This keeps image fetching batched (one query per page load) and follows the established pattern.

### Frontend: Replace placeholder divs with ResponsiveImage

Each of the 4 components gets a `coverImage` prop (or reads it from `item.coverImage`) and renders `<ResponsiveImage>` with a Gavel icon fallback — matching the pattern used by ItemCard, CategoryItemCard, etc.

## Files to modify

### Backend (3 files)
1. `lib/angle_web/controllers/image_helpers.ex` — add `attach_nested_cover_images/2`
2. `lib/angle_web/controllers/bids_controller.ex` — call attach for all 3 tabs
3. `lib/angle_web/controllers/store_dashboard_controller.ex` — call attach for listings

### Frontend (4 files)
4. `assets/js/features/bidding/components/active-bid-card.tsx` — replace placeholder with image
5. `assets/js/features/bidding/components/history-bid-card.tsx` — replace placeholder with image
6. `assets/js/features/bidding/components/won-bid-card.tsx` — replace placeholder with image
7. `assets/js/features/store-dashboard/components/listing-card.tsx` — add image display
