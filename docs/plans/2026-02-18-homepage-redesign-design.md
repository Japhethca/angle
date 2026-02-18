# Homepage Redesign — Design Doc

**Goal:** Redesign the homepage to convert new visitors, increase engagement for returning users, and break visual monotony by introducing varied section layouts and new content sections.

**Scope:** Frontend-only changes (React pages/components). No backend or controller changes — all data already exists in current Inertia props.

---

## Page Flow

| # | Section | Layout | Status |
|---|---------|--------|--------|
| 1 | Hero | Guest: value prop + CTAs / Auth: featured carousel with greeting | Redesigned |
| 2 | How It Works | 3-step horizontal strip with icons | New |
| 3 | Search | Centered large input + trending category pills | New |
| 4 | Ending Soon | Responsive grid (4/2/1 cols) | Changed layout |
| 5 | Recommended | Horizontal scroll, heading adapts to auth state | Minor tweak |
| 6 | Trust Stats | 4 stats in horizontal strip, hardcoded | New |
| 7 | Hot Now | Mosaic grid (1 large + 4 small desktop, scroll mobile) | Changed layout |
| 8 | Sell CTA | Split section: copy + CTA / image | New |
| 9 | Categories | Responsive grid with gradient fallbacks | Improved |
| 10 | Footer | Unchanged | — |

**Visual rhythm:** Full-width hero → strip → centered → grid → scroll → strip → mosaic → split → grid → footer. No two adjacent sections share the same layout.

---

## Section Details

### 1. Hero / Featured Area

Two experiences based on auth state:

**Guests:**
- Full-width hero with gradient background (brand colors)
- Headline: "Bid. Win. Own." (or similar punchy tagline)
- Subtext: "Discover unique items at auction prices. Join thousands of bidders on Nigeria's premier auction platform."
- Two CTAs: "Sign Up Free" (primary) + "Browse Items" (secondary/outline)
- Background: subtle collage/grid of item images at low opacity behind text

**Authenticated users:**
- Featured item carousel (improved from current)
- Time-of-day greeting moved here from Recommended section ("Good evening, Chidex")
- Larger, cinematic item image with bottom gradient overlay
- Item details overlaid: title, price, countdown timer, bid CTA
- Auto-advance every 6s with progress dots
- Swipe on mobile

### 2. How It Works

3-step visual explainer strip shown to all users.

Layout: horizontal row on desktop, stacked or scroll on mobile. Each step has:
- Large Lucide icon in brand accent color
- Step title + one-line description

| Step | Icon | Title | Description |
|------|------|-------|-------------|
| 1 | `Search` | Find Items | Browse categories or search for items you love |
| 2 | `Gavel` | Place Your Bid | Set your price and compete with other bidders |
| 3 | `Trophy` | Win & Own | Highest bid wins when the auction ends |

Styling: `bg-surface-muted`, compact padding.

### 3. Search Section

Prominent search area with more visibility than the nav bar input.

- Large centered search input (~600-700px max on desktop, full-width mobile)
- Placeholder: "Search for items, categories, or sellers..."
- Search icon left, submit icon right
- Below input: row of trending/popular category pills linking to category pages
- Pills derived from existing `categories` prop — no new backend work

### 4. Ending Soon (Grid)

Switched from horizontal scroll to responsive grid.

- 4 columns desktop, 2 tablet, 1 mobile — 8 items (2 rows desktop)
- Same card content: cover image, title, price, countdown, watchlist heart
- **No "Almost gone" badge** — section title + countdown already communicate urgency
- Section header: "Ending Soon" + "View All" link
- Data: same `ending_soon_items`, still auto-refreshes every 60s

### 5. Recommended (Horizontal Scroll)

Kept as horizontal scroll for visual contrast after the grid above.

- Greeting removed (moved to hero)
- Header: "Recommended for You" (auth) / "Popular Items" (guest) + "View All" link
- Cards unchanged

### 6. Trust / Stats Strip

Compact credibility strip with platform numbers.

Layout: 4 stats evenly spaced on desktop, 2x2 grid on mobile. Each stat: Lucide icon above, large bold number, smaller label below.

| Icon | Number | Label |
|------|--------|-------|
| `Package` | 1,200+ | Items Listed |
| `Gavel` | 5,000+ | Bids Placed |
| `Users` | 800+ | Active Bidders |
| `Trophy` | 350+ | Auctions Won |

Hardcoded values for now. `bg-surface-muted` background, compact padding.

### 7. Hot Now (Mosaic Grid)

Desktop layout — 1 large tile (left half) + 4 smaller tiles (2x2 right):

```
┌─────────────┬──────┬──────┐
│             │  2   │  3   │
│      1      ├──────┼──────┤
│  (large)    │  4   │  5   │
└─────────────┴──────┴──────┘
```

- Large tile: full-height image with title/price overlay at bottom, fire badge
- Small tiles: standard card treatment
- Mobile: falls back to horizontal scroll
- Data: first 5 from `hot_items` prop
- Header: "Hot Now" + "View All" link

### 8. Sell on Angle CTA

Supply-side conversion section.

Desktop: 50/50 split — copy left, image right. Mobile: stacked (copy on top).

- Headline: "Start Selling on Angle"
- Subtext: "Turn your unused items into cash. List your items, set a starting price, and let bidders compete. It's free to get started."
- CTA: "List an Item" (primary button, uses `AuthLink` — guests redirect to sign up)
- Image: placeholder gradient or static image from `/images/`
- Styling: `bg-surface-muted` or subtle brand gradient background

### 9. Browse Categories (Improved)

Switched from horizontal scroll to responsive grid with better empty-state treatment.

- Grid: 4 columns desktop, 3 tablet, 2 mobile
- Show 6-8 top-level categories
- Cards with images: image fills card, dark gradient overlay from bottom, white text name
- Cards without images: colored gradient background (brand-tinted) with category name + centered Lucide icon
- Header: "Browse Categories" + "View All Categories" link

---

## Non-Goals

- No backend/controller changes
- No new API endpoints or typed queries
- No real-time stats (hardcoded for now)
- No search backend — search navigates to a route or focuses nav input
