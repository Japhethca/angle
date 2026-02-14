# Category Mega-Menu Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a hover-triggered mega-menu dropdown to the "Categories" nav link on desktop, showing all top-level categories with their subcategories in a 3-column grid.

**Architecture:** ETS-cached typed query provides nav categories as a shared Inertia prop. Frontend uses shadcn NavigationMenu (Radix-based) for the hover dropdown panel. Mobile nav unchanged.

**Tech Stack:** Ash typed queries, GenServer + ETS, Inertia shared props, React, shadcn/ui NavigationMenu, Tailwind CSS

---

### Task 1: Define `nav_category` typed query

Add a new typed query to the Catalog domain that returns top-level categories with nested subcategories.

**Files:**
- Modify: `lib/angle/catalog.ex:10-21`

**Step 1: Add the typed query**

In `lib/angle/catalog.ex`, add a new `typed_query` inside the existing `resource Angle.Catalog.Category do` block, after the `homepage_category` typed query:

```elixir
typed_query :nav_category, :read do
  ts_result_type_name "NavCategory"
  ts_fields_const_name "navCategoryFields"
  fields [:id, :name, :slug, categories: [:id, :name, :slug]]
  filter expr(is_nil(parent_id))
end
```

This fetches only top-level categories (where `parent_id` is nil) and includes their child `categories` relationship with `id`, `name`, and `slug` fields.

**Step 2: Run Ash codegen**

Run: `mix ash.codegen --dev`

If it generates a migration, that's expected (the filter may require no migration since it's a query-time filter). Review any generated migration.

**Step 3: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors.

**Step 4: Generate TypeScript types**

Run: `mix ash_typescript.codegen`
Expected: `assets/js/ash_rpc.ts` updated with `NavCategory` type and `navCategoryFields` const.

**Step 5: Verify the typed query works**

Run in iex:
```
iex -S mix
AshTypescript.Rpc.run_typed_query(:angle, :nav_category, %{}, nil)
```
Expected: Returns `%{"success" => true, "data" => [...]}` with top-level categories containing nested `categories` arrays.

**Step 6: Commit**

```bash
git add lib/angle/catalog.ex assets/js/ash_rpc.ts
git commit -m "feat: add nav_category typed query for mega-menu"
```

---

### Task 2: Create `CategoryCache` GenServer

Build an ETS-backed cache with 5-minute TTL that wraps the `nav_category` typed query.

**Files:**
- Create: `lib/angle/catalog/category_cache.ex`
- Modify: `lib/angle/application.ex:10-30`

**Step 1: Create the CategoryCache module**

Create `lib/angle/catalog/category_cache.ex`:

```elixir
defmodule Angle.Catalog.CategoryCache do
  @moduledoc """
  ETS-backed cache for navigation categories.
  Caches the nav_category typed query result with a 5-minute TTL.
  """

  use GenServer

  @table :nav_categories_cache
  @ttl_ms :timer.minutes(5)

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Returns cached nav categories. On cache miss or TTL expiry,
  fetches from the nav_category typed query and caches the result.
  """
  def get_nav_categories do
    case :ets.lookup(@table, :nav_categories) do
      [{:nav_categories, data, inserted_at}] ->
        if System.monotonic_time(:millisecond) - inserted_at < @ttl_ms do
          data
        else
          fetch_and_cache()
        end

      [] ->
        fetch_and_cache()
    end
  end

  # Server callbacks

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  # Private

  defp fetch_and_cache do
    case AshTypescript.Rpc.run_typed_query(:angle, :nav_category, %{}, nil) do
      %{"success" => true, "data" => data} ->
        results = extract_results(data)
        :ets.insert(@table, {:nav_categories, results, System.monotonic_time(:millisecond)})
        results

      _ ->
        []
    end
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
```

**Step 2: Add to supervision tree**

