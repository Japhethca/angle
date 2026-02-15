# Preferences Page + Dark Mode Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Preferences settings page with functional Language and Theme (Light/Dark) switching, plus full dark mode support across the entire app using semantic color tokens.

**Architecture:** Define semantic CSS variable tokens (`--surface`, `--content`, `--border-subtle`, etc.) that auto-switch between light and dark values. Replace all hardcoded neutral color classes (`bg-white`, `text-neutral-01`, etc.) with semantic equivalents (`bg-surface`, `text-content`). A `ThemeProvider` React context toggles the `dark` class on `<html>` via localStorage.

**Tech Stack:** React 19, Tailwind CSS v4, Inertia.js, Phoenix, shadcn/ui, Lucide icons, localStorage

**Worktree:** `/Users/chidex/sources/mine/angle/.worktrees/feat-preferences-dark-mode`

**Design doc:** `docs/plans/2026-02-15-preferences-page-design.md`

**Figma:** Desktop `454-5962`, Mobile `636-6571`, Color system `125-12992`

---

## Semantic Token System

### Token definitions (added to `app.css`)

These CSS variables switch automatically between light/dark via the `.dark` class. Registered in `@theme` as Tailwind colors.

**Surface tokens** (backgrounds):

| Token | Tailwind class | Light value | Dark value | Replaces |
|-------|---------------|-------------|------------|----------|
| `--surface` | `bg-surface` | `#FFFFFF` | `#0A0A0A` | `bg-white` |
| `--surface-secondary` | `bg-surface-secondary` | `#FAFAFA` | `#141414` | `bg-neutral-09` |
| `--surface-muted` | `bg-surface-muted` | `#F5F5F5` | `#1A1A1A` | `bg-neutral-08` |
| `--surface-inset` | `bg-surface-inset` | `#E5E5E5` | `#262626` | `bg-neutral-07` |
| `--surface-emphasis` | `bg-surface-emphasis` | `#D4D4D4` | `#404040` | `bg-neutral-06` |

**Content tokens** (text):

| Token | Tailwind class | Light value | Dark value | Replaces |
|-------|---------------|-------------|------------|----------|
| `--content` | `text-content` | `#0A0A0A` | `#FAFAFA` | `text-neutral-01`, `text-neutral-02` |
| `--content-secondary` | `text-content-secondary` | `#404040` | `#D4D4D4` | `text-neutral-03` |
| `--content-tertiary` | `text-content-tertiary` | `#737373` | `#A3A3A3` | `text-neutral-04` |
| `--content-placeholder` | `text-content-placeholder` | `#A3A3A3` | `#737373` | `text-neutral-05` |

**Border tokens:**

| Token | Tailwind class | Light value | Dark value | Replaces |
|-------|---------------|-------------|------------|----------|
| `--border-subtle` | `border-subtle` | `#E5E5E5` | `#262626` | `border-neutral-07` |
| `--border-strong` | `border-strong` | `#D4D4D4` | `#404040` | `border-neutral-06` |

**Feedback tokens** (from Figma color system):

| Token | Light value | Dark value | Replaces |
|-------|-------------|------------|----------|
| `--feedback-success` / `--feedback-success-muted` | `#1E8567` / `#dcfce7` | `#4ade80` / `#052e16` | `text-green-700` / `bg-green-100` |
| `--feedback-warning` / `--feedback-warning-muted` | `#C15100` / `#fff7ed` | `#fb923c` / `#431407` | `text-yellow-800` / `bg-yellow-100` |
| `--feedback-error` / `--feedback-error-muted` | `#B00020` / `#fef2f2` | `#f87171` / `#450a0a` | `text-red-*` / `bg-red-50` |
| `--feedback-info` / `--feedback-info-muted` | `#0000DB` / `#eff6ff` | `#60a5fa` / `#172554` | `text-blue-*` / `bg-blue-50` |

### Migration cheat sheet

