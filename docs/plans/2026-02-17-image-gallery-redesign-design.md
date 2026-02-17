# Item Image Gallery Redesign

## Goal

Replace the current thumbnail-strip + single-image gallery with a grid mosaic layout and full-screen lightbox on the item detail page.

## Desktop Grid Layout (lg+)

CSS Grid with 3 columns and 2 rows. Main image spans column 1 across both rows (~60% width). Remaining images fill a 2x2 grid in columns 2-3.

```
┌─────────────┬──────┬──────┐
│             │ img2 │ img3 │
│  main img   ├──────┼──────┤
│  (col 1,    │ img4 │ img5 │
│   row 1-2)  │      │/+N   │
└─────────────┴──────┴──────┘
```

- **Gap**: 8px between all cells
- **Rounding**: `rounded-2xl` on outer container with `overflow-hidden`; individual cells have no rounding (container clips them)
- **Images**: `object-cover` to fill cells
- **Click**: Any image click opens lightbox

### Image count handling

| Count | Layout |
|-------|--------|
| 0 | Centered placeholder (Gavel icon), `max-w-[640px]`, `mx-auto`, 4:3 aspect |
| 1 | Single centered image, `max-w-[640px]`, `mx-auto`, 4:3 aspect |
| 2 | Main image left (~60%), one image right (full height of right column) |
| 3 | Main image left, 2 images stacked on right |
| 4 | Main image left, 2 stacked on right top, 1 below-right |
| 5+ | Full 1+4 grid. If >5 images, last cell gets dark overlay with "+N more" text |

## Mobile Layout

No grid — screen too narrow for mosaic.

- Full-width single image, 4:3 aspect, `rounded-2xl`
- Dot indicators below when >1 image
- Tapping the image opens lightbox

## Lightbox

Full-screen modal triggered by clicking/tapping any image (desktop or mobile).

- **Overlay**: `bg-black/90` backdrop
- **Close**: X button top-left; `Escape` key
- **Counter**: "3/8" text top-right
- **Navigation**: Left/right arrow buttons on sides; `←`/`→` keyboard keys
- **Main image**: Centered, `object-contain` (full image visible, no cropping)
- **Thumbnail strip**: Horizontal row at bottom, active thumbnail highlighted with ring, scrollable if many images
- **Entry point**: Opens at the index of the clicked image

Implementation: React component with `useState` for active index, `useEffect` for keyboard listeners, rendered via portal. No external library.

## Files affected

- `assets/js/features/items/components/item-image-gallery.tsx` — rewrite grid + add lightbox
- `assets/js/pages/items/show.tsx` — may need layout adjustments if gallery width changes
