# Legal Settings Page Design

## Overview

Add a Legal section to the Settings page with collapsible accordion items for Terms of Service and Privacy Policy, plus standalone full-text pages at `/terms` and `/privacy`.

## Figma References

- Desktop: `454-6223`
- Mobile: `636-6714`

## Approach

Static React pages with hardcoded placeholder legal text. No database or Ash resources needed.

## Legal Settings Page (`/settings/legal`)

Uses existing `SettingsLayout` with title "Legal".

Content is two accordion items (shadcn `Accordion`, `type="single"`, `collapsible`):

| Section | Title | Subtitle | Expanded Content |
|---------|-------|----------|-----------------|
| Terms of Service | "Terms of Service" | "Understand the rules for using Angle." | Brief summary + link to `/terms` |
| Privacy Service | "Privacy Service" | "See how we collect, use, and protect your data." | Brief summary + link to `/privacy` |

## Standalone Pages

- **`/terms`** — Full Terms of Service with placeholder text, simple static layout (no settings sidebar)
- **`/privacy`** — Full Privacy Policy with placeholder text, same layout

## Files

### New

- `assets/js/pages/settings/legal.tsx` — Legal settings page
- `assets/js/features/settings/components/legal-content.tsx` — Accordion content component
- `assets/js/pages/terms.tsx` — Full terms page
- `assets/js/pages/privacy.tsx` — Full privacy page

### Modified

- `lib/angle_web/controllers/settings_controller.ex` — Add `legal/2` action
- `lib/angle_web/router.ex` — Add `/settings/legal`, `/terms`, `/privacy` routes
- `assets/js/features/settings/components/settings-layout.tsx` — Enable Legal menu item
- `assets/js/pages/settings/index.tsx` — Enable Legal menu item with href
- `assets/js/features/settings/index.ts` — Export `LegalContent`

## Backend

The legal settings page needs no user data — controller just calls `render_inertia("settings/legal")`.

For `/terms` and `/privacy`, a simple controller renders the Inertia pages with no props.