```
bg-white              → bg-surface
bg-neutral-08         → bg-surface-muted
bg-neutral-09         → bg-surface-secondary
bg-neutral-07         → bg-surface-inset
bg-neutral-06         → bg-surface-emphasis
bg-gray-50            → bg-surface-muted
text-neutral-01       → text-content
text-neutral-02       → text-content
text-neutral-03       → text-content-secondary
text-neutral-04       → text-content-tertiary
text-neutral-05       → text-content-placeholder
text-gray-500         → text-content-tertiary
text-gray-900         → text-content
text-gray-400         → text-content-placeholder
border-neutral-07     → border-subtle
border-neutral-06     → border-strong
hover:bg-neutral-07   → hover:bg-surface-inset
hover:bg-neutral-08   → hover:bg-surface-muted
hover:text-neutral-01 → hover:text-content
hover:text-neutral-02 → hover:text-content
hover:bg-gray-50      → hover:bg-surface-muted
bg-green-100          → bg-feedback-success-muted
text-green-700/800    → text-feedback-success
bg-red-50             → bg-feedback-error-muted
text-red-500          → text-feedback-error
hover:bg-red-50       → hover:bg-feedback-error-muted
bg-blue-50            → bg-feedback-info-muted
bg-yellow-100         → bg-feedback-warning-muted
text-yellow-800       → text-feedback-warning
```

**Keep as-is (no migration needed):**
- `bg-primary-600`, `text-primary-600`, `bg-primary-600/10`, `bg-primary-1000` — brand orange works on both themes
- `text-white` on colored backgrounds — stays white
- `bg-[#060818]` — footer is already dark
- All shadcn component classes (`bg-background`, `text-foreground`, etc.) — already token-based
- `border-white/10`, `bg-white/80` etc. — transparency-based overlays on images, keep as-is

---

## Tasks

### Task 1: Define Semantic Token System

Add CSS variables and Tailwind theme mappings.

**Files:**
- Modify: `assets/css/app.css`

**Step 1: Add semantic CSS variables to `:root` and `.dark`**

In `app.css`, inside `:root` (after the existing shadcn vars), add:

```css
  /* Semantic surface tokens */
  --surface: #FFFFFF;
  --surface-secondary: #FAFAFA;
  --surface-muted: #F5F5F5;
  --surface-inset: #E5E5E5;
  --surface-emphasis: #D4D4D4;

  /* Semantic content tokens */
  --content: #0A0A0A;
  --content-secondary: #404040;
  --content-tertiary: #737373;
  --content-placeholder: #A3A3A3;

  /* Semantic border tokens */
  --border-subtle: #E5E5E5;
  --border-strong: #D4D4D4;

  /* Feedback tokens (from Figma color system) */
  --feedback-success: #1E8567;
  --feedback-success-muted: #dcfce7;
  --feedback-warning: #C15100;
  --feedback-warning-muted: #fff7ed;
  --feedback-error: #B00020;
  --feedback-error-muted: #fef2f2;
  --feedback-info: #0000DB;
  --feedback-info-muted: #eff6ff;
```

Inside `.dark`, add matching overrides:

```css
  /* Semantic surface tokens */
  --surface: #0A0A0A;
  --surface-secondary: #141414;
  --surface-muted: #1A1A1A;
  --surface-inset: #262626;
  --surface-emphasis: #404040;

  /* Semantic content tokens */
  --content: #FAFAFA;
  --content-secondary: #D4D4D4;
  --content-tertiary: #A3A3A3;
  --content-placeholder: #737373;

  /* Semantic border tokens */
  --border-subtle: #262626;
  --border-strong: #404040;

  /* Feedback tokens */
  --feedback-success: #4ade80;
  --feedback-success-muted: #052e16;
  --feedback-warning: #fb923c;
  --feedback-warning-muted: #431407;
  --feedback-error: #f87171;
  --feedback-error-muted: #450a0a;
  --feedback-info: #60a5fa;
  --feedback-info-muted: #172554;
```

**Step 2: Register as Tailwind colors in `@theme`**

Add inside the `@theme {}` block:

```css
  /* Semantic color tokens */
  --color-surface: var(--surface);
  --color-surface-secondary: var(--surface-secondary);
  --color-surface-muted: var(--surface-muted);
  --color-surface-inset: var(--surface-inset);
  --color-surface-emphasis: var(--surface-emphasis);

  --color-content: var(--content);
  --color-content-secondary: var(--content-secondary);
  --color-content-tertiary: var(--content-tertiary);
  --color-content-placeholder: var(--content-placeholder);

  --color-border-subtle: var(--border-subtle);
  --color-border-strong: var(--border-strong);

  --color-feedback-success: var(--feedback-success);
  --color-feedback-success-muted: var(--feedback-success-muted);
  --color-feedback-warning: var(--feedback-warning);
  --color-feedback-warning-muted: var(--feedback-warning-muted);
  --color-feedback-error: var(--feedback-error);
  --color-feedback-error-muted: var(--feedback-error-muted);
  --color-feedback-info: var(--feedback-info);
  --color-feedback-info-muted: var(--feedback-info-muted);
```

**Step 3: Build to verify no CSS errors**

```
mix assets.build
```

**Step 4: Commit**

```
git commit -m "feat: define semantic color token system for dark mode support"
```

---

### Task 2: Theme Provider Hook

Create the `useTheme` hook and `ThemeProvider` context.

**Files:**
- Create: `assets/js/hooks/use-theme.tsx`

**Step 1: Create ThemeProvider + useTheme**

```tsx
import { createContext, useContext, useEffect, useState } from "react";

type Theme = "light" | "dark";

interface ThemeContextValue {
  theme: Theme;
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<Theme>(() => {
    if (typeof window === "undefined") return "light";
    return (localStorage.getItem("theme") as Theme) || "light";
  });

  useEffect(() => {
    const root = document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(theme);
    localStorage.setItem("theme", theme);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error("useTheme must be used within a ThemeProvider");
  }
  return context;
}
```

**Step 2: Commit**

```
git commit -m "feat: add ThemeProvider and useTheme hook"
```

---

### Task 3: Wire ThemeProvider into App Entry Points

**Files:**
- Modify: `assets/js/app.tsx`
- Modify: `assets/js/ssr.tsx`

**Step 1: Update app.tsx**

Add `import { ThemeProvider } from "@/hooks/use-theme";` and wrap `<App>`:

```tsx
setup({ App, el, props }) {
  hydrateRoot(
    el,
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <App {...props} />
      </ThemeProvider>
    </QueryClientProvider>
  );
},
```

**Step 2: Update ssr.tsx**

Same import, wrap in `setup()`:

```tsx
return (
  <QueryClientProvider client={queryClient}>
    <ThemeProvider>
      <App {...props} />
    </ThemeProvider>
  </QueryClientProvider>
);
```

**Step 3: Build and verify**

```
mix assets.build
```

**Step 4: Commit**

```
git commit -m "feat: wire ThemeProvider into app and SSR entry points"
```

---

### Task 4: Backend Route + Controller + Test

**Files:**
- Modify: `lib/angle_web/router.ex:115` (add route)
- Modify: `lib/angle_web/controllers/settings_controller.ex` (add action)
- Modify: `test/angle_web/controllers/settings_controller_test.exs` (add tests)

**Step 1: Add route in router.ex**

After `get "/settings/security"`, add:

```elixir
get "/settings/preferences", SettingsController, :preferences
```

**Step 2: Add controller action**

```elixir
def preferences(conn, _params) do
  conn
  |> assign_prop(:user, user_profile_data(conn))
  |> render_inertia("settings/preferences")
end
```

**Step 3: Add tests**

```elixir
describe "GET /settings/preferences" do
  test "renders settings/preferences page for authenticated user", %{conn: conn} do
    user = create_user(%{email: "prefs@example.com"})

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/settings/preferences")

    response = html_response(conn, 200)
    assert response =~ "settings/preferences"
  end

  test "redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/settings/preferences")
    assert redirected_to(conn) == ~p"/auth/login"
  end
end
```

**Step 4: Run tests**

```
mix test test/angle_web/controllers/settings_controller_test.exs
```

**Step 5: Commit**

```
git commit -m "feat: add /settings/preferences route and controller action"
```

---

### Task 5: Theme Card Component

