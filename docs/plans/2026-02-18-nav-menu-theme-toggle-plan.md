# Nav Menu & Theme Toggle Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add system theme support, redesign the profile popover menu, and add a theme toggle for non-auth users.

**Architecture:** Extend `useTheme` hook with "system" mode (matchMedia listener), create an inline 3-segment theme toggle component, update UserMenuContent menu items, add theme toggle to non-auth desktop/mobile nav, and add "system" ThemeCard to preferences.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, Lucide icons, Radix UI primitives

---

### Task 1: Update `useTheme` to support "system" mode

**Files:**
- Modify: `assets/js/hooks/use-theme.tsx`

**Step 1: Update types and state**

Replace the entire file with:

```tsx
import { createContext, useContext, useEffect, useLayoutEffect, useState } from "react";

type ThemeOption = "light" | "dark" | "system";
type ResolvedTheme = "light" | "dark";

interface ThemeContextValue {
  theme: ThemeOption;
  resolvedTheme: ResolvedTheme;
  setTheme: (theme: ThemeOption) => void;
}

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

function getSystemTheme(): ResolvedTheme {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function resolveTheme(theme: ThemeOption): ResolvedTheme {
  return theme === "system" ? getSystemTheme() : theme;
}

// Always start with "light" for SSR. Corrected after hydration via useLayoutEffect.
export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<ThemeOption>("light");
  const [resolvedTheme, setResolvedTheme] = useState<ResolvedTheme>("light");

  // Correct theme from localStorage after hydration, before browser paints.
  useLayoutEffect(() => {
    const stored = localStorage.getItem("theme");
    const validTheme: ThemeOption =
      stored === "dark" ? "dark" : stored === "system" ? "system" : "light";
    setThemeState(validTheme);
    setResolvedTheme(resolveTheme(validTheme));
  }, []);

  // Sync DOM class and localStorage whenever theme changes.
  useLayoutEffect(() => {
    const resolved = resolveTheme(theme);
    setResolvedTheme(resolved);
    const root = document.documentElement;
    root.classList.remove("light", "dark");
    root.classList.add(resolved);
    localStorage.setItem("theme", theme);
  }, [theme]);

  // Listen for OS theme changes when in "system" mode.
  useEffect(() => {
    if (theme !== "system") return;
    const mql = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => {
      const resolved = getSystemTheme();
      setResolvedTheme(resolved);
      const root = document.documentElement;
      root.classList.remove("light", "dark");
      root.classList.add(resolved);
    };
    mql.addEventListener("change", handler);
    return () => mql.removeEventListener("change", handler);
  }, [theme]);

  const setTheme = (newTheme: ThemeOption) => {
    setThemeState(newTheme);
  };

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme }}>
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

Key changes:
- `ThemeOption` = `"light" | "dark" | "system"` (what user selects)
- `ResolvedTheme` = `"light" | "dark"` (what the DOM gets)
- `resolvedTheme` exposed for components that need to know the actual visual theme
- `matchMedia` listener activates only when `theme === "system"`

**Step 2: Verify asset build**

Run: `cd assets && npx tsc --noEmit 2>&1 | head -20`
Expected: No errors related to use-theme.tsx (other pre-existing errors OK)

**Step 3: Commit**

```bash
git add assets/js/hooks/use-theme.tsx
git commit -m "feat: add system theme mode to useTheme hook"
```

---

### Task 2: Create ThemeToggle component

**Files:**
- Create: `assets/js/components/theme-toggle.tsx`

**Step 1: Create the 3-segment inline toggle**

```tsx
import { Sun, Moon, Monitor } from "lucide-react";
import { useTheme } from "@/hooks/use-theme";
import { cn } from "@/lib/utils";

type ThemeOption = "light" | "system" | "dark";

const options: { value: ThemeOption; icon: typeof Sun; label: string }[] = [
  { value: "light", icon: Sun, label: "Light" },
  { value: "system", icon: Monitor, label: "System" },
  { value: "dark", icon: Moon, label: "Dark" },
];

interface ThemeToggleProps {
  className?: string;
}