In `lib/angle/application.ex`, add `Angle.Catalog.CategoryCache` to the `children` list, before `AngleWeb.Endpoint`:

```elixir
children = [
  AngleWeb.Telemetry,
  Angle.Repo,
  {DNSCluster, query: Application.get_env(:angle, :dns_cluster_query) || :ignore},
  {Oban,
   AshOban.config(
     Application.fetch_env!(:angle, :ash_domains),
     Application.fetch_env!(:angle, Oban)
   )},
  {Phoenix.PubSub, name: Angle.PubSub},
  Angle.Catalog.CategoryCache,
  {Inertia.SSR, path: Path.join([Application.app_dir(:angle), "priv"])},
  AngleWeb.Endpoint,
  {Absinthe.Subscription, AngleWeb.Endpoint},
  AshGraphql.Subscription.Batcher,
  {AshAuthentication.Supervisor, [otp_app: :angle]}
]
```

**Step 3: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors.

**Step 4: Test in iex**

Run:
```
iex -S mix
Angle.Catalog.CategoryCache.get_nav_categories()
```
Expected: Returns a list of category maps with nested subcategories. Second call should be faster (cached).

**Step 5: Commit**

```bash
git add lib/angle/catalog/category_cache.ex lib/angle/application.ex
git commit -m "feat: add CategoryCache GenServer with ETS and 5-min TTL"
```

---

### Task 3: Create shared Inertia prop plug

Add a plug that injects `nav_categories` from the cache into every page's Inertia props.

**Files:**
- Create: `lib/angle_web/plugs/nav_categories.ex`
- Modify: `lib/angle_web/router.ex:11-21`

**Step 1: Create the plug**

Create `lib/angle_web/plugs/nav_categories.ex`:

```elixir
defmodule AngleWeb.Plugs.NavCategories do
  @moduledoc """
  Assigns nav_categories as a shared Inertia prop from the ETS cache.
  """

  import Inertia.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    categories = Angle.Catalog.CategoryCache.get_nav_categories()
    assign_prop(conn, :nav_categories, categories)
  end
end
```

**Step 2: Add plug to the browser pipeline**

In `lib/angle_web/router.ex`, add the plug to the `:browser` pipeline, after the `Inertia.Plug` line:

```elixir
pipeline :browser do
  plug :accepts, ["html"]
  plug :fetch_session
  plug :fetch_live_flash
  plug :put_root_layout, html: {AngleWeb.Layouts, :root}
  plug :protect_from_forgery
  plug :put_secure_browser_headers
  plug :load_current_user
  plug Inertia.Plug
  plug AngleWeb.Plugs.NavCategories
end
```

**Step 3: Verify compilation**

Run: `mix compile`
Expected: Compiles without errors.

**Step 4: Verify prop is available**