**Files:**
- Create: `assets/js/features/settings/components/theme-card.tsx`

**Step 1: Create component** (matches Figma skeleton preview)

```tsx
import { cn } from "@/lib/utils";

interface ThemeCardProps {
  variant: "light" | "dark";
  selected: boolean;
  onClick: () => void;
}

export function ThemeCard({ variant, selected, onClick }: ThemeCardProps) {
  const isLight = variant === "light";

  return (
    <button type="button" onClick={onClick} className="flex flex-1 flex-col items-center gap-2">
      <div
        className={cn(
          "w-full rounded-lg border-2 p-1",
          selected ? "border-content" : "border-subtle"
        )}
      >
        <div
          className={cn(
            "flex flex-col gap-2 rounded p-2",
            isLight ? "bg-neutral-07" : "bg-neutral-01"
          )}
        >
          <div
            className={cn(
              "flex flex-col gap-2 rounded-md p-2 shadow-sm",
              isLight ? "bg-white" : "bg-neutral-03"
            )}
          >
            <div className={cn("h-2 w-20 rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
            <div className={cn("h-2 w-[100px] rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
          </div>
          {[1, 2].map((i) => (
            <div
              key={i}
              className={cn(
                "flex items-center gap-2 rounded-md p-2 shadow-sm",
                isLight ? "bg-white" : "bg-neutral-03"
              )}
            >
              <div className={cn("size-4 rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
              <div className={cn("h-2 w-[100px] rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
            </div>
          ))}
        </div>
      </div>
      <span className="text-sm text-content-secondary">
        {isLight ? "Light" : "Dark"}
      </span>
    </button>
  );
}
```

Note: ThemeCard uses hardcoded neutral colors intentionally — it's a static preview of what light/dark themes look like, not a themed component itself.

**Step 2: Commit**

```
git commit -m "feat: add ThemeCard skeleton preview component"
```

---

### Task 6: Preferences Form Component

**Files:**
- Create: `assets/js/features/settings/components/preferences-form.tsx`
- Modify: `assets/js/features/settings/index.ts` (add export)

**Step 1: Create form component**

```tsx
import { useState } from "react";
import { toast } from "sonner";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Label } from "@/components/ui/label";
import { useTheme } from "@/hooks/use-theme";
import { ThemeCard } from "./theme-card";

export function PreferencesForm() {
  const { theme, setTheme } = useTheme();
  const [selectedTheme, setSelectedTheme] = useState(theme);
  const [language, setLanguage] = useState(
    () => (typeof window !== "undefined" ? localStorage.getItem("language") : null) || "en"
  );

  const isDirty = selectedTheme !== theme || language !== (localStorage.getItem("language") || "en");

  const handleSave = () => {
    setTheme(selectedTheme);
    localStorage.setItem("language", language);
    toast.success("Preferences saved");
  };

  return (
    <div className="space-y-8">
      <div className="space-y-2">
        <Label>Language</Label>
        <Select value={language} onValueChange={setLanguage}>
          <SelectTrigger className="w-full">
            <SelectValue placeholder="Select language" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="en">English</SelectItem>
          </SelectContent>
        </Select>
      </div>

      <div className="space-y-2">
        <h3 className="font-heading text-base font-medium text-content-secondary">Theme</h3>
        <div className="flex gap-4 lg:gap-8">
          <ThemeCard variant="light" selected={selectedTheme === "light"} onClick={() => setSelectedTheme("light")} />
          <ThemeCard variant="dark" selected={selectedTheme === "dark"} onClick={() => setSelectedTheme("dark")} />
        </div>
      </div>

      <Button
        onClick={handleSave}
        disabled={!isDirty}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90 lg:w-auto"
      >
        Save Changes
      </Button>
    </div>
  );
}
```

**Step 2: Export from index.ts**

Add to `assets/js/features/settings/index.ts`:

```ts
export { PreferencesForm } from "./components/preferences-form";
```

**Step 3: Commit**

```
git commit -m "feat: add PreferencesForm with language and theme selection"
```

---

### Task 7: Preferences Page + Sidebar Link

