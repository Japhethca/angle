# Support Settings Page Design

## Overview

A static settings page with three sections: Help Center (collapsible FAQ accordion), Contact Support (email, phone, address), and Report An Issue (external link). Follows the same pattern as the Legal settings page.

## Sections

### Help Center
- Collapsible accordion section
- Description: "Find answers to common questions and guides."
- Contains FAQ items (expandable)
- Uses existing shadcn Accordion component (same as Legal page)

### Contact Support
- Static display of contact information:
  - Email: support@angle.com (mailto link)
  - Phone: +23481796988, +2348177417875
  - Address: 1A, Alana drive, Lagos

### Report An Issue
- External link styled in orange/primary color
- Opens in new tab (external arrow icon)
- Links to a support/issue reporting URL

## Architecture

- No backend data needed (all static content)
- Controller action renders Inertia page with no props
- Follows Legal page pattern exactly:
  - `SupportContent` component in `features/settings/components/`
  - Page wraps `SettingsLayout` + `SupportContent`
  - Barrel export from `features/settings/index.ts`

## Files

- **Create:** `assets/js/features/settings/components/support-content.tsx`
- **Create:** `assets/js/pages/settings/support.tsx`
- **Create:** `test/angle_web/controllers/settings_support_test.exs`
- **Modify:** `lib/angle_web/controllers/settings_controller.ex` (add `support` action)
- **Modify:** `lib/angle_web/router.ex` (add route)
- **Modify:** `assets/js/features/settings/components/settings-layout.tsx` (enable nav item)
- **Modify:** `assets/js/pages/settings/index.tsx` (enable mobile nav item)
- **Modify:** `assets/js/features/settings/index.ts` (add barrel export)
