# Category Mega-Menu Dropdown Design

## Overview

Replace the "Categories" nav link with a hover-triggered mega-menu dropdown on desktop. The dropdown displays all top-level categories with their subcategories in a multi-column grid. Mobile nav is unchanged — "Categories" stays as a regular link.

## Approach

Use the existing shadcn/ui `NavigationMenu` component (Radix-based) for the hover trigger and dropdown panel. Categories are loaded as a shared Inertia prop via an ETS-cached typed query.

## Data Flow

### Typed Query

Define `NavCategory` on the Category resource:

```
fields: ["id", "name", "slug", { categories: ["id", "name", "slug"] }]
filter: parent_id is nil (top-level only)
```

This returns top-level categories with nested subcategories.

### ETS Cache

`Angle.Catalog.CategoryCache` — a GenServer owning an ETS table:

- `get_nav_categories/0` — checks ETS for cached result. On miss or TTL expiry (5 minutes), calls `AshTypescript.run_typed_query` for the `nav_category` typed query, stores serialized result + timestamp in ETS, returns data.
- Started in the application supervision tree.
- Cache is invalidated naturally by TTL. No explicit busting needed since categories change rarely.

### Shared Inertia Prop

A plug or shared helper in the controller pipeline calls `CategoryCache.get_nav_categories/0` and assigns `nav_categories` to Inertia shared props. Every page receives this data.

### Frontend Types

`mix ash_typescript.codegen` generates `NavCategory` type and `navCategoryFields` in `ash_rpc.ts`.

## Frontend Components

### `navigation/category-mega-menu.tsx` (new)

Renders the dropdown content panel. Props: `categories: NavCategory`.

**Layout (from Figma):**
- White background, rounded bottom corners (12px), shadow `0px 1px 2px 0px rgba(0,0,0,0.08)`
- 24px padding
- 3-column grid per row, ~104px gap between columns
- Each column: category name (16px medium, `neutral-01`) + subcategory links (14px regular, `neutral-03`, 8px vertical gap)
- ~40px gap between rows

**Links:**
- Category names link to `/categories/{slug}`
- Subcategory items link to `/categories/{parentSlug}/{childSlug}`

### `navigation/main-nav.tsx` (modified)

Desktop nav section changes:
- "Categories" extracted from the `navLinks` array
- Rendered as a `NavigationMenu` with `NavigationMenuTrigger` + `NavigationMenuContent` containing `CategoryMegaMenu`
- Trigger styled to match existing nav text style (no pill/background, plain text)
- Other nav links remain as `AuthLink` elements

Mobile nav unchanged — "Categories" stays as a regular link.

### `layouts/layout.tsx` (modified)

Reads `nav_categories` from page props, passes to `MainNav` as a prop.

### NavigationMenu Styling Overrides

- **Trigger:** Override default `navigationMenuTriggerStyle` — use `text-sm text-neutral-03 hover:text-neutral-01`, no background
- **Viewport:** Position below nav bar, white background, bottom-rounded 12px, Figma shadow, no border
- **Content:** Width accommodates 3 columns (~216px each + gaps + padding)

## Files

**New:**
- `lib/angle/catalog/category_cache.ex` — ETS cache GenServer
- `lib/angle_web/plugs/nav_categories.ex` — shared Inertia prop plug
- `assets/js/navigation/category-mega-menu.tsx` — mega-menu component

**Modified:**
- `lib/angle/catalog/category.ex` — add `nav_category` typed query
- `assets/js/navigation/main-nav.tsx` — Categories becomes NavigationMenu trigger
- `assets/js/layouts/layout.tsx` — pass nav_categories prop to MainNav
- `assets/js/ash_rpc.ts` — auto-regenerated

**Not touched:**
- Mobile nav / bottom nav
- Pages (categories come through shared props)
- `components/ui/navigation-menu.tsx` (use as-is, override via className)

## Mobile Behavior

No changes. "Categories" remains a regular link to `/categories` in both the mobile hamburger sheet and bottom nav.
