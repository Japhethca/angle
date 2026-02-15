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
| Theme implementation | Functional dark mode | Semantic CSS variable tokens that auto-switch between light/dark. |
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

### Dark Mode — Semantic Token Approach

Instead of adding `dark:` prefixes to every hardcoded color class, we use **semantic CSS variable tokens** that auto-switch between light and dark values. This ensures new components automatically support dark mode without manual `dark:` classes.

**How it works:**
1. Define CSS variables in `:root` (light) and `.dark` (dark) blocks in `app.css`
2. Register them as Tailwind theme colors so they're available as `bg-surface`, `text-content`, etc.
3. Replace all hardcoded neutral color classes with semantic equivalents
4. shadcn/ui components already use CSS variables and auto-switch — no changes needed

**Key token groups:**

| Category | Examples | Replaces |
|----------|----------|----------|
| Surface (backgrounds) | `bg-surface`, `bg-surface-secondary`, `bg-surface-muted` | `bg-white`, `bg-neutral-09`, `bg-neutral-08` |
| Content (text) | `text-content`, `text-content-secondary`, `text-content-tertiary` | `text-neutral-01`, `text-neutral-03`, `text-neutral-04` |
| Border | `border-subtle`, `border-strong` | `border-neutral-07`, `border-neutral-06` |
| Feedback | `text-feedback-success`, `bg-feedback-error-muted` | `text-green-700`, `bg-red-50` |

**Files requiring migration (~300+ occurrences across 47 files):**
- Navigation (3 files) — nav backgrounds, link colors, hover states
- Layouts (2 files) — footer, auth layout
- Pages (12 files) — headings, cards, breadcrumbs, metadata
- Feature components (30 files) — item cards, forms, bid sections, settings

Full token definitions and migration details in the implementation plan (`2026-02-15-preferences-page-plan.md`).

### Not In Scope

- Actual i18n/translation framework
- System theme preference detection (`prefers-color-scheme`)
- Backend persistence of preferences
