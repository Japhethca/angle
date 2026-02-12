# Homepage Implementation Design

> **Figma designs:**
> - Desktop: https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=218-8497&m=dev
> - Mobile: https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=206-3254&m=dev

## Overview

Build the full homepage for Angle, replacing the current placeholder. The homepage is the primary landing page for logged-in users, showcasing featured auctions, personalized recommendations, ending-soon items, trending items, and browsable categories.

Includes a full navigation bar redesign and site-wide footer.

## Decisions

- **Hero image (Figma 280:3364):** Skipped — not relevant to the homepage (listings show actual items).
- **Navigation:** Full redesign to match Figma (Home, Categories, My Bids, Sell Item, Watchlist, search, notifications, avatar).
- **Missing backend features:** Build with available data. Watchlist, star ratings, item images, search, and notifications are out of scope — UI elements render but actions are no-ops or placeholders.
- **Typography:** Add Rubik (headings) + IBM Plex Sans (body) via Google Fonts.
- **Data loading:** AshTypescript typed queries for type-safe, SSR-friendly Inertia props. Optional client-side re-fetching for Ending Soon section via generated field constants + `useAshQuery`.

## Architecture

### Data Flow

```
Ash Domain (typed_query) → PageController (run_typed_query) → Inertia props → React page
                                                                                  ↓
                                                              useAshQuery + field constants
                                                              (optional client-side refresh)
```

**Why typed queries over pure `useAshQuery`:**
- SSR-friendly — page renders with full data on first load (no loading spinners)
- Single HTTP request (Inertia page visit loads everything)
- Generated TypeScript types + field constants (no hand-written interfaces)
- Follows project convention (controller loads data → Inertia props)
- Can still layer `useAshQuery` on top for sections that need polling

### Typed Query Definitions

**Angle.Inventory domain:**

```elixir
typed_query :homepage_item_card, :read do
  ts_result_type_name "HomepageItemCard"
  ts_fields_const_name "homepageItemCardFields"
  fields [
    :id, :title, :slug, :starting_price, :current_price,
    :end_time, :auction_status, :condition, :sale_type, :view_count,
    %{category: [:id, :name, :slug]}
  ]
end
```

**Angle.Catalog domain:**

```elixir
typed_query :homepage_category, :read do
  ts_result_type_name "HomepageCategory"
  ts_fields_const_name "homepageCategoryFields"
  fields [:id, :name, :slug, :image_url]
end
```

### PageController

`PageController.home/2` fetches all homepage data via `AshTypescript.Rpc.run_typed_query/4`:

- `featured_items` — published items, limit 5 (hero carousel)
- `recommended_items` — published items, limit 8
- `ending_soon_items` — published items sorted by `end_time` asc, limit 8
- `hot_items` — published items sorted by `view_count` desc, limit 8
- `categories` — all categories

Pattern match on `%{"success" => true, "data" => data}` (NOT `{:ok, data}`).

### Client-Side Re-fetching

The Ending Soon section uses `useAshQuery` with the generated `homepageItemCardFields` constant and a `refetchInterval` of 60s to keep countdowns accurate. Other sections use static Inertia props only.

```typescript
import { listItems, homepageItemCardFields } from '@/ash_rpc';
import { useAshQuery } from '@/hooks/use-ash-query';

const { data } = useAshQuery(
  ['ending-soon-items'],
  () => listItems({ fields: homepageItemCardFields, sort: 'end_time' }),
  { refetchInterval: 60_000 }
);
```

## Component Tree

```
HomePage
├── FeaturedItemCarousel    → props: featured_items (HomepageItemCard[])
├── RecommendedSection      → props: recommended_items, userName
├── EndingSoonSection       → props: ending_soon_items (initial), useAshQuery (refresh)
├── HotNowSection           → props: hot_items (HomepageItemCard[])
├── BrowseCategoriesSection → props: categories (HomepageCategory[])
└── Footer                  → static
```

