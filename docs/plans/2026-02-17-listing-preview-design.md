# Listing Preview & Edit Design

## Overview

Replace the current inline preview wizard step (Step 4) with a server-loaded preview page that mirrors the public item detail page. Sellers see exactly what buyers will see, with Edit links and a Publish button. Each wizard step saves to the server so the preview page can load the full draft.

## Figma References

| Screen | Node IDs |
|--------|----------|
| Preview (Desktop) | `586-8083` |
| Preview (Mobile) | `722-9334` |

Figma file key: `jk9qoWNcSpgUa8lsj7uXa9`

## Route Structure

| Route | Purpose |
|-------|---------|
| `/store/listings/new` | Steps 1-3 wizard (create + edit draft) |
| `/store/listings/:id/preview` | Server-loaded preview (mirrors public item page) |
| `/store/listings/:id/edit?step=N` | Edit existing draft (wizard pre-filled from server) |

## Flow

1. **Step 1** (Basic Details): `createDraftItem` RPC — saves title, description, category, condition, attributes. Uploads images.
2. **Step 2** (Auction Info): `updateDraftItem` RPC — saves startingPrice, reservePrice, auction duration fields.
3. **Step 3** (Logistics): `updateDraftItem` or `upsertStoreProfile` — saves delivery preference.
4. After Step 3: `router.visit(/store/listings/:id/preview)` — Inertia navigation to preview page.
5. **Preview page**: Server loads draft item via `item_detail` typed query. Renders using shared `ItemDetailLayout`.
6. **Edit links** on preview: Navigate to `/store/listings/:id/edit?step=N`. Wizard loads draft from server, opens at step N.
7. **Publish button**: Calls `publishItem` RPC. On success, shows success modal, then redirects to `/store/listings` or view listing.

## Shared `ItemDetailLayout` Component

Extract the presentational layout from `pages/items/show.tsx` into `features/items/components/item-detail-layout.tsx`.

```tsx
interface ItemDetailLayoutProps {
  mode: "public" | "preview";
  item: ItemData;
  images: ImageData[];
  seller?: Seller | null;
  similarItems?: HomepageItemCard;
  // Public mode
  watchlistEntryId?: string | null;
  // Preview mode
  onEdit?: (step: number) => void;
  onPublish?: () => void;
  isPublishing?: boolean;
}
```

### Public mode (existing behavior)
- Breadcrumb: Home > Category > Item Title
- Image gallery, bid section, watchlist, seller card, similar items
- Full item detail tabs

### Preview mode
- Wrapped in `StoreLayout` (store sidebar visible)
- "Draft Preview" banner at top
- Static price display (no bid form)
- "Edit" links on Description, Features, Logistics sections
- Sticky "Publish" button (right column desktop / bottom mobile)
- Hides: seller card, similar items, watchlist/share buttons, bid form

## Saving at Each Step

Current behavior: Step 1 creates draft, Steps 2-3 client-side only, everything saved at publish.

New behavior: Each step persists to server immediately.

| Step | RPC Call | Fields Saved |
|------|----------|-------------|
| Step 1 | `createDraftItem` | title, description, categoryId, condition, attributes, images |
| Step 2 | `updateDraftItem` | startingPrice, reservePrice, startTime (placeholder), endTime (computed from duration) |
| Step 3 | `updateDraftItem` | deliveryPreference (on StoreProfile or item) |

## Preview Page Controller

New `preview` action in `StoreDashboardController`:
- Verify current user owns the draft item
- Load draft item using `item_detail` typed query (same query as public `show` action, but without the `published` filter)
- Load images via `ImageHelpers`
- Load current user as seller for display
- Render Inertia page `"store/listings/preview"`

## Edit Page Controller

New `edit` action in `StoreDashboardController`:
- Verify current user owns the draft item
- Load draft item from server
- Load categories (same as `new` action)
- Load store profile
- Pass `step` query param as prop to control which wizard step opens
- Render Inertia page `"store/listings/edit"` (same wizard component, pre-filled)

## Files to Create/Modify

### New files
- `assets/js/features/items/components/item-detail-layout.tsx` — shared layout component
- `assets/js/pages/store/listings/preview.tsx` — preview page
- `assets/js/pages/store/listings/edit.tsx` — edit page

### Modified files
- `assets/js/pages/items/show.tsx` — refactor to use `ItemDetailLayout` with `mode="public"`
- `assets/js/features/items/index.ts` — export `ItemDetailLayout`
- `assets/js/features/listing-form/components/listing-wizard.tsx` — save at each step, redirect to preview after Step 3
- `assets/js/features/listing-form/components/auction-info-step.tsx` — call `updateDraftItem` on Next
- `assets/js/features/listing-form/components/logistics-step.tsx` — call `updateDraftItem` on Next
- `assets/js/features/listing-form/components/preview-step.tsx` — remove (replaced by preview page)
- `lib/angle_web/controllers/store_dashboard_controller.ex` — add `preview` and `edit` actions
- `lib/angle_web/router.ex` — add preview and edit routes
