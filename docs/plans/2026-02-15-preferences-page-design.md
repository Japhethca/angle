# Preferences Settings Page Design

**Date:** 2026-02-15
**Status:** Approved

## Figma References

- Desktop: `node-id=454-5962` ([link](https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=454-5962&m=dev))
- Mobile: `node-id=636-6571` ([link](https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=636-6571&m=dev))

## Overview

Add a Preferences settings page with Language selection and Theme (Light/Dark) switching. Theme is fully functional — toggling dark mode applies across the entire app via Tailwind's class-based dark mode strategy.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Persistence | Frontend only (localStorage) | No backend changes needed. |
| Theme implementation | Functional dark mode | Tailwind `dark:` class strategy. CSS variables already defined in app.css. |
| Language | Store preference only | Dropdown saves to localStorage. No i18n framework yet. |
| Dark mode scope | Full app | All pages and custom components get `dark:` variants. |

## Architecture

### Theme Provider

- **Location:** `assets/js/hooks/use-theme.tsx`
- React context providing `{ theme, setTheme }` via `useTheme()` hook
- Reads/writes `localStorage` key `"theme"` (values: `"light"` | `"dark"`)
- Defaults to `"light"` if nothing stored
- Toggles the `dark` class on `document.documentElement`
- Wraps the app in `app.tsx` and `ssr.tsx` (SSR defaults to light)

### Preferences Page

- **Route:** `GET /settings/preferences`
- **Controller:** `SettingsController.preferences/2` — passes `user` data via Inertia props
- **Page:** `assets/js/pages/settings/preferences.tsx`
- Renders inside `SettingsLayout` (same pattern as account/store/security pages)

### Page Content

1. **Language dropdown** — `<Select>` with "English" as the only option. Saves to `localStorage` key `"language"`.
2. **Theme selector** — Two clickable skeleton cards (Light/Dark) matching Figma wireframes. Selected card: `border-neutral-01` (2px). Unselected: `border-neutral-07` (2px).
3. **"Save Changes" button** — Applies both selections. Orange primary button. Full-width on mobile.

### New Components

- `assets/js/features/settings/components/preferences-form.tsx` — Language select + theme cards + save button
- `assets/js/features/settings/components/theme-card.tsx` — Skeleton preview card (light/dark variants)

### Sidebar Update

Enable the "Preferences" link in `settingsMenuItems` in `settings-layout.tsx`:
```
{ label: "Preferences", href: "/settings/preferences", icon: SlidersHorizontal }
```

### Dark Mode — Full App Coverage

The app already has dark mode CSS infrastructure in place:
- `@custom-variant dark (.dark&, .dark &)` in app.css (line 62)
- `.dark` CSS variable overrides for all shadcn tokens (app.css lines 107-139)
- `body` uses `var(--background)` / `var(--foreground)` which auto-switch
- All shadcn/ui components use CSS variables and auto-switch

What needs `dark:` variants: every custom component using hardcoded Tailwind color classes.

**Dark mode color mapping (neutral scale):**

| Light | Dark |
|-------|------|
| `bg-white` | `dark:bg-neutral-01` |
| `bg-neutral-08` | `dark:bg-neutral-03` |
| `bg-neutral-09` | `dark:bg-neutral-03` |
| `text-neutral-01` | `dark:text-neutral-10` |
| `text-neutral-02` | `dark:text-neutral-09` |
| `text-neutral-03` | `dark:text-neutral-06` |
| `text-neutral-04` | `dark:text-neutral-05` |
| `text-neutral-05` | `dark:text-neutral-05` (stays) |
| `border-neutral-06` | `dark:border-neutral-04` |
| `border-neutral-07` | `dark:border-neutral-03` |
| `hover:bg-neutral-08` | `dark:hover:bg-neutral-03` |
| `hover:text-neutral-01` | `dark:hover:text-neutral-10` |
| `bg-primary-600/10` | stays (orange tint works on dark) |

**Files requiring changes (~300+ occurrences across 47 files):**

**Navigation (3 files, ~20 occurrences):**
- `main-nav.tsx` — nav bg, link colors, search input, button hover states, mobile sheet
- `bottom-nav.tsx` — nav bg, active/inactive icon colors
- `category-mega-menu.tsx` — link and subcategory text colors

**Layouts (2 files, ~10 occurrences):**
- `footer.tsx` — already dark (`bg-[#060818]`), minor text adjustments
- `auth-layout.tsx` — badge styling

**Pages (12 files, ~95 occurrences):**
- `home.tsx`, `dashboard.tsx`, `bids.tsx`, `watchlist.tsx`, `profile.tsx` — headings/subheadings
- `settings/index.tsx` — mobile menu card backgrounds, text colors
- `categories/index.tsx`, `categories/show.tsx` — card bgs, filter buttons, empty states
- `items/new.tsx`, `items/show.tsx` — breadcrumbs, metadata, header
- `store/show.tsx` — store profile, tabs, reviews section
- `admin/users.tsx` — table styling, badges

**Features (30 files, ~175 occurrences):**
- `home/components/*` — section backgrounds, empty states, carousel
- `items/components/*` — item cards, image gallery, seller card, tabs
- `bidding/components/*` — bid section, confirm dialog
- `settings/components/*` — forms, profile sections, layout
- `auth/components/*` — login/register forms, alert backgrounds

### Not In Scope

- Actual i18n/translation framework
- System theme preference detection (`prefers-color-scheme`)
- Backend persistence of preferences
