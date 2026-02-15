# Notification Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Notifications settings page where users can toggle 9 notification preferences across three channels (Push, Email, SMS), stored as an embedded Ash resource on the User.

**Architecture:** Embedded `Angle.Accounts.NotificationPreferences` resource with 9 boolean attributes (all default `true`), stored as a JSONB column on User. A single `update_notification_preferences` action on User accepts the full preferences map and is exposed via AshTypescript RPC. The controller loads the user with preferences and renders an Inertia page inside `SettingsLayout`.

**Tech Stack:** Ash Framework (embedded resource), Phoenix controller + Inertia.js, React 19, shadcn/ui Switch, TanStack Query via `useAshMutation`

---

## Task 1: Create the Embedded Resource

Create `Angle.Accounts.NotificationPreferences` with 9 boolean attributes, all defaulting to `true`.

**Files:**
- Create: `lib/angle/accounts/notification_preferences.ex`

**Step 1: Create the embedded resource**

```elixir
# lib/angle/accounts/notification_preferences.ex
defmodule Angle.Accounts.NotificationPreferences do
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    # Push Notifications
    attribute :push_bidding, :boolean, default: true, public?: true
    attribute :push_watchlist, :boolean, default: true, public?: true
    attribute :push_payments, :boolean, default: true, public?: true
    attribute :push_communication, :boolean, default: true, public?: true

    # Email Notifications
    attribute :email_communication, :boolean, default: true, public?: true
    attribute :email_marketing, :boolean, default: true, public?: true
    attribute :email_security, :boolean, default: true, public?: true

    # SMS Alerts
    attribute :sms_communication, :boolean, default: true, public?: true
    attribute :sms_security, :boolean, default: true, public?: true
  end
end
```

**Step 2: Verify it compiles**

Run: `mix compile`
Expected: Compiles with no errors.

**Step 3: Commit**

```bash
git add lib/angle/accounts/notification_preferences.ex
git commit -m "feat: add NotificationPreferences embedded resource"
```

---

## Task 2: Add Attribute and Action to User Resource

Add `notification_preferences` attribute on User and `update_notification_preferences` action exposed via AshTypescript RPC.

**Files:**
- Modify: `lib/angle/accounts/user.ex` (attributes section ~line 475, actions section ~line 382)

**Step 1: Add the attribute to User**

In `lib/angle/accounts/user.ex`, inside the `attributes do` block (after `auto_charge` at line 475), add:

```elixir
    attribute :notification_preferences, Angle.Accounts.NotificationPreferences,
      default: %{},
      public?: true
```

**Step 2: Add the update action**

In the `actions do` block (after `update_auto_charge` at line 385), add:

```elixir
    update :update_notification_preferences do
      description "Update the user's notification preferences"
      accept [:notification_preferences]
    end
```

**Step 3: Verify it compiles**

Run: `mix compile`
Expected: Compiles with no errors.

**Step 4: Commit**

```bash
git add lib/angle/accounts/user.ex
git commit -m "feat: add notification_preferences attribute and action to User"
```

---

## Task 3: Generate Migration and Run Codegen

Generate the database migration for the new JSONB column and regenerate TypeScript RPC.

**Files:**
- Create: new migration file (auto-generated)
- Modify: `assets/js/ash_rpc.ts` (auto-generated)

**Step 1: Generate Ash codegen (migration)**

Run: `mix ash.codegen add_notification_preferences --dev`
Expected: Creates a migration file with an `add` column of type `:map` on the `users` table.

**Step 2: Run the migration**

Run: `mix ecto.migrate`
Expected: Migration runs successfully.

**Step 3: Generate TypeScript RPC**

Run: `mix ash_typescript.codegen`
Expected: `assets/js/ash_rpc.ts` is updated with `updateNotificationPreferences` function and related types.

**Step 4: Verify the generated function exists**

Run: `grep "updateNotificationPreferences" assets/js/ash_rpc.ts`
Expected: Shows the exported function signature.

**Step 5: Commit**

```bash
git add priv/repo/migrations/ assets/js/ash_rpc.ts lib/angle/accounts/user.ex
git commit -m "feat: add notification_preferences migration and codegen"
```

