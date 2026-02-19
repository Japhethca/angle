# Homepage Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the homepage to convert new visitors, increase engagement for returning users, and break visual monotony with varied section layouts and new content sections.

**Architecture:** All changes are frontend-only (React components). No backend/controller changes — the existing Inertia props (`featured_items`, `recommended_items`, `ending_soon_items`, `hot_items`, `categories`, `watchlisted_map`) remain unchanged. New sections (How It Works, Search, Trust Stats, Sell CTA) use static content or derive data from existing props.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, Inertia.js, Lucide React icons, existing `useAuth`/`useAuthGuard` hooks

**Design doc:** `docs/plans/2026-02-18-homepage-redesign-design.md`

---

### Task 1: Create GuestHero Component

The guest hero replaces the featured carousel for unauthenticated visitors. It shows a value proposition with CTAs.

**Files:**
- Create: `assets/js/features/home/components/guest-hero.tsx`

**Step 1: Create the component**

```tsx
import { Link } from "@inertiajs/react";
import { Button } from "@/components/ui/button";

export function GuestHero() {
  return (
    <section className="relative overflow-hidden bg-gradient-to-br from-primary-900 via-primary-800 to-primary-950">
      {/* Decorative background pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute left-1/4 top-1/4 size-64 rounded-full bg-primary-400 blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 size-48 rounded-full bg-primary-600 blur-3xl" />
      </div>

      <div className="relative px-4 py-16 text-center lg:px-10 lg:py-24">
        <h1 className="font-heading text-4xl font-bold text-white lg:text-6xl">
          Bid. Win. Own.
        </h1>
        <p className="mx-auto mt-4 max-w-xl text-lg text-white/80 lg:text-xl">
          Discover unique items at auction prices. Join thousands of bidders on
          Nigeria&apos;s premier auction platform.
        </p>
        <div className="mt-8 flex items-center justify-center gap-4">
          <Button
            size="lg"
            className="rounded-full bg-white px-8 text-primary-900 hover:bg-white/90"
            asChild
          >
            <Link href="/auth/register">Sign Up Free</Link>
          </Button>
          <Button
            variant="outline"
            size="lg"
            className="rounded-full border-white/30 px-8 text-white hover:bg-white/10"
            asChild
          >
            <Link href="#search-section">Browse Items</Link>
          </Button>
        </div>
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/guest-hero.tsx
git commit -m "feat(home): add GuestHero component for unauthenticated visitors"
```

---

### Task 2: Refactor FeaturedItemCarousel for Authenticated Users

Move the greeting from `RecommendedSection` into the featured carousel and improve the overlay treatment. The carousel is now only shown to authenticated users.

**Files:**
- Modify: `assets/js/features/home/components/featured-item-carousel.tsx`

**Step 1: Update the component**

Add the greeting import and display it above the carousel. Add auto-advance with `useEffect`. The key changes:

1. Import `useAuth` from `@/features/auth`
2. Add `getGreeting()` helper (moved from recommended-section)
3. Show greeting above the carousel
4. Add auto-advance every 6 seconds with a `useEffect` + `setInterval`

```tsx
// Add to imports:
import { useAuth } from "@/features/auth";

// Add before the component:
function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

// Inside the component, after useState:
const { user } = useAuth();

// Add auto-advance effect after the state declarations:
useEffect(() => {
  if (items.length <= 1) return;
  const timer = setInterval(() => {
    setCurrentIndex(i => (i === items.length - 1 ? 0 : i + 1));
  }, 6000);
  return () => clearInterval(timer);
}, [items.length]);

// Add greeting before the desktop layout div:
// (inside the main return, before {/* Desktop layout */})
{user?.full_name && (
  <h2 className="mb-6 font-heading text-2xl font-semibold text-content lg:text-[32px]">
    {getGreeting()}, {user.full_name}
  </h2>
)}
```

Keep all existing carousel logic (navigation, dots, mobile/desktop layouts) intact. The only additions are the greeting, the auto-advance timer, and the `useEffect` import.

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/featured-item-carousel.tsx
git commit -m "feat(home): add greeting and auto-advance to FeaturedItemCarousel"
```

---

### Task 3: Create HowItWorksSection Component

A 3-step visual explainer strip.

**Files:**
- Create: `assets/js/features/home/components/how-it-works-section.tsx`

**Step 1: Create the component**

```tsx
import { Search, Gavel, Trophy } from "lucide-react";