## Homepage Sections

### 1. Featured Item Carousel

Full-width hero section (~900px height desktop). One featured item at a time with prev/next navigation.

**Desktop layout:** Two columns — large product image (left ~60%), item details (right ~40%).

**Item details:**
- Item title
- Seller name (`created_by.full_name` or `created_by.email` — may need to add to typed query fields)
- Price (current_price or starting_price, formatted as Naira)
- Countdown timer (days, hours, minutes until end_time)
- Two CTAs: "Watch" (outlined, placeholder) and "Bid" (filled orange, links to item)

**Right side:** 4 small vertical thumbnail cards showing next items. Click navigates carousel.

**Mobile:** Stacks vertically — image on top, details below. Thumbnails become horizontal scroll strip.

### 2. Recommended Items ("Good afternoon, [Name]")

Greeting with time-of-day logic (morning/afternoon/evening) + user's full_name.

Horizontal scrollable row of ItemCard components. 4 visible on desktop, 1.5 on mobile (peek to hint scroll).

### 3. Ending Soon

Section heading "Ending Soon". Same horizontal scroll row of ItemCards. Red/urgent status badges. Optionally re-fetches via `useAshQuery` with 60s interval.

### 4. Hot Now

Section heading "Hot Now". Same row layout. Items sorted by popularity (view_count). Orange "Hot Now" badges.

### 5. Browse Categories

Section heading "Browse Categories". Grid layout: 4 columns desktop, 2 mobile. Each card shows category image + name.

## Shared Components

### ItemCard (`assets/js/components/items/item-card.tsx`)

Reusable card used across all item sections (432x480px desktop).

- Image area (top ~60%, rounded corners, placeholder if no image)
- Optional status badge overlay (top-right): "Ending Soon" (red), "Hot Now" (orange), "Almost Gone" (red)
- Item title (truncated to 1 line)
- Price in Naira (e.g. "₦1,118,500")
- Bottom row: bid count + countdown timer
- Two CTAs: "Watch" (outlined) + "Bid" (filled orange)

Props: `HomepageItemCard` (generated type) + optional `badge` string.

### CountdownTimer (`assets/js/components/shared/countdown-timer.tsx`)

Inline component rendering time remaining from `end_time`.

- Format: `Xd Xh Xm` (drops days when < 1 day, shows "Ended" when past)
- Client-side tick via `useEffect` + `setInterval` (1 minute interval)
- No server polling — decrements from initial end_time

### Footer (`assets/js/components/layouts/footer.tsx`)

Multi-column layout:
- Column 1: Angle logo + tagline
- Column 2: "Goods" — category links
- Column 3: "Social" — Instagram, LinkedIn
- Column 4: "Legal" — Privacy policy
- Bottom bar: copyright

Static, no data dependencies. Added to `Layout` component so it appears on all pages.

### formatNaira (`assets/js/lib/format.ts`)

Utility: `formatNaira(1118500)` → `"₦1,118,500"`.

## Navigation Bar Redesign

Replace current `MainNav` (`assets/js/components/navigation/main-nav.tsx`).

### Desktop (left to right)
- Angle logo (links to `/`)
- Nav links: Home, Categories, My Bids, Sell Item, Watchlist
- Search input with search icon (right-aligned, visual only for now)
- Notification bell icon (placeholder, no backend)
- User avatar/icon (links to `/profile`)

### Mobile
- Angle logo (left) + hamburger icon (right)
- Slide-out drawer with all nav links + search

### Auth-conditional
- Logged out: show "Sign In" / "Sign Up" instead of avatar + notification icon
- "Sell Item" and "My Bids" only visible when authenticated

## Typography & Theme

### Fonts

Import Rubik + IBM Plex Sans via Google Fonts in root layout or `app.css`.