export function ThemeToggle({ className }: ThemeToggleProps) {
  const { theme, setTheme } = useTheme();

  return (
    <div
      className={cn(
        "inline-flex items-center rounded-full bg-surface-muted p-1",
        className
      )}
    >
      {options.map(({ value, icon: Icon, label }) => (
        <button
          key={value}
          type="button"
          onClick={() => setTheme(value)}
          className={cn(
            "flex items-center gap-1.5 rounded-full px-3 py-1.5 text-xs font-medium transition-colors",
            theme === value
              ? "bg-surface text-content shadow-sm"
              : "text-content-tertiary hover:text-content-secondary"
          )}
          aria-label={label}
        >
          <Icon className="size-3.5" />
          {label}
        </button>
      ))}
    </div>
  );
}
```

**Step 2: Verify asset build**

Run: `cd assets && npx tsc --noEmit 2>&1 | grep "theme-toggle" | head -5`
Expected: No errors

**Step 3: Commit**

```bash
git add assets/js/components/theme-toggle.tsx
git commit -m "feat: add ThemeToggle 3-segment component"
```

---

### Task 3: Redesign UserMenuContent for authenticated users

**Files:**
- Modify: `assets/js/navigation/user-menu-content.tsx`

**Step 1: Update imports and menu items**

Replace the entire file with:

```tsx
import { Link, router } from "@inertiajs/react";
import { ChevronRight, LogOut, User, Store, CreditCard } from "lucide-react";
import { useAuth } from "@/features/auth";
import { Avatar, AvatarImage, AvatarFallback } from "@/components/ui/avatar";
import { ThemeToggle } from "@/components/theme-toggle";

interface UserMenuContentProps {
  onNavigate?: () => void;
}

function getInitials(name: string | null): string {
  if (!name) return "?";
  const parts = name.trim().split(" ").filter(Boolean);
  if (parts.length === 0) return "?";
  return parts
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

const menuItems = [
  { label: "Account", href: "/settings/account", icon: User },
  { label: "Store", href: "/store", icon: Store },
  { label: "Payments", href: "/settings/payments", icon: CreditCard },
];

export function UserMenuContent({ onNavigate }: UserMenuContentProps) {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <div className="flex flex-col gap-6">
      {/* User details */}
      <div className="flex flex-col items-center gap-2">
        <Avatar className="size-20">
          {user.avatar_url && (
            <AvatarImage src={user.avatar_url} alt="" />
          )}
          <AvatarFallback className="bg-[#ffe7cc] text-2xl font-medium text-[#a34400]">
            {getInitials(user.full_name)}
          </AvatarFallback>
        </Avatar>
        <div className="flex flex-col items-center gap-1">
          <p className="text-xl text-content">{user.full_name}</p>
          <p className="text-sm text-content-tertiary">{user.email}</p>
        </div>
      </div>

      {/* Theme toggle */}
      <div className="flex justify-center">
        <ThemeToggle />
      </div>

      {/* Navigation links */}
      <div className="flex flex-col gap-4">
        {menuItems.map(({ label, href, icon: Icon }) => (
          <Link
            key={href}
            href={href}
            className="flex items-center justify-between text-base text-content transition-colors hover:text-content-secondary"
            onClick={onNavigate}
          >
            <span className="flex items-center gap-3">
              <Icon className="size-5 text-content-tertiary" />
              {label}
            </span>
            <ChevronRight className="size-5 text-content-tertiary" />
          </Link>
        ))}
      </div>

      {/* Log out */}
      <button
        type="button"
        className="flex w-full items-center justify-between text-base text-content-tertiary transition-colors hover:text-content-secondary"
        onClick={() => {
          onNavigate?.();
          router.post("/auth/logout");
        }}
      >
        <span className="flex items-center gap-3">
          <LogOut className="size-5" />
          Log out
        </span>
      </button>
    </div>
  );
}
```

Key changes from current:
- "Settings" link replaced with Account, Store, Payments (each with icon + chevron)
- Theme toggle added between user details and nav links
- Gap reduced from `gap-10` to `gap-6` to accommodate more items
- Each menu item shows icon on left, chevron on right
- Log out has icon on left, no chevron

**Step 2: Verify asset build**

Run: `cd assets && npx tsc --noEmit 2>&1 | grep "user-menu-content" | head -5`
Expected: No errors

**Step 3: Commit**

```bash
git add assets/js/navigation/user-menu-content.tsx
git commit -m "feat: redesign UserMenuContent with theme toggle and new nav items"
```

---

### Task 4: Add theme toggle for non-auth users

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx`

**Step 1: Add ThemeToggleButton for desktop non-auth**

Add a small icon-only theme button that cycles through light → system → dark for non-auth desktop users. Import the `ThemeToggle` and add it.