---

## Task 4: Add Controller Action and Route

Add the `notifications` action to `SettingsController` and the route in `router.ex`.

**Files:**
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Modify: `lib/angle_web/router.ex`

**Step 1: Add controller action**

In `lib/angle_web/controllers/settings_controller.ex`, after the `preferences` action (line 48), add:

```elixir
  def notifications(conn, _params) do
    conn
    |> assign_prop(:user, user_notifications_data(conn))
    |> render_inertia("settings/notifications")
  end
```

Then add the helper function after `user_payments_data` (line 103):

```elixir
  defp user_notifications_data(conn) do
    user = conn.assigns.current_user
    prefs = user.notification_preferences || %{}

    %{
      id: user.id,
      notification_preferences: %{
        push_bidding: Map.get(prefs, :push_bidding, true),
        push_watchlist: Map.get(prefs, :push_watchlist, true),
        push_payments: Map.get(prefs, :push_payments, true),
        push_communication: Map.get(prefs, :push_communication, true),
        email_communication: Map.get(prefs, :email_communication, true),
        email_marketing: Map.get(prefs, :email_marketing, true),
        email_security: Map.get(prefs, :email_security, true),
        sms_communication: Map.get(prefs, :sms_communication, true),
        sms_security: Map.get(prefs, :sms_security, true)
      }
    }
  end
```

**Step 2: Add route**

In `lib/angle_web/router.ex`, inside the protected settings scope (after line 120 for `/settings/legal`), add:

```elixir
    get "/settings/notifications", SettingsController, :notifications
```

**Step 3: Verify it compiles**

Run: `mix compile`
Expected: Compiles with no errors.

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/settings_controller.ex lib/angle_web/router.ex
git commit -m "feat: add notifications controller action and route"
```

---

## Task 5: Create React Notifications Page and Components

Build the notifications page with reusable `NotificationSection` component and toggle rows.

**Files:**
- Create: `assets/js/features/settings/components/notification-section.tsx`
- Create: `assets/js/pages/settings/notifications.tsx`
- Modify: `assets/js/features/settings/index.ts` (add barrel export)

**Step 1: Create the NotificationSection component**

This is a reusable component that renders a section title and a list of toggle rows. Follow the pattern from `auto-charge-section.tsx`.

```tsx
// assets/js/features/settings/components/notification-section.tsx
import { Switch } from "@/components/ui/switch";

interface NotificationToggle {
  key: string;
  label: string;
  description: string;
}

interface NotificationSectionProps {
  title: string;
  toggles: NotificationToggle[];
  values: Record<string, boolean>;
  onToggle: (key: string, value: boolean) => void;
  isPending: boolean;
}

