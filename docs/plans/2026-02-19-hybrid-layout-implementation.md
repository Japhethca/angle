# Hybrid Layout System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a consistent hybrid layout system that constrains content width to 1280px while allowing backgrounds to extend full-width across homepage, functional pages, and footer.

**Architecture:** Create a reusable Section component with props for full-bleed backgrounds, width constraints, and background variants. Migrate existing components to use Section in 3 phases: quick wins, homepage sections, functional pages.

**Tech Stack:** React 18, TypeScript, Tailwind CSS, Inertia.js

---

## Phase 1: Create Section Component & Quick Wins

### Task 1: Create Section Component

**Files:**
- Create: `assets/js/components/layouts/section.tsx`
- Create: `assets/js/components/layouts/index.ts`

**Step 1: Create Section component file**

Create `assets/js/components/layouts/section.tsx`:

```tsx
interface SectionProps {
  children: React.ReactNode;
  fullBleed?: boolean;
  constrain?: boolean;
  maxWidth?: string;
  background?: 'default' | 'muted' | 'dark' | 'gradient' | 'accent';
  className?: string;
  id?: string;
  as?: 'section' | 'div';
}

export function Section({
  children,
  fullBleed = false,
  constrain = true,
  maxWidth = 'max-w-7xl',
  background = 'default',
  className = '',
  id,
  as: Component = 'section',
}: SectionProps) {
  const bgClasses = {
    default: '',
    muted: 'bg-surface-muted',
    dark: 'bg-content text-background dark:bg-surface-muted dark:text-content',
    gradient: 'bg-gradient-to-br from-primary-600 to-primary-1000',
    accent: 'bg-primary-50 dark:bg-primary-950/30',
  };

  if (fullBleed) {
    return (
      <Component id={id} className={`${bgClasses[background]} ${className}`}>
        <div className={`mx-auto ${maxWidth} px-4 lg:px-10`}>
          {children}
        </div>
      </Component>
    );
  }

  if (constrain) {
    return (
      <Component
        id={id}
        className={`mx-auto ${maxWidth} px-4 lg:px-10 ${bgClasses[background]} ${className}`}
      >
        {children}
      </Component>
    );
  }

  return (
    <Component id={id} className={`${bgClasses[background]} ${className}`}>
      {children}
    </Component>
  );
}
```

**Step 2: Create barrel export**

Create `assets/js/components/layouts/index.ts`:

```ts
export { Section } from './section';
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/components/layouts/section.tsx assets/js/components/layouts/index.ts
git commit -m "feat: add Section component for hybrid layout system

- Supports fullBleed backgrounds with constrained content
- 5 background variants (default, muted, dark, gradient, accent)
- Configurable max-width with default max-w-7xl (1280px)
- Type-safe props with semantic HTML element support"
```

---

### Task 2: Update Footer

**Files:**
- Modify: `assets/js/layouts/footer.tsx:22-96`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace footer element with Section**

Replace lines 23-96 with:

```tsx
export function Footer() {
  return (
    <Section
      fullBleed
      background="dark"
      className="hidden lg:block"
      as="footer"
    >
      <div className="py-12">
        <div className="grid grid-cols-12 gap-8">
          {/* Branding */}
          <div className="col-span-4 space-y-4">
            <img src="/images/logo.svg" alt="Angle" className="h-10 brightness-0 invert" />
            <p className="text-sm text-neutral-05">
              Nigeria's First Bidding Marketplace
            </p>
          </div>

          {/* Categories */}
          <div className="col-span-3 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Categories</h4>
            <ul className="space-y-2.5">
              {categoryLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>

          {/* Socials */}
          <div className="col-span-2 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Socials</h4>
            <ul className="space-y-2.5">
              {socialLinks.map((link) => (
                <li key={link.label}>
                  <a
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </div>

          {/* Legal */}
          <div className="col-span-3 space-y-4">
            <h4 className="text-sm font-medium text-neutral-05">Legal</h4>
            <ul className="space-y-2.5">
              {legalLinks.map((link) => (
                <li key={link.label}>
                  <Link
                    href={link.href}
                    className="text-sm text-neutral-06 transition-colors hover:text-white"
                  >
                    {link.label}
                  </Link>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Copyright */}
        <div className="mt-12 border-t border-white/10 pt-6">
          <p className="text-xs text-neutral-05">
            &copy;{new Date().getFullYear()} Angle. All rights reserved.
          </p>
        </div>
      </div>
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Visual verification**

1. Start dev server: `PORT=4113 mix phx.server` (or use existing)
2. Navigate to homepage
3. Scroll to footer
4. Verify:
   - Footer background extends full-width
   - Footer content constrained to ~1280px center
   - Content doesn't stretch on ultra-wide screens

**Step 5: Commit**

```bash
git add assets/js/layouts/footer.tsx
git commit -m "refactor: use Section component in Footer