**Files:**
- Create: `assets/js/pages/settings/preferences.tsx`
- Modify: `assets/js/features/settings/components/settings-layout.tsx:24`
- Modify: `assets/js/pages/settings/index.tsx` (update mobile menu)

**Step 1: Create page**

```tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, PreferencesForm } from "@/features/settings";
import type { SettingsUser } from "@/features/settings";

interface SettingsPreferencesProps {
  user: SettingsUser;
}

export default function SettingsPreferences({ user }: SettingsPreferencesProps) {
  return (
    <>
      <Head title="Preferences" />
      <SettingsLayout title="Preferences">
        <PreferencesForm />
      </SettingsLayout>
    </>
  );
}
```

**Step 2: Enable sidebar link**

In `settings-layout.tsx`, change:

```tsx
// FROM:
{ label: "Preferences", href: "#", disabled: true, icon: SlidersHorizontal },
// TO:
{ label: "Preferences", href: "/settings/preferences", icon: SlidersHorizontal },
```

**Step 3: Update mobile settings index**

In `pages/settings/index.tsx`, update the Preferences menu item href to `/settings/preferences` and remove `disabled`.

**Step 4: Build + test**

```
mix assets.build && mix test
```

**Step 5: Commit**

```
git commit -m "feat: add preferences page and enable sidebar link"
```

---

### Task 8: Migrate Navigation Components to Semantic Tokens

Replace hardcoded neutral classes with semantic token classes. **No `dark:` prefixes needed.**

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx`
- Modify: `assets/js/navigation/bottom-nav.tsx`
- Modify: `assets/js/navigation/category-mega-menu.tsx`

**Use the migration cheat sheet above.** Key replacements in main-nav.tsx:

```
bg-white                    → bg-surface
border-neutral-07           → border-subtle
text-neutral-03             → text-content-secondary
hover:text-neutral-01       → hover:text-content
bg-neutral-08               → bg-surface-muted
text-neutral-01             → text-content
text-neutral-05             → text-content-placeholder
hover:bg-neutral-08         → hover:bg-surface-muted
```

**Step 1: Migrate all three files using the cheat sheet**

**Step 2: Build + verify visually**

**Step 3: Commit**

```
git commit -m "refactor: migrate navigation components to semantic color tokens"
```

---

### Task 9: Migrate Layout Components

**Files:**
- Modify: `assets/js/layouts/footer.tsx` (already dark-themed, minimal changes)
- Modify: `assets/js/layouts/auth-layout.tsx`

**Step 1: Migrate using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate layout components to semantic color tokens"
```

---

### Task 10: Migrate Settings Components

**Files:**
- Modify: `assets/js/features/settings/components/settings-layout.tsx`
- Modify: `assets/js/features/settings/components/account-form.tsx`
- Modify: `assets/js/features/settings/components/change-password-form.tsx`
- Modify: `assets/js/features/settings/components/profile-image-section.tsx`
- Modify: `assets/js/features/settings/components/quick-sign-in-section.tsx`
- Modify: `assets/js/features/settings/components/store-form.tsx`
- Modify: `assets/js/features/settings/components/store-logo-section.tsx`
- Modify: `assets/js/features/settings/components/store-verification-section.tsx`
- Modify: `assets/js/features/settings/components/two-factor-section.tsx`
- Modify: `assets/js/features/settings/components/verification-section.tsx`
- Modify: `assets/js/pages/settings/index.tsx`

**Step 1: Migrate all files using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate settings components to semantic color tokens"
```

---

### Task 11: Migrate Home Page Components

**Files:**
- Modify: `assets/js/pages/home.tsx`
- Modify: `assets/js/features/home/components/browse-categories-section.tsx`
- Modify: `assets/js/features/home/components/featured-item-carousel.tsx`
- Modify: `assets/js/features/home/components/hot-now-section.tsx`
- Modify: `assets/js/features/home/components/ending-soon-section.tsx`
- Modify: `assets/js/features/home/components/recommended-section.tsx`

**Step 1: Migrate using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate home page components to semantic color tokens"
```

---

### Task 12: Migrate Item Components + Pages

