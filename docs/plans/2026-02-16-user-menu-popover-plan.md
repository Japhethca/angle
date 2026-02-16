# User Menu Popover Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the plain user icon link in the navbar with a hover popover showing user info, Settings link, and Log out action — on both desktop and mobile.

**Architecture:** Extract shared user menu content into `UserMenuContent`, wrap it in a hover-controlled Popover for desktop (`UserMenuPopover`), and render it directly in the mobile Sheet. Uses existing shadcn Popover and Avatar components.

**Tech Stack:** React, shadcn/ui (Popover, Avatar), Radix primitives, Inertia.js router, Lucide icons, Tailwind CSS

**Design doc:** `docs/plans/2026-02-16-user-menu-popover-design.md`
**Figma:** `https://www.figma.com/design/jk9qoWNcSpgUa8lsj7uXa9/Angle?node-id=812-10474&m=dev`

---

### Task 1: Create `UserMenuContent` component

**Files:**
- Create: `assets/js/navigation/user-menu-content.tsx`

**Step 1: Create the shared content component**

This component renders the user avatar, name, email, Settings link, and Log out button. It's used by both the desktop popover and mobile sheet.

```tsx
import { Link, router } from "@inertiajs/react";
import { ChevronRight, LogOut } from "lucide-react";
import { useAuth } from "@/features/auth";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";

interface UserMenuContentProps {
  onNavigate?: () => void;
}

function getInitials(name: string | null): string {
  if (!name) return "?";
  return name
    .split(" ")
    .map((n) => n[0])
    .join("")
    .toUpperCase()
    .slice(0, 2);
}

export function UserMenuContent({ onNavigate }: UserMenuContentProps) {
  const { user } = useAuth();
  if (!user) return null;

  return (
    <div className="flex flex-col gap-10">
      {/* User details */}
      <div className="flex flex-col items-center gap-2">
        <Avatar className="size-10">
          <AvatarFallback className="bg-[#ffe7cc] text-sm font-medium text-[#a34400]">
            {getInitials(user.full_name)}
          </AvatarFallback>
        </Avatar>
        <div className="flex flex-col items-center gap-1">
          <p className="text-xl text-content">{user.full_name}</p>
          <p className="text-sm text-content-tertiary">{user.email}</p>
        </div>
      </div>

      {/* Actions */}
      <div className="flex flex-col gap-4">
        <Link
          href="/settings/account"
          className="flex items-center justify-between text-base text-content transition-colors hover:text-content-secondary"
          onClick={onNavigate}
        >
          Settings
          <ChevronRight className="size-5" />
        </Link>
        <button
          className="flex items-center justify-between text-base text-content-tertiary transition-colors hover:text-content-secondary"
          onClick={() => {
            onNavigate?.();
            router.post("/auth/logout");
          }}
        >
          Log out
          <LogOut className="size-5" />
        </button>
      </div>
    </div>
  );
}
```

**Step 2: Verify no TypeScript errors**

Run: `npx tsc --noEmit --project assets/tsconfig.json 2>&1 | grep user-menu-content`
Expected: No output (no errors in our new file)

**Step 3: Commit**

```
git add assets/js/navigation/user-menu-content.tsx
git commit -m "feat: add UserMenuContent component for user menu"
```

---

### Task 2: Create `UserMenuPopover` component

**Files:**
- Create: `assets/js/navigation/user-menu-popover.tsx`

**Step 1: Create the desktop hover popover wrapper**

```tsx
import { useRef, useState } from "react";
import { User } from "lucide-react";
import { Popover, PopoverTrigger, PopoverContent } from "@/components/ui/popover";
import { UserMenuContent } from "./user-menu-content";

const CLOSE_DELAY = 150;

export function UserMenuPopover() {
  const [open, setOpen] = useState(false);
  const closeTimeout = useRef<ReturnType<typeof setTimeout> | null>(null);

  function handleOpen() {
    if (closeTimeout.current) {
      clearTimeout(closeTimeout.current);
      closeTimeout.current = null;
    }
    setOpen(true);
  }

  function handleClose() {
    closeTimeout.current = setTimeout(() => setOpen(false), CLOSE_DELAY);
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <div onMouseEnter={handleOpen} onMouseLeave={handleClose}>
        <PopoverTrigger asChild>
          <button className="flex size-10 items-center justify-center rounded-lg text-content-secondary transition-colors hover:bg-surface-muted">
            <User className="size-5" />
          </button>
        </PopoverTrigger>
      </div>
      <PopoverContent
        align="end"
        sideOffset={8}
        className="w-[304px] rounded-xl border-0 px-6 pb-10 pt-6 shadow-[0px_1px_2px_0px_rgba(0,0,0,0.08)]"
        onMouseEnter={handleOpen}
        onMouseLeave={handleClose}
      >
        <UserMenuContent onNavigate={() => setOpen(false)} />
      </PopoverContent>
    </Popover>
  );
}
```