export function NotificationSection({
  title,
  toggles,
  values,
  onToggle,
  isPending,
}: NotificationSectionProps) {
  return (
    <div>
      <h2 className="mb-4 text-base font-semibold text-content">{title}</h2>
      <div className="space-y-1">
        {toggles.map((toggle) => (
          <div
            key={toggle.key}
            className="flex items-center justify-between rounded-xl border border-subtle p-4"
          >
            <div className="mr-4">
              <p className="text-sm font-medium text-content">{toggle.label}</p>
              <p className="text-xs text-content-tertiary">
                {toggle.description}
              </p>
            </div>
            <Switch
              checked={values[toggle.key] ?? true}
              onCheckedChange={(checked) => onToggle(toggle.key, checked)}
              disabled={isPending}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
```

**Step 2: Create the notifications page**

```tsx
// assets/js/pages/settings/notifications.tsx
import { useState } from "react";
import { Head } from "@inertiajs/react";
import { Separator } from "@/components/ui/separator";
import { SettingsLayout } from "@/features/settings";
import { NotificationSection } from "@/features/settings/components/notification-section";
import { useAshMutation } from "@/hooks/use-ash-query";
import { updateNotificationPreferences, buildCSRFHeaders } from "@/ash_rpc";
import { toast } from "sonner";

interface NotificationPreferences {
  push_bidding: boolean;
  push_watchlist: boolean;
  push_payments: boolean;
  push_communication: boolean;
  email_communication: boolean;
  email_marketing: boolean;
  email_security: boolean;
  sms_communication: boolean;
  sms_security: boolean;
}

interface NotificationsUser {
  id: string;
  notification_preferences: NotificationPreferences;
}

interface SettingsNotificationsProps {
  user: NotificationsUser;
}

const PUSH_TOGGLES = [
  {
    key: "push_bidding",
    label: "Bidding",
    description: "Get notified when you're outbid or win an auction",
  },
  {
    key: "push_watchlist",
    label: "Watchlist",
    description: "Get reminders on items on your watchlist",
  },
  {
    key: "push_payments",
    label: "Payments",
    description: "Confirmations when money moves in and out",
  },
  {
    key: "push_communication",
    label: "Communication",
    description: "Alerts from buyers and sellers",
  },
];

const EMAIL_TOGGLES = [
  {
    key: "email_communication",
    label: "Communication",
    description: "Receive emails about your account activity",
  },
  {
    key: "email_marketing",
    label: "Marketing",
    description: "Receive emails about new products, features, and more",
  },
  {
    key: "email_security",
    label: "Security",
    description: "Receive emails about your account security",
  },
];

const SMS_TOGGLES = [
  {
    key: "sms_communication",
    label: "Communication",
    description: "Receive updates about your account activity",
  },
  {
    key: "sms_security",
    label: "Security",
    description: "Receive updates about your account security",
  },
];

export default function SettingsNotifications({ user }: SettingsNotificationsProps) {
  const [prefs, setPrefs] = useState<NotificationPreferences>(
    user.notification_preferences
  );

  const { mutate, isPending } = useAshMutation(
    (newPrefs: NotificationPreferences) =>
      updateNotificationPreferences({
        identity: user.id,
        input: { notificationPreferences: newPrefs },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => toast.success("Notification preferences updated"),
      onError: (_error, _vars, context) => {
        if (context?.previousPrefs) {
          setPrefs(context.previousPrefs);
        }
        toast.error("Failed to update notification preferences");
      },
    }
  );

  const handleToggle = (key: string, value: boolean) => {
    const previousPrefs = { ...prefs };
    const newPrefs = { ...prefs, [key]: value };
    setPrefs(newPrefs);
    mutate(newPrefs, { context: { previousPrefs } });
  };

  return (
    <>
      <Head title="Notification Settings" />
      <SettingsLayout title="Notifications">
        <div className="space-y-6">
          <NotificationSection
            title="Push Notifications"
            toggles={PUSH_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
          <Separator />
          <NotificationSection
            title="Email Notifications"
            toggles={EMAIL_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
          <Separator />
          <NotificationSection
            title="SMS Alerts"
            toggles={SMS_TOGGLES}
            values={prefs}
            onToggle={handleToggle}
            isPending={isPending}
          />
        </div>
      </SettingsLayout>
    </>
  );
}
```

**Step 3: Add barrel export**

In `assets/js/features/settings/index.ts`, add:

```typescript
export { NotificationSection } from "./components/notification-section";
```

**Step 4: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors.

**Step 5: Commit**

```bash
git add assets/js/features/settings/components/notification-section.tsx \
       assets/js/pages/settings/notifications.tsx \
       assets/js/features/settings/index.ts
git commit -m "feat: add notifications page and NotificationSection component"
```

---

## Task 6: Enable Sidebar Navigation

Update the settings sidebar to enable the Notifications menu item.

**Files:**
- Modify: `assets/js/features/settings/components/settings-layout.tsx` (line 23)

**Step 1: Update sidebar nav item**

In `assets/js/features/settings/components/settings-layout.tsx`, change line 23 from:

```typescript
  { label: "Notifications", href: "#", disabled: true, icon: Bell },
```

to:

```typescript
  { label: "Notifications", href: "/settings/notifications", icon: Bell },
```

**Step 2: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors.

**Step 3: Commit**

```bash
git add assets/js/features/settings/components/settings-layout.tsx
git commit -m "feat: enable Notifications menu item in settings sidebar"
```

---

## Task 7: Write Backend Tests

Add tests for the `update_notification_preferences` action and the controller action.

**Files:**
- Create: `test/angle/accounts/notification_preferences_test.exs`
- Create: `test/angle_web/controllers/settings_notifications_test.exs`

**Step 1: Write resource tests**

```elixir
# test/angle/accounts/notification_preferences_test.exs
defmodule Angle.Accounts.NotificationPreferencesTest do
  use Angle.DataCase, async: true

  alias Angle.Factory

  describe "update_notification_preferences" do
    test "new user has all preferences defaulting to true" do
      user = Factory.create_user()
      prefs = user.notification_preferences

      assert prefs.push_bidding == true
      assert prefs.push_watchlist == true
      assert prefs.push_payments == true
      assert prefs.push_communication == true
      assert prefs.email_communication == true
      assert prefs.email_marketing == true
      assert prefs.email_security == true
      assert prefs.sms_communication == true
      assert prefs.sms_security == true
    end

    test "can toggle individual preferences" do
      user = Factory.create_user()

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{
            notification_preferences: %{
              push_bidding: false,
              email_marketing: false
            }
          },
          authorize?: false
        )
        |> Ash.update()

      assert updated.notification_preferences.push_bidding == false
      assert updated.notification_preferences.email_marketing == false
      # Remaining defaults still true
      assert updated.notification_preferences.push_watchlist == true
      assert updated.notification_preferences.email_security == true
    end

    test "can disable all preferences" do
      user = Factory.create_user()

      all_false = %{
        push_bidding: false,
        push_watchlist: false,
        push_payments: false,
        push_communication: false,
        email_communication: false,
        email_marketing: false,
        email_security: false,
        sms_communication: false,
        sms_security: false
      }

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{notification_preferences: all_false},
          authorize?: false
        )
        |> Ash.update()

      prefs = updated.notification_preferences

      assert prefs.push_bidding == false
      assert prefs.push_watchlist == false
      assert prefs.push_payments == false
      assert prefs.push_communication == false
      assert prefs.email_communication == false
      assert prefs.email_marketing == false
      assert prefs.email_security == false
      assert prefs.sms_communication == false
      assert prefs.sms_security == false
    end
  end
end
```

**Step 2: Run tests to verify they pass**

Run: `mix test test/angle/accounts/notification_preferences_test.exs`
Expected: 3 tests, 0 failures.

**Step 3: Write controller test**

```elixir
# test/angle_web/controllers/settings_notifications_test.exs
defmodule AngleWeb.SettingsNotificationsTest do
  use AngleWeb.ConnCase, async: true

  alias Angle.Factory

  setup %{conn: conn} do
    user = Factory.create_user()

    conn =
      conn
      |> Plug.Test.init_test_session(%{})
      |> AshAuthentication.Plug.Helpers.store_in_session(user)

    %{conn: conn, user: user}
  end

  describe "GET /settings/notifications" do
    test "renders notifications page with default preferences", %{conn: conn} do
      conn = get(conn, "/settings/notifications")
      assert conn.status == 200
    end
  end
end
```

**Step 4: Run all tests**

Run: `mix test`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add test/angle/accounts/notification_preferences_test.exs \
       test/angle_web/controllers/settings_notifications_test.exs
git commit -m "test: add notification preferences and controller tests"
```

---

## Task 8: Final Verification

Run all checks to make sure everything works end-to-end.

**Step 1: Elixir compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with no warnings.

**Step 2: TypeScript compilation**

Run: `cd assets && npx tsc --noEmit`
Expected: No type errors.

**Step 3: Full test suite**

Run: `mix test`
Expected: All tests pass.

**Step 4: Codegen check**

Run: `mix ash.codegen --check`
Expected: No pending changes.

**Step 5: Start server and manually verify**

Run: `mix phx.server` (port 4111)
- Navigate to `/settings/notifications`
- Verify 3 sections render: Push Notifications (4 toggles), Email Notifications (3 toggles), SMS Alerts (2 toggles)
- Toggle a preference and verify toast appears
- Refresh page and verify toggle persists