At the top, add import:
```tsx
import { ThemeToggle } from '@/components/theme-toggle';
```

In the desktop right section, inside the non-auth `<>` fragment (after "Sign Up" button, before `</>`), add the theme toggle. Replace the entire non-auth block:

```tsx
<>
  <ThemeToggle />
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
```

**Step 2: Add theme toggle in mobile hamburger for non-auth**

In the mobile Sheet content, inside the non-auth block (the `<div className="flex flex-col gap-2">` that has Sign In/Sign Up), add the theme toggle above the buttons:

```tsx
<div className="flex flex-col gap-4">
  <div className="flex justify-center">
    <ThemeToggle />
  </div>
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
</div>
```

**Step 3: Verify asset build**

Run: `cd assets && npx tsc --noEmit 2>&1 | grep "main-nav" | head -5`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: add theme toggle for non-authenticated users"
```

---

### Task 5: Add "system" option to Preferences page

**Files:**
- Modify: `assets/js/features/settings/components/theme-card.tsx`
- Modify: `assets/js/features/settings/components/preferences-form.tsx`

**Step 1: Update ThemeCard to support "system" variant**

Replace `theme-card.tsx` with:

```tsx
import { cn } from "@/lib/utils";

interface ThemeCardProps {
  variant: "light" | "dark" | "system";
  selected: boolean;
  onClick: () => void;
}

export function ThemeCard({ variant, selected, onClick }: ThemeCardProps) {
  // System card shows a split light/dark preview
  const isLight = variant === "light" || variant === "system";
  const isSystem = variant === "system";

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
            isSystem
              ? "bg-gradient-to-r from-neutral-07 to-neutral-01"
              : isLight
                ? "bg-neutral-07"
                : "bg-neutral-01"
          )}
        >
          <div
            className={cn(
              "flex flex-col gap-2 rounded-md p-2 shadow-sm",
              isSystem
                ? "bg-gradient-to-r from-white to-neutral-03"
                : isLight
                  ? "bg-white"
                  : "bg-neutral-03"
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
                isSystem
                  ? "bg-gradient-to-r from-white to-neutral-03"
                  : isLight
                    ? "bg-white"
                    : "bg-neutral-03"
              )}
            >
              <div className={cn("size-4 rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
              <div className={cn("h-2 w-[100px] rounded-full", isLight ? "bg-neutral-07" : "bg-neutral-04")} />
            </div>
          ))}
        </div>
      </div>
      <span className="text-sm text-content-secondary">
        {variant === "light" ? "Light" : variant === "dark" ? "Dark" : "System"}
      </span>
    </button>
  );
}
```

**Step 2: Add third ThemeCard to PreferencesForm**

In `preferences-form.tsx`, add the system theme card. Replace the theme card row:

```tsx
<div className="flex gap-4 lg:gap-8">
  <ThemeCard variant="light" selected={selectedTheme === "light"} onClick={() => setSelectedTheme("light")} />
  <ThemeCard variant="system" selected={selectedTheme === "system"} onClick={() => setSelectedTheme("system")} />
  <ThemeCard variant="dark" selected={selectedTheme === "dark"} onClick={() => setSelectedTheme("dark")} />
</div>
```

Also update the `selectedTheme` state type — change the `useState` call:

```tsx
const [selectedTheme, setSelectedTheme] = useState<"light" | "dark" | "system">(theme);
```

**Step 3: Verify asset build**

Run: `cd assets && npx tsc --noEmit 2>&1 | grep -E "(theme-card|preferences-form)" | head -5`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/settings/components/theme-card.tsx assets/js/features/settings/components/preferences-form.tsx
git commit -m "feat: add system theme option to preferences page"
```

---

### Task 6: Final verification

**Step 1: Run full test suite**

Run: `mix test`
Expected: 213 tests, 35 failures (same as baseline — all pre-existing SSR failures)

**Step 2: Build assets**

Run: `mix assets.build`
Expected: Builds successfully

**Step 3: Visual QA**

Start server and verify:
- `localhost:<port>` — non-auth users see theme toggle next to Sign In/Sign Up on desktop
- Mobile hamburger menu shows theme toggle for non-auth users
- Log in → profile popover shows theme toggle + Account/Store/Payments/Log out
- Toggle to "system" → theme follows OS preference
- Toggle to "dark" → dark mode
- Toggle to "light" → light mode
- Navigate to `/settings/preferences` → 3 theme cards (Light, System, Dark)
- Select System → save → theme follows OS