Start server: `mix phx.server`
Visit `http://localhost:4111` and inspect the Inertia page props (check the `#app` div's `data-page` attribute in the HTML source or React devtools).
Expected: `nav_categories` array is present in props.

**Step 5: Commit**

```bash
git add lib/angle_web/plugs/nav_categories.ex lib/angle_web/router.ex
git commit -m "feat: add NavCategories plug for shared Inertia prop"
```

---

### Task 4: Create `CategoryMegaMenu` React component

Build the mega-menu dropdown content panel.

**Files:**
- Create: `assets/js/navigation/category-mega-menu.tsx`

**Step 1: Create the component**

Create `assets/js/navigation/category-mega-menu.tsx`:

```tsx
import { Link } from '@inertiajs/react';

interface NavSubcategory {
  id: string;
  name: string;
  slug: string;
}

interface NavCategory {
  id: string;
  name: string;
  slug: string;
  categories: NavSubcategory[];
}

interface CategoryMegaMenuProps {
  categories: NavCategory[];
}

export function CategoryMegaMenu({ categories }: CategoryMegaMenuProps) {
  return (
    <div className="grid grid-cols-3 gap-x-[104px] gap-y-10 p-6">
      {categories.map(category => (
        <div key={category.id} className="flex flex-col gap-2">
          <Link
            href={`/categories/${category.slug}`}
            className="text-base font-medium text-neutral-01 hover:underline"
          >
            {category.name}
          </Link>
          {category.categories.length > 0 && (
            <div className="flex flex-col gap-2">
              {category.categories.map(sub => (
                <Link
                  key={sub.id}
                  href={`/categories/${category.slug}/${sub.slug}`}
                  className="text-sm text-neutral-03 transition-colors hover:text-neutral-01"
                >
                  {sub.name}
                </Link>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
```

**Step 2: Verify TypeScript**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors from this file.

**Step 3: Commit**

```bash
git add assets/js/navigation/category-mega-menu.tsx
git commit -m "feat: add CategoryMegaMenu component for nav dropdown"
```

---

### Task 5: Update `Layout` to pass `nav_categories` to `MainNav`

Read `nav_categories` from Inertia page props and pass it down.

**Files:**
- Modify: `assets/js/layouts/layout.tsx:14-31`
- Modify: `assets/js/features/auth/types.ts:31-40`

**Step 1: Add `nav_categories` to `PageProps` type**

In `assets/js/features/auth/types.ts`, update the `PageProps` interface to include `nav_categories`:

```typescript
export interface PageProps {
  auth: AuthState;
  flash: {
    info?: string;
    error?: string;
    success?: string;
  };
  csrf_token: string;
  nav_categories: Array<{
    id: string;
    name: string;
    slug: string;
    categories: Array<{
      id: string;
      name: string;
      slug: string;
    }>;
  }>;
  [key: string]: any;
}
```

**Step 2: Pass `nav_categories` to `MainNav`**

In `assets/js/layouts/layout.tsx`, read `nav_categories` from page props and pass to `MainNav`:

```tsx
export default function Layout({ children }: LayoutProps) {
  const { flash, nav_categories } = usePage<PageProps>().props;

  // ... existing flash useEffect ...

  return (
    <div className="flex min-h-screen flex-col">
      <MainNav navCategories={nav_categories ?? []} />
      <main className="flex-1 pb-[72px] lg:pb-0">{children}</main>
      <Footer />
      <BottomNav />
      <Toaster />
    </div>
  );
}
```

**Step 3: Verify TypeScript (will fail until Task 6 updates MainNav)**

Run: `cd assets && npx tsc --noEmit`
Expected: Error about `navCategories` prop not existing on `MainNav` — this is expected and will be fixed in Task 6.

**Step 4: Commit**

```bash
git add assets/js/layouts/layout.tsx assets/js/features/auth/types.ts
git commit -m "feat: pass nav_categories from layout to MainNav"
```

---

### Task 6: Update `MainNav` with NavigationMenu for Categories

Replace the "Categories" nav link with a NavigationMenu trigger + dropdown panel on desktop. Mobile nav unchanged.

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx`

**Step 1: Update MainNav**

Replace the contents of `assets/js/navigation/main-nav.tsx` with:

```tsx
import { useState } from 'react';
import { Link, usePage } from '@inertiajs/react';
import { Search, Bell, Menu, User } from 'lucide-react';
import { useAuth, AuthLink } from '@/features/auth';
import { Button } from '@/components/ui/button';
import { Sheet, SheetTrigger, SheetContent, SheetHeader, SheetTitle } from '@/components/ui/sheet';
import {
  NavigationMenu,
  NavigationMenuList,
  NavigationMenuItem,
  NavigationMenuTrigger,
  NavigationMenuContent,
} from '@/components/ui/navigation-menu';
import { CategoryMegaMenu } from './category-mega-menu';

interface NavCategory {
  id: string;
  name: string;
  slug: string;
  categories: Array<{ id: string; name: string; slug: string }>;
}

interface MainNavProps {
  navCategories: NavCategory[];
}

const navLinks = [
  { label: 'Home', href: '/' },
  { label: 'My Bids', href: '/bids', auth: true },
  { label: 'List Item', href: '/items/new', auth: true },
  { label: 'Watchlist', href: '/watchlist', auth: true },
];

export function MainNav({ navCategories }: MainNavProps) {
  const { authenticated } = useAuth();
  const { url } = usePage();
  const [mobileOpen, setMobileOpen] = useState(false);

  const visibleLinks = navLinks.filter(link => !link.auth || authenticated);

  const isActive = (href: string) => {
    if (href === '/') return url === '/';
    return url.startsWith(href);
  };

  const isCategoriesActive = url.startsWith('/categories');

  return (
    <nav className="sticky top-0 z-40 border-b border-neutral-07 bg-white">
      <div className="flex h-16 items-center justify-between px-4 lg:h-[72px] lg:px-10">
        {/* Left: Logo + Desktop nav links */}
        <div className="flex items-center gap-10">
          <Link href="/">
            <img src="/images/logo.svg" alt="Angle" className="h-8" />
          </Link>

          {/* Desktop nav links */}
          <div className="hidden items-center gap-8 lg:flex">
            {/* Home link */}
            <AuthLink
              href="/"
              className={
                isActive('/')
                  ? 'border-b-2 border-primary-1000 pb-1 text-sm font-medium text-primary-1000'
                  : 'text-sm text-neutral-03 transition-colors hover:text-neutral-01'
              }
            >
              Home
            </AuthLink>

            {/* Categories mega-menu */}
            <NavigationMenu>
              <NavigationMenuList>
                <NavigationMenuItem>
                  <NavigationMenuTrigger
                    className={
                      isCategoriesActive
                        ? 'h-auto rounded-none border-b-2 border-primary-1000 bg-transparent p-0 pb-1 text-sm font-medium text-primary-1000 shadow-none hover:bg-transparent focus:bg-transparent data-[state=open]:bg-transparent'
                        : 'h-auto rounded-none bg-transparent p-0 text-sm font-normal text-neutral-03 shadow-none transition-colors hover:bg-transparent hover:text-neutral-01 focus:bg-transparent data-[state=open]:bg-transparent'
                    }
                  >
                    Categories
                  </NavigationMenuTrigger>
                  <NavigationMenuContent className="p-0">
                    <CategoryMegaMenu categories={navCategories} />
                  </NavigationMenuContent>
                </NavigationMenuItem>
              </NavigationMenuList>
            </NavigationMenu>

            {/* Remaining nav links */}
            {visibleLinks.filter(link => link.href !== '/').map(link => (
              <AuthLink
                key={link.href}
                href={link.href}
                auth={link.auth}
                className={
                  isActive(link.href)
                    ? 'border-b-2 border-primary-1000 pb-1 text-sm font-medium text-primary-1000'
                    : 'text-sm text-neutral-03 transition-colors hover:text-neutral-01'
                }
              >
                {link.label}
              </AuthLink>
            ))}
          </div>
        </div>

        {/* Desktop right section */}
        <div className="hidden items-center gap-3 lg:flex">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-neutral-05" />
            <input
              placeholder="Search for an item..."
              className="h-10 w-[358px] rounded-lg bg-neutral-08 pl-10 pr-4 text-sm text-neutral-01 placeholder:text-neutral-05 outline-none"
              disabled
            />
          </div>

          {authenticated ? (
            <>
              <button className="flex size-10 items-center justify-center rounded-lg text-neutral-03 transition-colors hover:bg-neutral-08">
                <Bell className="size-5" />
              </button>
              <Link
                href="/profile"
                className="flex size-10 items-center justify-center rounded-lg text-neutral-03 transition-colors hover:bg-neutral-08"
              >
                <User className="size-5" />
              </Link>
            </>
          ) : (
            <>
              <Button variant="ghost" size="sm" asChild>
                <Link href="/auth/login">Sign In</Link>
              </Button>
              <Button
                size="sm"
                className="bg-primary-600 text-white hover:bg-primary-600/90"
                asChild
              >
                <Link href="/auth/register">Sign Up</Link>
              </Button>
            </>
          )}
        </div>

        {/* Mobile right section — unchanged */}
        <div className="flex items-center gap-2 lg:hidden">
          <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
            <Search className="size-[18px]" />
          </button>
          {authenticated && (
            <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
              <Bell className="size-[18px]" />
            </button>
          )}
          <Sheet open={mobileOpen} onOpenChange={setMobileOpen}>
            <SheetTrigger asChild>
              <button className="flex size-9 items-center justify-center rounded-lg bg-neutral-08 text-neutral-03">
                <Menu className="size-[18px]" />
              </button>
            </SheetTrigger>
            <SheetContent side="right" className="w-full bg-white sm:w-[300px]">
              <SheetHeader>
                <SheetTitle>
                  <img src="/images/logo.svg" alt="Angle" className="h-8" />
                </SheetTitle>
              </SheetHeader>

              <div className="flex flex-col gap-6 px-4 pt-4">
                {authenticated ? (
                  <Link
                    href="/profile"
                    className="text-sm font-medium text-neutral-01"
                    onClick={() => setMobileOpen(false)}
                  >
                    Profile
                  </Link>
                ) : (
                  <div className="flex flex-col gap-2">
                    <Button variant="outline" asChild>
                      <Link href="/auth/login" onClick={() => setMobileOpen(false)}>
                        Sign In
                      </Link>
                    </Button>
                    <Button className="bg-primary-600 text-white hover:bg-primary-600/90" asChild>
                      <Link href="/auth/register" onClick={() => setMobileOpen(false)}>
                        Sign Up
                      </Link>
                    </Button>
                  </div>
                )}
              </div>
            </SheetContent>
          </Sheet>
        </div>
      </div>
    </nav>
  );
}
```

Key changes from current `main-nav.tsx`:
- "Categories" removed from `navLinks` array
- `navCategories` accepted as prop
- Desktop: "Categories" rendered as `NavigationMenuTrigger` with `NavigationMenuContent` containing `CategoryMegaMenu`
- Trigger styled to match existing nav text (no pill/background)
- "Home" rendered separately before the NavigationMenu
- Other nav links rendered after the NavigationMenu
- Mobile section completely unchanged

**Step 2: Verify TypeScript**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors from these changes.

**Step 3: Verify visually**

Start server: `mix phx.server`
Visit `http://localhost:4111`

Check:
- Hover over "Categories" in desktop nav — mega-menu dropdown appears
- Dropdown shows 3-column grid of categories with subcategories
- Category names link to `/categories/{slug}`
- Subcategory items link to `/categories/{parentSlug}/{childSlug}`
- Other nav links still work
- Mobile nav unchanged — "Categories" still appears as regular link in mobile sheet

**Step 4: Commit**

```bash
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: replace Categories nav link with mega-menu dropdown"
```

---

### Task 7: Style the NavigationMenu viewport

Fine-tune the dropdown panel styling to match the Figma design: white background, rounded bottom corners, subtle shadow, proper width.

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx` (NavigationMenu className overrides)

**Step 1: Adjust NavigationMenu viewport styling**

The default shadcn `NavigationMenuViewport` has a border and generic styling. Override via className props on the `NavigationMenu` component. In `main-nav.tsx`, update the NavigationMenu section:

```tsx
<NavigationMenu className="static">
  <NavigationMenuList>
    <NavigationMenuItem>
      <NavigationMenuTrigger
        className={
          isCategoriesActive
            ? 'h-auto rounded-none border-b-2 border-primary-1000 bg-transparent p-0 pb-1 text-sm font-medium text-primary-1000 shadow-none hover:bg-transparent focus:bg-transparent data-[state=open]:bg-transparent'
            : 'h-auto rounded-none bg-transparent p-0 text-sm font-normal text-neutral-03 shadow-none transition-colors hover:bg-transparent hover:text-neutral-01 focus:bg-transparent data-[state=open]:bg-transparent'
        }
      >
        Categories
      </NavigationMenuTrigger>
      <NavigationMenuContent className="p-0">
        <CategoryMegaMenu categories={navCategories} />
      </NavigationMenuContent>
    </NavigationMenuItem>
  </NavigationMenuList>
</NavigationMenu>
```

If the viewport needs overriding (border removal, shadow, rounded corners), pass `viewport={false}` to `NavigationMenu` and let the content render inline, or override viewport styles via the component's className. Test both approaches and pick whichever matches the Figma design better.

The target viewport styling:
- White background
- Bottom-rounded 12px (`rounded-b-xl`)
- Shadow: `shadow-[0px_1px_2px_0px_rgba(0,0,0,0.08)]`
- No border
- Width accommodating 3 columns (~216px each + 104px gaps + 48px padding = ~860px)

**Step 2: Verify visually against Figma**

Compare the dropdown appearance with the Figma design. Adjust padding, gap, and column sizing as needed.

**Step 3: Commit**

```bash
git add assets/js/navigation/main-nav.tsx
git commit -m "style: match mega-menu dropdown to Figma design"
```

---

### Task 8: Final verification and cleanup

Run all checks and create PR.

**Step 1: TypeScript check**

Run: `cd assets && npx tsc --noEmit`
Expected: No new errors.

**Step 2: Elixir compilation**

Run: `mix compile`
Expected: No errors.

**Step 3: Run tests**

Run: `mix test`
Expected: All tests pass.

**Step 4: Manual verification**

Start server: `mix phx.server`
Visit `http://localhost:4111`

Checklist:
- [ ] Desktop: "Categories" in nav shows chevron indicator
- [ ] Desktop: Hovering "Categories" opens mega-menu dropdown
- [ ] Desktop: Dropdown shows 3-column grid of categories
- [ ] Desktop: Each category shows subcategories as clickable links
- [ ] Desktop: Category links go to `/categories/{slug}`
- [ ] Desktop: Subcategory links go to `/categories/{parentSlug}/{childSlug}`
- [ ] Desktop: Moving mouse away from dropdown closes it
- [ ] Desktop: Other nav links (Home, My Bids, etc.) still work
- [ ] Mobile: "Categories" appears as regular link (not dropdown)
- [ ] Mobile: Bottom nav unchanged
- [ ] SSR: Page loads correctly with categories data

**Step 5: Create PR**

```bash
git push -u origin feat/category-mega-menu
gh pr create --title "feat: category mega-menu dropdown in nav" --body "..."
```

---

## Files Summary

**New files:**
- `lib/angle/catalog/category_cache.ex` — ETS cache GenServer
- `lib/angle_web/plugs/nav_categories.ex` — shared Inertia prop plug
- `assets/js/navigation/category-mega-menu.tsx` — mega-menu component

**Modified files:**
- `lib/angle/catalog.ex` — add `nav_category` typed query
- `lib/angle/application.ex` — add CategoryCache to supervision tree
- `lib/angle_web/router.ex` — add NavCategories plug to browser pipeline
- `assets/js/ash_rpc.ts` — auto-regenerated (new NavCategory type)
- `assets/js/features/auth/types.ts` — add `nav_categories` to PageProps
- `assets/js/layouts/layout.tsx` — pass nav_categories to MainNav
- `assets/js/navigation/main-nav.tsx` — Categories becomes NavigationMenu trigger

**Not touched:**
- Mobile nav / bottom nav
- `assets/js/components/ui/navigation-menu.tsx` (use as-is, override via className)
- Pages (categories come through shared props)