**Step 2: Verify no TypeScript errors**

Run: `npx tsc --noEmit --project assets/tsconfig.json 2>&1 | grep user-menu-popover`
Expected: No output (no errors in our new file)

**Step 3: Commit**

```
git add assets/js/navigation/user-menu-popover.tsx
git commit -m "feat: add UserMenuPopover with hover-controlled popover"
```

---

### Task 3: Wire up desktop popover in `MainNav`

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx:1-6` (imports)
- Modify: `assets/js/navigation/main-nav.tsx:118-123` (desktop user icon)

**Step 1: Update imports**

Add `UserMenuPopover` import. Remove `User` from lucide-react imports (no longer used directly in this file).

Change line 3 from:
```tsx
import { Search, Bell, Menu, User } from 'lucide-react';
```
to:
```tsx
import { Search, Bell, Menu } from 'lucide-react';
```

Add after the CategoryMegaMenu import (line 14):
```tsx
import { UserMenuPopover } from './user-menu-popover';
```

**Step 2: Replace desktop user icon link with popover**

Replace lines 118-123:
```tsx
              <Link
                href="/settings/account"
                className="flex size-10 items-center justify-center rounded-lg text-content-secondary transition-colors hover:bg-surface-muted"
              >
                <User className="size-5" />
              </Link>
```

With:
```tsx
              <UserMenuPopover />
```

**Step 3: Verify no TypeScript errors**

Run: `npx tsc --noEmit --project assets/tsconfig.json 2>&1 | grep main-nav`
Expected: No output

**Step 4: Commit**

```
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: replace desktop user icon with UserMenuPopover"
```

---

### Task 4: Wire up mobile user menu in `MainNav` Sheet

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx:1-15` (imports)
- Modify: `assets/js/navigation/main-nav.tsx:165-172` (mobile profile link)

**Step 1: Add UserMenuContent import**

Add after the UserMenuPopover import:
```tsx
import { UserMenuContent } from './user-menu-content';
```

**Step 2: Replace mobile "Profile" link with UserMenuContent**

Replace lines 165-172:
```tsx
                {authenticated ? (
                  <Link
                    href="/settings/account"
                    className="text-sm font-medium text-content"
                    onClick={() => setMobileOpen(false)}
                  >
                    Profile
                  </Link>
                ) : (
```

With:
```tsx
                {authenticated ? (
                  <UserMenuContent onNavigate={() => setMobileOpen(false)} />
                ) : (
```

**Step 3: Verify no TypeScript errors**

Run: `npx tsc --noEmit --project assets/tsconfig.json 2>&1 | grep main-nav`
Expected: No output

**Step 4: Commit**

```
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: add user menu content to mobile nav sheet"
```

---

### Task 5: Visual verification against Figma

**Step 1: Take browser screenshot of desktop popover**

Navigate to `http://localhost:4111` while logged in. Hover over the user icon in the top-right of the navbar. Take a screenshot.

**Step 2: Compare with Figma design**

Figma node: `812-10474` (file key: `jk9qoWNcSpgUa8lsj7uXa9`)

Check:
- Popover width (304px), border-radius (12px), shadow
- Avatar with initials, warm background
- Name size (20px/text-xl), email size (14px/text-sm)
- Settings row with right-arrow, Log out row with logout icon
- Spacing between sections (40px gap)

**Step 3: Fix any discrepancies found**

**Step 4: Take mobile screenshot**

Resize browser to mobile width, open hamburger menu, verify user menu content appears.

**Step 5: Final commit if fixes were needed**

```
git add -A
git commit -m "fix: adjust user menu popover styling to match Figma"
```
