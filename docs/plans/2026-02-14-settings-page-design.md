# Settings Page — Account Section Design

## Goal

Build a settings page accessible from the profile icon for logged-in users. The initial scope covers the Account section with profile editing. Other settings sections (Store, Security, Payments, Notifications, Preferences, Legal, Support) appear in the sidebar/menu but link to placeholder pages.

## Figma References

- Desktop Account: node-id=352-14681
- Mobile Settings menu: node-id=352-14725
- Mobile Account (variant A): node-id=633-5727
- Mobile Account (variant B): node-id=678-7411

## Routing

| Route | Desktop Behavior | Mobile Behavior |
|-------|-----------------|-----------------|
| `/settings` | Redirects to `/settings/account` | Shows settings menu (profile card + menu list) |
| `/settings/account` | Settings layout with sidebar + Account form | Back arrow + Account form |

Profile icon in nav links to `/settings/account` (desktop) and `/settings` (mobile via bottom nav).

## Page Structure

### Desktop — Settings Layout

Left sidebar navigation:
- Account (active by default)
- Store, Security, Payments, Notifications, Preferences, Legal, Support (placeholder)
- "Log Out" at bottom

Right content area:
- Breadcrumb: "Settings > {section}"
- Section content

### Mobile — Settings Menu (`/settings`)

- "Settings" title
- Profile card: avatar + full name with chevron + email (links to `/settings/account`)
- Menu items: Security, Payments, Notifications, Preferences, Legal, Support
- "Log Out" at bottom

### Account Page Content (both desktop and mobile)

1. **Profile Image** — avatar placeholder with Change/Delete buttons (UI only, no actual upload)
2. **Form Fields**:
   - Name (`full_name`) — text input
   - Email (`email`) — read-only, displayed but not editable
   - Phone number (`phone_number`) — text input with static "234" country code prefix
   - Address (`location`) — text input
3. **Verification** — static placeholder showing uploaded document UI
4. **Quick Sign In** — static placeholder showing Google connected state
5. **Save Changes** button

## Backend

### User Resource Changes

New `:update_profile` action on `Angle.Accounts.User`:
- Accepts: `full_name`, `phone_number`, `location`
- Does NOT accept `email` (email changes are sensitive, handled separately)
- Authorization: user can only update themselves (existing policy covers this)

### Typed Mutation

Add typed mutation for `update_profile` to generate `updateProfile` RPC function in `ash_rpc.ts`.

### Controller

`SettingsController`:
- `index/2` — desktop: redirects to `/settings/account`; mobile: renders `settings/index` with user data
- `account/2` — renders `settings/account` with current user profile data

User data loaded from `conn.assigns.current_user` and passed as Inertia props.

## Frontend

### Components

- `SettingsLayout` — shared layout with sidebar (desktop) / back button (mobile)
- `AccountForm` — react-hook-form + Zod, submits via `useAshMutation`
- `ProfileImageSection` — avatar + Change/Delete buttons (cosmetic only)
- `VerificationSection` — static placeholder
- `QuickSignInSection` — static placeholder

### Form Behavior

- Pre-populated from Inertia props (current user data)
- Zod validation: name required, phone optional, address optional
- Submit via `useAshMutation` calling generated `updateProfile` RPC
- Email displayed as read-only
- Success: toast notification + Inertia page refresh to update auth context
- Phone field: visual "234" prefix (decorative), value stored as plain string

## Scope Exclusions

- Profile image upload (UI only, no backend storage)
- Verification document upload
- Google OAuth connect/disconnect
- Other settings sections (Store, Security, Payments, etc.) — placeholder only
- Email change functionality