Tailwind config:
```js
fontFamily: {
  heading: ['Rubik', 'sans-serif'],
  body: ['IBM Plex Sans', 'sans-serif'],
}
```

Set `font-body` as default on `<body>`. Use `font-heading` on headings.

### Color Tokens

```js
colors: {
  primary: {
    600: '#F56600',   // main orange
    1000: '#522200',  // dark orange
  },
  neutral: {
    '01': '#0A0A0A',
    '03': '#404040',
    '04': '#737373',
    '05': '#A3A3A3',
    '06': '#D4D4D4',
    '07': '#E5E5E5',
    '08': '#F5F5F5',
    '09': '#FAFAFA',
    '10': '#FFFFFF',
  },
  feedback: {
    error: '#C1170B',
  },
}
```

Migrate existing `bg-orange-500` / `hover:bg-orange-600` usage to `primary-600`.

## Responsive Strategy

### Desktop (lg ≥ 1024px)
- 1440px max-width container, centered
- Featured carousel: 2-column (image + details/thumbnails)
- Item sections: 4 cards visible in scroll row
- Categories: 4-column grid
- Nav: full horizontal links + search + icons
- Footer: 4-column

### Tablet (md 768px–1023px)
- Featured carousel: image stacked above details, thumbnails horizontal strip
- Item rows: 3 cards visible
- Categories: 3-column grid
- Nav: condensed, search behind icon toggle

### Mobile (< 768px)
- Single column
- Featured carousel: full-width image, details below, no thumbnails (or horizontal scroll)
- Item rows: 1.5 cards visible (peek next card)
- Categories: 2-column grid
- Nav: hamburger with slide-out drawer
- Footer: single column stacked

Implementation uses mobile-first Tailwind classes (`sm:`, `md:`, `lg:`).

Item sections use horizontal scroll: `flex overflow-x-auto gap-4 snap-x` with `snap-start` on each card.

## File Structure

### New files

```
assets/js/
├── components/
│   ├── items/
│   │   └── item-card.tsx
│   ├── home/
│   │   ├── featured-item-carousel.tsx
│   │   ├── recommended-section.tsx
│   │   ├── ending-soon-section.tsx
│   │   ├── hot-now-section.tsx
│   │   └── browse-categories-section.tsx
│   ├── shared/
│   │   └── countdown-timer.tsx
│   └── layouts/
│       └── footer.tsx
├── lib/
│   └── format.ts
└── pages/
    └── home.tsx                        # rewrite existing placeholder
```

### Modified files

```
lib/angle/inventory.ex                  # add typed_query :homepage_item_card
lib/angle/catalog.ex                    # add typed_query :homepage_category
lib/angle_web/controllers/page_controller.ex  # add run_typed_query calls
assets/js/components/navigation/main-nav.tsx  # full redesign
assets/js/components/layouts/layout.tsx       # add Footer
assets/css/app.css                            # Google Fonts import
tailwind.config.js                            # font families, color tokens
assets/js/ash_rpc.ts                          # regenerated via mix ash_typescript.generate
```

## Implementation Order

1. **Theme** — Fonts + color tokens in Tailwind config and CSS
2. **Typed queries** — Define in domains, run `mix ash_typescript.generate` to regenerate types
3. **PageController** — Fetch data with `run_typed_query`, pass as Inertia props
4. **Shared components** — CountdownTimer, ItemCard, formatNaira
5. **Navigation** — MainNav redesign + MobileNav
6. **Homepage sections** — Featured carousel, Recommended, Ending Soon, Hot Now, Categories
7. **Footer** — Static footer added to Layout
8. **Responsive polish** — Test mobile/tablet breakpoints

## Out of Scope

- Watchlist backend (link renders, action is no-op)
- Star ratings (not shown on item cards)
- Item image uploads (placeholder images)
- Search backend (input renders, no search action wired)
- Notification system (bell icon renders, no notifications)
- Item detail page (cards can link to it but we don't build it here)
