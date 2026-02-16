# Support Settings Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Support settings page with Help Center accordion, Contact Support info, and Report An Issue link.

**Architecture:** Static content page following the Legal page pattern — no backend data, controller renders Inertia page, React component handles all UI.

**Tech Stack:** Phoenix controller, Inertia.js, React, shadcn/ui Accordion, Lucide icons, Tailwind CSS

---

### Task 1: Add controller action and route

**Files:**
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Modify: `lib/angle_web/router.ex`

**Step 1: Add support action to controller**

Add after the `legal` action in `lib/angle_web/controllers/settings_controller.ex`:

```elixir
def support(conn, _params) do
  conn
  |> render_inertia("settings/support")
end
```

**Step 2: Add route**

In `lib/angle_web/router.ex`, inside the protected settings scope (after `get "/settings/legal"`), add:

```elixir
get "/settings/support", SettingsController, :support
```

**Step 3: Verify Elixir compiles**

Run: `mix compile`
Expected: Compiles successfully

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/settings_controller.ex lib/angle_web/router.ex
git commit -m "feat: add support settings controller action and route"
```

---

### Task 2: Create SupportContent component

**Files:**
- Create: `assets/js/features/settings/components/support-content.tsx`

**Step 1: Create the component**

Create `assets/js/features/settings/components/support-content.tsx` with:

- **Help Center section:** Uses `Accordion` from `@/components/ui/accordion` with collapsible FAQ items. Title "Help Center" with description "Find answers to common questions and guides." The accordion has placeholder FAQ items.
- **Contact Support section:** Title "Contact Support", displays:
  - Email: `support@angle.com` as a `mailto:` link
  - Phone: `+23481796988`, `+2348177417875`
  - Address: `1A, Alana drive, Lagos`
  - Each item has a Lucide icon (Mail, Phone, MapPin)
- **Report An Issue section:** An external link styled in orange/primary text with `ExternalLink` icon from Lucide. Opens in new tab.

Follow the same styling conventions as `LegalContent`:
- `text-sm font-semibold text-content` for section titles
- `text-sm text-content-tertiary` for descriptions
- `text-primary-600` for links
- Sections separated with spacing

**Step 2: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 3: Commit**

```bash
git add assets/js/features/settings/components/support-content.tsx
git commit -m "feat: add SupportContent component with help center, contact, and report sections"
```

---

### Task 3: Create Support page and update barrel export

**Files:**
- Create: `assets/js/pages/settings/support.tsx`
- Modify: `assets/js/features/settings/index.ts`

**Step 1: Create the page**

Create `assets/js/pages/settings/support.tsx` following the Legal page pattern:

```tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, SupportContent } from "@/features/settings";

export default function SettingsSupport() {
  return (
    <>
      <Head title="Support" />
      <SettingsLayout title="Support">
        <SupportContent />
      </SettingsLayout>
    </>
  );
}
```

**Step 2: Add barrel export**

In `assets/js/features/settings/index.ts`, add:

```ts
export { SupportContent } from "./components/support-content";
```

**Step 3: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/pages/settings/support.tsx assets/js/features/settings/index.ts
git commit -m "feat: add Support settings page with barrel export"
```

---

### Task 4: Enable Support in sidebar and mobile navigation

**Files:**
- Modify: `assets/js/features/settings/components/settings-layout.tsx`
- Modify: `assets/js/pages/settings/index.tsx`

**Step 1: Enable desktop sidebar item**

In `assets/js/features/settings/components/settings-layout.tsx`, change:

```ts
{ label: "Support", href: "#", disabled: true, icon: HelpCircle },
```

to:

```ts
{ label: "Support", href: "/settings/support", icon: HelpCircle },
```

**Step 2: Enable mobile nav item**

In `assets/js/pages/settings/index.tsx`, change:

```ts
{ label: "Support", icon: HelpCircle, disabled: true },
```

to:

```ts
{ label: "Support", icon: HelpCircle, href: "/settings/support" },
```

**Step 3: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/settings/components/settings-layout.tsx assets/js/pages/settings/index.tsx
git commit -m "feat: enable Support nav item in settings sidebar and mobile menu"
```

---

### Task 5: Add controller tests

**Files:**
- Create: `test/angle_web/controllers/settings_support_test.exs`

**Step 1: Write tests**

Create `test/angle_web/controllers/settings_support_test.exs`:

```elixir
defmodule AngleWeb.SettingsSupportTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /settings/support" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/support")

      assert html_response(conn, 200) =~ "settings/support"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/support")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
```

**Step 2: Run tests**

Run: `mix test test/angle_web/controllers/settings_support_test.exs`
Expected: 2 tests, 0 failures

**Step 3: Commit**

```bash
git add test/angle_web/controllers/settings_support_test.exs
git commit -m "test: add controller tests for support settings page"
```

---

### Task 6: Verify everything works

**Step 1: Run full test suite**

Run: `mix test`
Expected: All tests pass

**Step 2: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 3: Browser verification**

Start dev server and verify:
- Navigate to `/settings/support` — page renders with all 3 sections
- Help Center accordion expands/collapses
- Contact info displays correctly
- Report An Issue link works
- Desktop sidebar shows Support as active
- Mobile settings index shows Support link (not disabled)