**Files:**
- Modify: `assets/js/features/items/components/category-item-card.tsx`
- Modify: `assets/js/features/items/components/category-item-list-card.tsx`
- Modify: `assets/js/features/items/components/item-card.tsx`
- Modify: `assets/js/features/items/components/item-detail-tabs.tsx`
- Modify: `assets/js/features/items/components/item-image-gallery.tsx`
- Modify: `assets/js/features/items/components/seller-card.tsx`
- Modify: `assets/js/features/items/components/similar-items.tsx`
- Modify: `assets/js/features/items/components/item-form.tsx`
- Modify: `assets/js/pages/items/new.tsx`
- Modify: `assets/js/pages/items/show.tsx`

**Step 1: Migrate using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate item components and pages to semantic color tokens"
```

---

### Task 13: Migrate Bidding Components

**Files:**
- Modify: `assets/js/features/bidding/components/bid-form.tsx`
- Modify: `assets/js/features/bidding/components/bid-section.tsx`
- Modify: `assets/js/features/bidding/components/confirm-bid-dialog.tsx`

**Step 1: Migrate using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate bidding components to semantic color tokens"
```

---

### Task 14: Migrate Category, Store + Remaining Pages

**Files:**
- Modify: `assets/js/pages/categories/index.tsx`
- Modify: `assets/js/pages/categories/show.tsx`
- Modify: `assets/js/pages/store/show.tsx`
- Modify: `assets/js/pages/bids.tsx`
- Modify: `assets/js/pages/watchlist.tsx`
- Modify: `assets/js/pages/profile.tsx`
- Modify: `assets/js/pages/dashboard.tsx`

**Step 1: Migrate using cheat sheet**

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate category, store, and remaining pages to semantic color tokens"
```

---

### Task 15: Migrate Auth + Admin Components

**Files:**
- Modify: `assets/js/features/auth/components/login-form.tsx`
- Modify: `assets/js/features/auth/components/register-form.tsx`
- Modify: `assets/js/features/auth/components/forgot-password-form.tsx`
- Modify: `assets/js/features/auth/components/reset-password-form.tsx`
- Modify: `assets/js/pages/auth/confirm-new-user.tsx`
- Modify: `assets/js/pages/auth/verify-account.tsx`
- Modify: `assets/js/pages/admin/users.tsx`

**Step 1: Migrate using cheat sheet**

Special cases for auth:
- `bg-orange-500 hover:bg-orange-600 text-white` — keep as-is (brand button on auth pages)
- `bg-white` dividers → `bg-surface`
- `text-gray-*` → use `text-content-*` equivalents

**Step 2: Build + verify**

**Step 3: Commit**

```
git commit -m "refactor: migrate auth and admin components to semantic color tokens"
```

---

### Task 16: Final Verification

**Step 1: Full build**

```
mix assets.build
```

**Step 2: Full test suite**

```
mix test
```

**Step 3: Visual verification against Figma**

Compare with Figma designs (desktop `454-5962`, mobile `636-6571`):
- Navigate to `/settings/preferences`
- Verify language dropdown, theme cards, save button match Figma
- Toggle to dark mode — verify entire app switches correctly
- Check: navbar, settings pages, home, item pages, categories, store, auth pages
- Check mobile views for bottom nav, mobile settings menu

**Step 4: Fix any issues and commit**

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Define semantic token system in CSS | 1 |
| 2 | ThemeProvider hook | 1 new |
| 3 | Wire into app entry points | 2 |
| 4 | Backend route + controller + test | 3 |
| 5 | ThemeCard component | 1 new |
| 6 | PreferencesForm component | 1 new, 1 export |
| 7 | Preferences page + sidebar link | 1 new, 2 modified |
| 8 | Migrate navigation | 3 |
| 9 | Migrate layouts | 2 |
| 10 | Migrate settings components | 11 |
| 11 | Migrate home components | 6 |
| 12 | Migrate item components | 10 |
| 13 | Migrate bidding components | 3 |
| 14 | Migrate category/store/other pages | 7 |
| 15 | Migrate auth/admin components | 7 |
| 16 | Final verification | — |