- Footer now uses fullBleed with dark background
- Content constrained to max-w-7xl (1280px)
- Maintains existing styling and layout"
```

---

### Task 3: Update TrustStatsSection

**Files:**
- Modify: `assets/js/features/home/components/trust-stats-section.tsx:10-26`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section element with Section**

Replace lines 11-24 with:

```tsx
export function TrustStatsSection() {
  return (
    <Section fullBleed background="dark" className="py-10 lg:py-12">
      <div className="mx-auto grid max-w-4xl grid-cols-2 gap-8 lg:grid-cols-4">
        {stats.map((stat) => (
          <div key={stat.label} className="flex flex-col items-center text-center">
            <stat.icon className="mb-2 size-6 text-primary-600 dark:text-primary-400" />
            <span className="font-heading text-2xl font-bold lg:text-3xl">
              {stat.value}
            </span>
            <span className="mt-1 text-sm text-content-secondary">{stat.label}</span>
          </div>
        ))}
      </div>
    </Section>
  );
}
```

**Step 3: Update icon colors for dark background**

In the icon className, change to:

```tsx
<stat.icon className="mb-2 size-6 text-primary-400" />
```

And for text spans, use light colors:

```tsx
<span className="font-heading text-2xl font-bold text-white lg:text-3xl">
  {stat.value}
</span>
<span className="mt-1 text-sm text-white/80">{stat.label}</span>
```

**Step 4: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 5: Visual verification**

1. Navigate to homepage
2. Scroll to Trust Stats section
3. Verify:
   - Dark background extends full-width
   - Stats grid constrained to center
   - Icons and text visible on dark background
   - Toggle dark mode - check both themes

**Step 6: Commit**

```bash
git add assets/js/features/home/components/trust-stats-section.tsx
git commit -m "refactor: use Section with dark fullBleed in TrustStats