const steps = [
  {
    icon: Search,
    title: "Find Items",
    description: "Browse categories or search for items you love",
  },
  {
    icon: Gavel,
    title: "Place Your Bid",
    description: "Set your price and compete with other bidders",
  },
  {
    icon: Trophy,
    title: "Win & Own",
    description: "Highest bid wins when the auction ends",
  },
];

export function HowItWorksSection() {
  return (
    <section className="bg-surface-muted px-4 py-10 lg:px-10 lg:py-12">
      <h2 className="mb-8 text-center font-heading text-2xl font-semibold text-content lg:text-[32px]">
        How It Works
      </h2>
      <div className="mx-auto grid max-w-3xl grid-cols-1 gap-8 sm:grid-cols-3">
        {steps.map((step, index) => (
          <div key={index} className="flex flex-col items-center text-center">
            <div className="mb-4 flex size-14 items-center justify-center rounded-2xl bg-primary-100 dark:bg-primary-900/30">
              <step.icon className="size-7 text-primary-600" />
            </div>
            <h3 className="text-base font-semibold text-content">{step.title}</h3>
            <p className="mt-1 text-sm text-content-secondary">{step.description}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/how-it-works-section.tsx
git commit -m "feat(home): add HowItWorksSection component"
```

---

### Task 4: Create SearchSection Component

A prominent search area with trending category pills.

**Files:**
- Create: `assets/js/features/home/components/search-section.tsx`

**Step 1: Create the component**

The component receives `categories` (from the existing `HomepageCategory` prop) and renders trending pills from the first 6 categories. Search submission navigates to `/categories` for now (no search backend yet).

```tsx
import { useState, type FormEvent } from "react";
import { Link } from "@inertiajs/react";
import { Search } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";

type Category = HomepageCategory[number];

interface SearchSectionProps {
  categories: Category[];
}

export function SearchSection({ categories }: SearchSectionProps) {
  const [query, setQuery] = useState("");

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    // Future: navigate to /search?q=query
    // For now, no-op since search backend doesn't exist yet
  };

  const trendingCategories = categories.slice(0, 6);

  return (
    <section id="search-section" className="px-4 py-10 lg:px-10 lg:py-12">
      <div className="mx-auto max-w-2xl">
        <form onSubmit={handleSubmit} className="relative">
          <Search className="absolute left-4 top-1/2 size-5 -translate-y-1/2 text-content-placeholder" />
          <input
            type="text"
            value={query}
            onChange={e => setQuery(e.target.value)}
            placeholder="Search for items, categories, or sellers..."
            className="h-14 w-full rounded-xl bg-surface-muted pl-12 pr-4 text-base text-content placeholder:text-content-placeholder outline-none ring-1 ring-transparent transition-shadow focus:ring-2 focus:ring-primary-600"
          />
        </form>

        {trendingCategories.length > 0 && (
          <div className="mt-4 flex flex-wrap items-center gap-2">
            <span className="text-sm text-content-tertiary">Trending:</span>
            {trendingCategories.map(category => (
              <Link
                key={category.id}
                href={`/categories/${category.slug || category.id}`}
                className="rounded-full bg-surface-muted px-3 py-1.5 text-sm text-content-secondary transition-colors hover:bg-surface-emphasis hover:text-content"
              >
                {category.name}
              </Link>
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/search-section.tsx
git commit -m "feat(home): add SearchSection component with trending pills"
```

---

### Task 5: Refactor EndingSoonSection to Grid Layout

Switch from horizontal scroll to a responsive grid. Remove the `"ending-soon"` badge (the section title + countdown already communicate urgency). Add "View All" link.

**Files:**
- Modify: `assets/js/features/home/components/ending-soon-section.tsx`

**Step 1: Update the component**

Replace the existing JSX (lines 32-49) with a grid layout. The `useAshQuery` data fetching stays the same. Key changes:

1. Change the section header to include a "View All" link
2. Replace the horizontal scroll `<div>` with a grid
3. Pass no `badge` prop to `ItemCard` (removing "Almost gone" labels)

Replace the full return statement:

```tsx
return (
  <section className="px-4 py-10 lg:px-10 lg:py-12">
    <div className="mb-6 flex items-center justify-between">
      <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
        Ending Soon
      </h2>
      <Link
        href="/categories"
        className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
      >
        View All
      </Link>
    </div>
    {items.length === 0 ? (
      <div className="flex h-48 items-center justify-center rounded-xl bg-surface-muted">
        <p className="text-sm text-content-tertiary">No items ending soon</p>
      </div>
    ) : (
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 lg:gap-6">
        {items.map((item) => (
          <ItemCard
            key={item.id}
            item={item}
            watchlistEntryId={watchlistedMap[item.id] ?? null}
          />
        ))}
      </div>
    )}
  </section>
);
```

Also add the `Link` import at the top:
```tsx
import { Link } from "@inertiajs/react";
```

**Step 2: Update ItemCard to support grid layout**

The current `ItemCard` has fixed widths (`w-[85vw] shrink-0 sm:w-[320px] lg:w-[432px]`). For the grid layout, cards need to fill their grid cell instead. Modify `assets/js/features/items/components/item-card.tsx` line 29:

Change the outer wrapper from:
```tsx
<div className="w-[85vw] shrink-0 sm:w-[320px] lg:w-[432px]">
```
To:
```tsx
<div className="w-[85vw] shrink-0 sm:w-[320px] lg:w-[432px] [.grid_&]:w-auto [.grid_&]:shrink">
```

This uses Tailwind's arbitrary variant to make the card fill its parent when inside a `.grid` container, while keeping the fixed widths when used in horizontal scroll containers.

**Step 3: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/ending-soon-section.tsx assets/js/features/items/components/item-card.tsx
git commit -m "feat(home): switch EndingSoonSection to grid layout, remove badge"
```

---

### Task 6: Refactor RecommendedSection

Remove the greeting (moved to hero), update heading to show "Popular Items" for guests, add "View All" link.

**Files:**
- Modify: `assets/js/features/home/components/recommended-section.tsx`

**Step 1: Update the component**

Replace the entire file:

```tsx
import { Link } from "@inertiajs/react";
import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/features/items";
import { useAuth } from "@/features/auth";

type Item = HomepageItemCard[number];

interface RecommendedSectionProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

export function RecommendedSection({ items, watchlistedMap = {} }: RecommendedSectionProps) {
  const { authenticated } = useAuth();

  const heading = authenticated ? "Recommended for You" : "Popular Items";

  return (
    <section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between px-4 lg:px-10">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          {heading}
        </h2>
        <Link
          href="/categories"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All
        </Link>
      </div>
      {items.length === 0 ? (
        <div className="mx-4 flex h-48 items-center justify-center rounded-xl bg-surface-muted lg:mx-10">
          <p className="text-sm text-content-tertiary">No recommendations yet</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} watchlistEntryId={watchlistedMap[item.id] ?? null} />
          ))}
        </div>
      )}
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/recommended-section.tsx
git commit -m "feat(home): update RecommendedSection heading, add View All link"
```

---

### Task 7: Create TrustStatsSection Component

A compact stats strip showing platform credibility numbers.

**Files:**
- Create: `assets/js/features/home/components/trust-stats-section.tsx`

**Step 1: Create the component**

```tsx
import { Package, Gavel, Users, Trophy } from "lucide-react";

const stats = [
  { icon: Package, value: "1,200+", label: "Items Listed" },
  { icon: Gavel, value: "5,000+", label: "Bids Placed" },
  { icon: Users, value: "800+", label: "Active Bidders" },
  { icon: Trophy, value: "350+", label: "Auctions Won" },
];

export function TrustStatsSection() {
  return (
    <section className="bg-surface-muted px-4 py-10 lg:px-10 lg:py-12">
      <div className="mx-auto grid max-w-4xl grid-cols-2 gap-8 lg:grid-cols-4">
        {stats.map((stat) => (
          <div key={stat.label} className="flex flex-col items-center text-center">
            <stat.icon className="mb-2 size-6 text-primary-600" />
            <span className="font-heading text-2xl font-bold text-content lg:text-3xl">
              {stat.value}
            </span>
            <span className="mt-1 text-sm text-content-secondary">{stat.label}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/trust-stats-section.tsx
git commit -m "feat(home): add TrustStatsSection component"
```

---

### Task 8: Refactor HotNowSection to Mosaic Grid

Switch from horizontal scroll to a mosaic layout on desktop (1 large tile + 4 small). Falls back to horizontal scroll on mobile.

**Files:**
- Modify: `assets/js/features/home/components/hot-now-section.tsx`

**Step 1: Update the component**

The mosaic needs a custom large tile for the first item and regular `ItemCard` components for the rest. Replace the full file:

```tsx
import { Link } from "@inertiajs/react";
import { Heart, Gavel } from "lucide-react";
import type { HomepageItemCard } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { ItemCard } from "@/features/items";
import { useAuthGuard } from "@/features/auth";
import { useWatchlistToggle } from "@/features/watchlist";

type Item = HomepageItemCard[number] & { coverImage?: ImageData | null };

interface HotNowSectionProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

function LargeTile({ item, watchlistEntryId }: { item: Item; watchlistEntryId: string | null }) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard, authenticated } = useAuthGuard();
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId,
  });

  return (
    <div className="relative overflow-hidden rounded-2xl bg-surface-muted">
      <Link href={itemUrl} className="block">
        <div className="relative aspect-[4/5]">
          {item.coverImage ? (
            <ResponsiveImage
              image={item.coverImage}
              sizes="(max-width: 1024px) 100vw, 50vw"
              alt={item.title}
            />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-16" />
            </div>
          )}

          {/* Gradient overlay */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent" />

          {/* Fire badge */}
          <div className="absolute left-3 top-3 text-2xl">🔥</div>

          {/* Watchlist heart */}
          <button
            className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-white/20 bg-black/20 backdrop-blur-sm transition-colors hover:bg-black/30"
            disabled={isPending}
            onClick={e => {
              e.preventDefault();
              e.stopPropagation();
              if (authenticated) toggle();
              else guard(itemUrl);
            }}
          >
            <Heart className={`size-4 ${isWatchlisted ? 'fill-red-500 text-red-500' : 'text-white'}`} />
          </button>

          {/* Item details overlay at bottom */}
          <div className="absolute bottom-0 left-0 right-0 p-4 lg:p-6">
            <h3 className="line-clamp-2 text-lg font-semibold text-white lg:text-xl">{item.title}</h3>
            <div className="mt-2 flex items-center gap-3">
              <span className="text-base font-bold text-white">{formatNaira(price)}</span>
              {item.endTime && (
                <CountdownTimer endTime={item.endTime} className="text-white/80" />
              )}
            </div>
          </div>
        </div>
      </Link>
    </div>
  );
}

export function HotNowSection({ items, watchlistedMap = {} }: HotNowSectionProps) {
  if (items.length === 0) {
    return (
      <section className="px-4 py-10 lg:px-10 lg:py-12">
        <h2 className="mb-6 font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Hot Now
        </h2>
        <div className="flex h-48 items-center justify-center rounded-xl bg-surface-muted">
          <p className="text-sm text-content-tertiary">No hot items right now</p>
        </div>
      </section>
    );
  }

  const [featured, ...rest] = items;
  const smallItems = rest.slice(0, 4);

  return (
    <section className="px-4 py-10 lg:px-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Hot Now
        </h2>
        <Link
          href="/categories"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All
        </Link>
      </div>

      {/* Desktop mosaic: hidden on mobile */}
      <div className="hidden lg:grid lg:grid-cols-2 lg:gap-6">
        <LargeTile
          item={featured}
          watchlistEntryId={watchlistedMap[featured.id] ?? null}
        />
        <div className="grid grid-cols-2 gap-6">
          {smallItems.map((item) => (
            <ItemCard
              key={item.id}
              item={item}
              badge="hot-now"
              watchlistEntryId={watchlistedMap[item.id] ?? null}
            />
          ))}
        </div>
      </div>

      {/* Mobile: horizontal scroll */}
      <div className="scrollbar-hide flex gap-4 overflow-x-auto pb-4 lg:hidden">
        {items.map((item) => (
          <ItemCard
            key={item.id}
            item={item}
            badge="hot-now"
            watchlistEntryId={watchlistedMap[item.id] ?? null}
          />
        ))}
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/hot-now-section.tsx
git commit -m "feat(home): switch HotNowSection to mosaic grid on desktop"
```

---

### Task 9: Create SellCtaSection Component

A supply-side conversion section encouraging users to list items.

**Files:**
- Create: `assets/js/features/home/components/sell-cta-section.tsx`

**Step 1: Create the component**

```tsx
import { AuthLink } from "@/features/auth";
import { Button } from "@/components/ui/button";
import { ArrowRight } from "lucide-react";

export function SellCtaSection() {
  return (
    <section className="bg-surface-muted px-4 py-10 lg:px-10 lg:py-16">
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-8 lg:flex-row lg:gap-16">
        {/* Copy side */}
        <div className="flex-1 text-center lg:text-left">
          <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
            Start Selling on Angle
          </h2>
          <p className="mt-3 text-base text-content-secondary lg:text-lg">
            Turn your unused items into cash. List your items, set a starting
            price, and let bidders compete. It&apos;s free to get started.
          </p>
          <Button
            size="lg"
            className="mt-6 rounded-full bg-primary-600 px-8 text-white hover:bg-primary-600/90"
            asChild
          >
            <AuthLink href="/store/listings/new" auth>
              List an Item
              <ArrowRight className="ml-2 size-4" />
            </AuthLink>
          </Button>
        </div>

        {/* Image/illustration side */}
        <div className="flex flex-1 items-center justify-center">
          <div className="flex aspect-[4/3] w-full max-w-md items-center justify-center rounded-2xl bg-gradient-to-br from-primary-100 to-primary-200 dark:from-primary-900/30 dark:to-primary-800/20">
            <div className="text-center">
              <span className="text-6xl">🏷️</span>
              <p className="mt-2 text-sm text-primary-700 dark:text-primary-400">
                List. Auction. Earn.
              </p>
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/sell-cta-section.tsx
git commit -m "feat(home): add SellCtaSection component"
```

---

### Task 10: Refactor BrowseCategoriesSection to Grid with Fallbacks

Switch from horizontal scroll to responsive grid. Add colored gradient fallback for categories without images.

**Files:**
- Modify: `assets/js/features/home/components/browse-categories-section.tsx`

**Step 1: Update the component**

Replace the full file:

```tsx
import { Link } from "@inertiajs/react";
import { Grid3X3 } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";

type Category = HomepageCategory[number];

interface BrowseCategoriesSectionProps {
  categories: Category[];
}

// Rotating gradient backgrounds for categories without images
const gradients = [
  "from-blue-500/20 to-blue-600/30 dark:from-blue-500/10 dark:to-blue-600/20",
  "from-emerald-500/20 to-emerald-600/30 dark:from-emerald-500/10 dark:to-emerald-600/20",
  "from-purple-500/20 to-purple-600/30 dark:from-purple-500/10 dark:to-purple-600/20",
  "from-amber-500/20 to-amber-600/30 dark:from-amber-500/10 dark:to-amber-600/20",
  "from-rose-500/20 to-rose-600/30 dark:from-rose-500/10 dark:to-rose-600/20",
  "from-cyan-500/20 to-cyan-600/30 dark:from-cyan-500/10 dark:to-cyan-600/20",
];

export function BrowseCategoriesSection({ categories }: BrowseCategoriesSectionProps) {
  const displayCategories = categories.slice(0, 8);

  return (
    <section className="px-4 py-10 lg:px-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Browse Categories
        </h2>
        <Link
          href="/categories"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All Categories
        </Link>
      </div>
      {displayCategories.length === 0 ? (
        <div className="flex h-48 flex-col items-center justify-center rounded-xl bg-surface-muted">
          <Grid3X3 className="mb-3 size-8 text-content-placeholder" />
          <p className="text-sm text-content-tertiary">No categories available</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 lg:gap-6">
          {displayCategories.map((category, index) => (
            <Link
              key={category.id}
              href={`/categories/${category.slug || category.id}`}
              className="group"
            >
              <div className="relative aspect-[3/4] overflow-hidden rounded-2xl">
                {category.imageUrl ? (
                  <img
                    src={category.imageUrl}
                    alt={category.name}
                    className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                  />
                ) : (
                  <div className={`flex h-full items-center justify-center bg-gradient-to-br ${gradients[index % gradients.length]}`}>
                    <Grid3X3 className="size-10 text-content-placeholder" />
                  </div>
                )}

                {/* Dark gradient overlay from bottom */}
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />

                {/* Category name */}
                <div className="absolute bottom-0 left-0 right-0 p-4">
                  <span className="text-sm font-semibold text-white lg:text-base">
                    {category.name}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </section>
  );
}
```

**Step 2: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 3: Commit**

```bash
git add assets/js/features/home/components/browse-categories-section.tsx
git commit -m "feat(home): switch BrowseCategoriesSection to grid with gradient fallbacks"
```

---

### Task 11: Update Barrel Export and Wire Up Home Page

Export all new components from the barrel and update the home page to use the new section order with auth-based hero.

**Files:**
- Modify: `assets/js/features/home/index.ts`
- Modify: `assets/js/pages/home.tsx`

**Step 1: Update barrel export**

Replace `assets/js/features/home/index.ts`:

```ts
// Home feature barrel export
export { BrowseCategoriesSection } from "./components/browse-categories-section";
export { EndingSoonSection } from "./components/ending-soon-section";
export { FeaturedItemCarousel } from "./components/featured-item-carousel";
export { GuestHero } from "./components/guest-hero";
export { HotNowSection } from "./components/hot-now-section";
export { HowItWorksSection } from "./components/how-it-works-section";
export { RecommendedSection } from "./components/recommended-section";
export { SearchSection } from "./components/search-section";
export { SellCtaSection } from "./components/sell-cta-section";
export { TrustStatsSection } from "./components/trust-stats-section";
```

**Step 2: Update the home page**

Replace `assets/js/pages/home.tsx`:

```tsx
import type { HomepageItemCard, HomepageCategory } from "@/ash_rpc";
import { useAuth } from "@/features/auth";
import {
  FeaturedItemCarousel,
  GuestHero,
  HowItWorksSection,
  SearchSection,
  EndingSoonSection,
  RecommendedSection,
  TrustStatsSection,
  HotNowSection,
  SellCtaSection,
  BrowseCategoriesSection,
} from "@/features/home";

interface HomeProps {
  featured_items: HomepageItemCard;
  recommended_items: HomepageItemCard;
  ending_soon_items: HomepageItemCard;
  hot_items: HomepageItemCard;
  categories: HomepageCategory;
  watchlisted_map: Record<string, string>;
}

export default function Home({
  featured_items = [],
  recommended_items = [],
  ending_soon_items = [],
  hot_items = [],
  categories = [],
  watchlisted_map = {},
}: HomeProps) {
  const { authenticated } = useAuth();

  return (
    <div>
      {authenticated ? (
        <FeaturedItemCarousel items={featured_items} watchlistedMap={watchlisted_map} />
      ) : (
        <GuestHero />
      )}
      <HowItWorksSection />
      <SearchSection categories={categories} />
      <EndingSoonSection initialItems={ending_soon_items} watchlistedMap={watchlisted_map} />
      <RecommendedSection items={recommended_items} watchlistedMap={watchlisted_map} />
      <TrustStatsSection />
      <HotNowSection items={hot_items} watchlistedMap={watchlisted_map} />
      <SellCtaSection />
      <BrowseCategoriesSection categories={categories} />
    </div>
  );
}
```

**Step 3: Verify assets build**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors

**Step 4: Run tests**

Run: `mix test`
Expected: All tests pass (no backend changes, so existing tests should be unaffected)

**Step 5: Commit**

```bash
git add assets/js/features/home/index.ts assets/js/pages/home.tsx
git commit -m "feat(home): wire up redesigned homepage with new section order"
```

---

### Task 12: Visual QA and Polish

Start the dev server and visually verify the full homepage in both auth states, both themes, and mobile/desktop.

**Files:**
- May need minor tweaks to any component from Tasks 1-11

**Step 1: Start worktree dev server**

Run: `PORT=4113 mix phx.server` (from worktree directory)

**Step 2: Visual QA checklist**

Using Chrome DevTools or browser, verify these scenarios:

1. **Guest desktop (light)** — navigate to `localhost:4113`
   - GuestHero shows with "Bid. Win. Own." headline and CTAs
   - How It Works shows 3 steps in a row
   - Search section with trending pills
   - Ending Soon in 4-column grid
   - "Popular Items" heading on Recommended (horizontal scroll)
   - Trust stats strip
   - Hot Now mosaic (1 large + 4 small)
   - Sell CTA section
   - Categories grid with gradient fallbacks

2. **Guest desktop (dark)** — toggle theme
   - All sections readable in dark mode
   - Gradient backgrounds adapt

3. **Auth desktop** — log in
   - FeaturedItemCarousel with greeting replaces GuestHero
   - "Recommended for You" heading
   - All other sections same

4. **Mobile** — resize to mobile viewport
   - GuestHero stacks nicely
   - How It Works stacks vertically
   - Ending Soon grid becomes single column
   - Hot Now falls back to horizontal scroll
   - Categories grid becomes 2 columns
   - Trust stats becomes 2x2 grid

**Step 3: Fix any visual issues**

Address spacing, overflow, responsive breakpoints, or dark mode color issues found during QA.

**Step 4: Commit any fixes**

```bash
git add -u
git commit -m "fix(home): visual polish from QA review"
```
