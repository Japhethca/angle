# Nav Menu & Theme Toggle Design

## Goal

Redesign the profile popover menu for authenticated users and add a dark/light/system theme toggle accessible from the navbar for all users (auth and non-auth). Also add the "system" theme option to Settings > Preferences.

## Current State

- **Auth users:** Profile popover shows avatar, name, email, "Settings" link, "Log out" button
- **Non-auth users:** "Sign In" and "Sign Up" buttons, no theme toggle
- **Theme system:** Only supports `"light"` | `"dark"`, stored in localStorage, no "system" option
- **Preferences page:** Shows 2 ThemeCard components (light/dark), no system option

## Changes

### 1. Update `useTheme` to support "system" mode

Add `"system"` as a third theme option. When active, use `window.matchMedia("(prefers-color-scheme: dark)")` to determine the resolved theme, and listen for OS changes.

### 2. Redesign `UserMenuContent` for authenticated users

Replace "Settings" link with:
- **Theme toggle** — inline 3-segment toggle (light / system / dark) with icons
- **Account** → `/settings/account`
- **Store** → `/store`
- **Payments** → `/settings/payments`
- **Log out** (stays)

### 3. Add theme toggle for non-auth users

Add a sun/moon icon button next to Sign In / Sign Up on desktop. On mobile, add the theme toggle inside the hamburger sheet.

### 4. Add "system" option to Preferences page

Add a third ThemeCard for "system" alongside light and dark.

## Files to modify

1. `assets/js/hooks/use-theme.tsx` — add "system" mode with matchMedia listener
2. `assets/js/navigation/user-menu-content.tsx` — redesign menu items + inline theme toggle
3. `assets/js/navigation/main-nav.tsx` — add theme toggle for non-auth users
4. `assets/js/features/settings/components/theme-card.tsx` — support "system" variant
5. `assets/js/features/settings/components/preferences-form.tsx` — add third theme card
