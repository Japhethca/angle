# User Menu Popover Design

## Context

The navbar's settings/account link is currently a plain `User` icon that navigates to `/settings/account`. The Figma design (node `812-10474`) shows a hover popover with user info, a Settings link, and a Log out action. On mobile, the same content should appear in the Sheet menu.

**Figma reference:** `https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=812-10474&m=dev`

## Design

### Approach

Use the existing shadcn Popover component with manual hover state management (open on mouseenter, close on mouseleave with 150ms delay). Extract shared content into a reusable component used by both desktop popover and mobile sheet.

### Components

#### `UserMenuContent`
**File:** `assets/js/navigation/user-menu-content.tsx`

Shared content rendered in both desktop popover and mobile sheet:

1. **Avatar + user details** (centered, stacked)
   - `Avatar` (40px) with `AvatarFallback` showing user initials, warm background (`bg-[#ffe7cc]`, text `text-[#a34400]`)
   - User's full name — `text-xl text-content`
   - User's email — `text-sm text-content-tertiary`
2. **Settings row** — "Settings" text + `ChevronRight` icon, full-width, links to `/settings/account`
3. **Log out row** — "Log out" in gray + `LogOut` icon, calls `router.post('/auth/logout')`

Props:
- `onNavigate?: () => void` — called before navigating (used by mobile to close the Sheet)

Gap between user details and CTA section: `gap-10` (40px, matching Figma).

#### `UserMenuPopover`
**File:** `assets/js/navigation/user-menu-popover.tsx`

Desktop-only wrapper:

- **Trigger:** The existing `User` icon button (same 40px rounded style)
- **Popover content:** `w-[304px]`, `rounded-xl`, white bg, shadow `shadow-[0px_1px_2px_0px_rgba(0,0,0,0.08)]`, padding `pt-6 pb-10 px-6`, renders `UserMenuContent`
- **Hover logic:** `onMouseEnter`/`onMouseLeave` on wrapper div controlling Popover `open` state with 150ms close delay via `useRef` timeout

### Changes to `MainNav`

**Desktop (line 118-123):** Replace `<Link href="/settings/account">` with `<UserMenuPopover />`

**Mobile (lines 165-172):** Replace the "Profile" link with `<UserMenuContent onNavigate={() => setMobileOpen(false)} />`

### Visual spec (from Figma node `814:11177`)

- Popover width: `304px`
- Border radius: `12px` (`rounded-xl`)
- Shadow: `0px 1px 2px 0px rgba(0,0,0,0.08)`
- Avatar: 40px, rounded-full, warm fallback bg
- Name: 20px, `#0a0a0a`
- Email: 14px, `#737373`
- Settings row: 16px, `#0a0a0a`, with right-arrow icon
- Log out row: 16px, `#737373`, with logout icon
- Padding: `pt-6 pb-10 px-6`
- Gap between sections: `40px`

### Not in scope

- Avatar image upload (no image URL in User model yet — fallback initials only)
- Notification bell popover (separate feature)