- Full-width dark background for visual separation
- Content constrained to max-w-4xl center
- Updated icon/text colors for dark background"
```

---

### Task 4: Update SellCtaSection

**Files:**
- Modify: `assets/js/features/home/components/sell-cta-section.tsx:5-44`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section element with Section**

Replace lines 6-42 with:

```tsx
export function SellCtaSection() {
  return (
    <Section fullBleed background="accent" className="py-10 lg:py-16">
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
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Visual verification**

1. Navigate to homepage
2. Scroll to Sell CTA section
3. Verify:
   - Subtle brand-colored background extends full-width
   - Content constrained to max-w-5xl center
   - Split layout (copy left, image right on desktop)
   - Toggle dark mode - check both themes

**Step 5: Commit**

```bash
git add assets/js/features/home/components/sell-cta-section.tsx
git commit -m "refactor: use Section with accent fullBleed in SellCTA

- Full-width subtle brand background for emphasis
- Content constrained to max-w-5xl center
- Maintains split layout and styling"
```

---

## Phase 2: Homepage Sections

### Task 5: Update GuestHero

**Files:**
- Modify: `assets/js/features/home/components/guest-hero.tsx:4-41`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section with Section component**

Replace lines 5-39 with:

```tsx
export function GuestHero() {
  return (
    <Section fullBleed background="gradient" className="relative overflow-hidden">
      {/* Decorative background pattern */}
      <div className="absolute inset-0 opacity-10">
        <div className="absolute left-1/4 top-1/4 size-64 rounded-full bg-primary-400 blur-3xl" />
        <div className="absolute bottom-1/4 right-1/4 size-48 rounded-full bg-primary-600 blur-3xl" />
      </div>

      <div className="relative py-16 text-center lg:py-24">
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
            className="rounded-full bg-white px-8 text-primary-1000 shadow-lg transition-all hover:bg-gray-50 hover:shadow-xl"
            asChild
          >
            <Link href="/auth/register">Sign Up Free</Link>
          </Button>
          <Button
            variant="outline"
            size="lg"
            className="rounded-full border-2 border-white bg-transparent px-8 text-white shadow-md transition-all hover:bg-white/20"
            asChild
          >
            <Link href="#search-section">Browse Items</Link>
          </Button>
        </div>
      </div>
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/guest-hero.tsx
git commit -m "refactor: use Section with gradient fullBleed in GuestHero

- Full-width gradient background
- Content constrained to max-w-7xl
- Maintains decorative background pattern"
```

---

### Task 6: Update HowItWorksSection

**Files:**
- Modify: `assets/js/features/home/components/how-it-works-section.tsx:21-40`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section with Section component**

Replace lines 22-38 with:

```tsx
export function HowItWorksSection() {
  return (
    <Section fullBleed background="muted" className="py-10 lg:py-12">
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
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/how-it-works-section.tsx
git commit -m "refactor: use Section with muted fullBleed in HowItWorks

- Full-width muted background for visual separation
- Content constrained to max-w-3xl
- Maintains 3-column grid layout"
```

---

### Task 7: Update SearchSection

**Files:**
- Modify: `assets/js/features/home/components/search-section.tsx:24-54`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section with Section component**

Replace lines 24-53 with:

```tsx
export function SearchSection({ categories }: SearchSectionProps) {
  const [query, setQuery] = useState("");

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (query.trim()) {
      router.visit(`/search?q=${encodeURIComponent(query.trim())}`);
    }
  };

  const trendingCategories = categories.slice(0, 6);

  return (
    <Section id="search-section" maxWidth="max-w-2xl" className="py-10 lg:py-12">
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
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/search-section.tsx
git commit -m "refactor: use Section in SearchSection with narrow max-width

- Content constrained to max-w-2xl for focused search
- Maintains anchor link id for guest hero
- Removes manual padding (Section handles it)"
```

---

### Task 8: Update EndingSoonSection

**Files:**
- Modify: `assets/js/features/home/components/ending-soon-section.tsx:33-61`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section with Section component**

Replace lines 33-60 with:

```tsx
export function EndingSoonSection({ initialItems, watchlistedMap = {} }: EndingSoonSectionProps) {
  const { data } = useAshQuery(
    ["homepage", "ending-soon"],
    () =>
      listItems({
        fields: homepageItemCardFields,
        filter: { publicationStatus: { eq: "published" } },
        sort: "++end_time",
        page: { limit: 8 },
        headers: buildCSRFHeaders(),
      }),
    {
      refetchInterval: 60_000,
      initialData: initialItems,
    }
  );

  const items = Array.isArray(data) ? data : data?.results ?? initialItems;

  return (
    <Section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Ending Soon
        </h2>
        <Link
          href="/search?sort=ending_soon"
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
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/ending-soon-section.tsx
git commit -m "refactor: use Section in EndingSoonSection

- Content constrained to max-w-7xl
- No background (keeps visual variety)
- Maintains 4-column grid and refetch logic"
```

---

### Task 9: Update RecommendedSection

**Files:**
- Modify: `assets/js/features/home/components/recommended-section.tsx`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Wrap component in Section**

Find the main container and wrap with Section, remove manual padding classes.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/recommended-section.tsx
git commit -m "refactor: use Section in RecommendedSection

- Content constrained to max-w-7xl
- Maintains horizontal scroll layout"
```

---

### Task 10: Update HotNowSection

**Files:**
- Modify: `assets/js/features/home/components/hot-now-section.tsx`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Wrap component in Section**

Find the main container and wrap with Section, remove manual padding classes.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/hot-now-section.tsx
git commit -m "refactor: use Section in HotNowSection

- Content constrained to max-w-7xl
- Maintains mosaic grid layout"
```

---

### Task 11: Update BrowseCategoriesSection

**Files:**
- Modify: `assets/js/features/home/components/browse-categories-section.tsx:24-75`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace section with Section component**

Replace lines 24 onwards with Section wrapper:

```tsx
export function BrowseCategoriesSection({ categories }: BrowseCategoriesSectionProps) {
  const displayCategories = categories.slice(0, 8);

  return (
    <Section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        {/* existing header */}
      </div>
      {/* existing content */}
    </Section>
  );
}
```

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/home/components/browse-categories-section.tsx
git commit -m "refactor: use Section in BrowseCategoriesSection

- Content constrained to max-w-7xl
- Maintains category grid layout"
```

---

## Phase 3: Functional Pages

### Task 12: Update Search Page

**Files:**
- Modify: `assets/js/pages/search.tsx:162-393`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Replace div wrapper with Section**

Replace line 165 `<div className="mx-auto max-w-7xl px-4 py-6 lg:px-10">` with:

```tsx
<Section className="py-6">
```

And remove the closing `</div>` at line 391.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/pages/search.tsx
git commit -m "refactor: use Section in Search page

- Replace manual max-w-7xl with Section component
- Maintains existing search and filter functionality"
```

---

### Task 13: Update Dashboard Page

**Files:**
- Modify: `assets/js/pages/dashboard.tsx:16-70`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Wrap entire page content in Section**

Replace lines 19-20 with:

```tsx
<Section fullBleed background="muted" className="min-h-screen py-6">
  {/* existing content */}
</Section>
```

And remove the outer div wrappers.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/pages/dashboard.tsx
git commit -m "refactor: use Section in Dashboard page

- Full-width muted background for entire page
- Content constrained to max-w-7xl
- Stats cards now properly constrained on ultra-wide"
```

---

### Task 14: Update BidsLayout

**Files:**
- Modify: `assets/js/features/bidding/components/bids-layout.tsx:39-79`

**Step 1: Import Section component**

At top of file, add:

```tsx
import { Section } from "@/components/layouts";
```

**Step 2: Wrap desktop layout in Section**

Replace line 40 with:

```tsx
<Section className="hidden lg:flex lg:min-h-[calc(100vh-88px)] lg:gap-10 lg:py-6">
  {/* existing sidebar and content */}
</Section>
```

And remove the div wrapper and manual classes.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/bidding/components/bids-layout.tsx
git commit -m "refactor: use Section in BidsLayout

- Sidebar + content constrained to max-w-7xl
- Maintains sidebar layout and navigation"
```

---

### Task 15: Update Watchlist (Similar to Bids)

**Files:**
- Modify: Watchlist layout components similarly

**Step 1: Find watchlist layout file**

Run: `find assets/js/features/watchlist -name "*layout*.tsx" -o -name "watchlist.tsx"`

**Step 2: Apply same Section pattern as BidsLayout**

Import Section and wrap the desktop sidebar + content layout.

**Step 3: Verify TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/watchlist/[files]
git commit -m "refactor: use Section in Watchlist

- Sidebar + content constrained to max-w-7xl
- Maintains existing layout structure"
```

---

## Final Verification

### Task 16: Comprehensive Visual QA

**Step 1: Test all breakpoints**

For each page (homepage, dashboard, bids, watchlist, search):

1. Mobile (375px): `Cmd+Option+I` → Toggle device toolbar → iPhone SE
2. Tablet (768px): iPad
3. Desktop (1024px): Responsive design mode
4. Large (1920px): Standard desktop
5. Ultra-wide (2560px): Check content constrained, backgrounds extend

**Step 2: Test dark mode**

On each page:
1. Toggle theme switcher
2. Verify all background variants look correct
3. Check text contrast on dark backgrounds

**Step 3: Test interactions**

1. Click all "View All" links - verify navigation works
2. Submit search form - verify functionality preserved
3. Navigate sidebar tabs (Bids, Watchlist) - verify layout stable
4. Check that no horizontal scrollbars appear

**Step 4: TypeScript validation**

Run: `cd assets && npx tsc --noEmit`
Expected: No TypeScript errors

**Step 5: Create summary document**

Create `docs/plans/2026-02-19-hybrid-layout-verification.md`:

```markdown
# Hybrid Layout Verification Results

## Pages Updated
- ✅ Footer
- ✅ Homepage (10 sections)
- ✅ Dashboard
- ✅ Search
- ✅ Bids
- ✅ Watchlist

## Breakpoint Testing
- ✅ 375px (Mobile)
- ✅ 768px (Tablet)
- ✅ 1024px (Desktop)
- ✅ 1920px (Large)
- ✅ 2560px (Ultra-wide)

## Dark Mode Testing
- ✅ All backgrounds render correctly
- ✅ Text contrast acceptable on all backgrounds
- ✅ Theme toggle works on all pages

## Functionality Testing
- ✅ Navigation links work
- ✅ Forms submit correctly
- ✅ Sidebar navigation functional
- ✅ No horizontal scrollbars

## TypeScript
- ✅ No compilation errors

## Issues Found
[List any issues discovered during QA]

## Date: 2026-02-19
```

**Step 6: Final commit**

```bash
git add docs/plans/2026-02-19-hybrid-layout-verification.md
git commit -m "docs: hybrid layout verification results

All pages updated with Section component, visual QA passed"
```

---

## Rollback Plan

If critical issues found:

**Revert single component:**
```bash
git log --oneline | grep "refactor.*Section"
git revert <commit-hash>
```

**Revert entire feature:**
```bash
git log --oneline | grep "hybrid layout"
git revert <first-commit>..<last-commit>
```

**Test after rollback:**
```bash
cd assets && npx tsc --noEmit
PORT=4113 mix phx.server
```

---

## Success Criteria

- ✅ All 17 files updated with Section component
- ✅ TypeScript compiles without errors
- ✅ Visual QA passed at all breakpoints
- ✅ Dark mode works correctly
- ✅ All functionality preserved (links, forms, navigation)
- ✅ Content constrained to 1280px on large screens
- ✅ Full-bleed backgrounds extend to screen edges
- ✅ No horizontal scrollbars at any viewport size

