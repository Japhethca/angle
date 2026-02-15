# Settings Page — Account Section Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a settings page with an Account section for profile editing, with responsive desktop (sidebar layout) and mobile (settings menu + form) experiences.

**Architecture:** Phoenix controller loads user profile data and passes as Inertia props. Frontend uses react-hook-form + Zod for the account form. Profile updates go through AshTypescript RPC via a new `update_profile` action on User. Desktop shows sidebar-based settings layout; mobile shows a settings menu at `/settings` and a standalone form at `/settings/account`.

**Tech Stack:** Ash Framework, Phoenix, Inertia.js, React 19, react-hook-form, Zod, TanStack Query (useAshMutation), shadcn/ui, Tailwind CSS, Lucide React icons.

**Design doc:** `docs/plans/2026-02-14-settings-page-design.md`

---

## Task 1: Backend — Add `update_profile` action to User resource

**Files:**
- Modify: `lib/angle/accounts/user.ex`
- Test: `test/angle/accounts/user_test.exs`

**Step 1: Write the failing test**

Add to `test/angle/accounts/user_test.exs`:

```elixir
describe "update_profile" do
  test "updates profile fields for the acting user" do
    user = create_user(%{full_name: "Original Name"})

    updated =
      user
      |> Ash.Changeset.for_update(:update_profile, %{
        full_name: "New Name",
        phone_number: "08012345678",
        location: "Lagos, Nigeria"
      })
      |> Ash.update!(actor: user)

    assert updated.full_name == "New Name"
    assert updated.phone_number == "08012345678"
    assert updated.location == "Lagos, Nigeria"
  end

  test "does not allow updating email via update_profile" do
    user = create_user(%{email: "original@example.com"})

    updated =
      user
      |> Ash.Changeset.for_update(:update_profile, %{
        full_name: "New Name",
        email: "hacked@example.com"
      })
      |> Ash.update!(actor: user)

    assert to_string(updated.email) == "original@example.com"
    assert updated.full_name == "New Name"
  end

  test "rejects update_profile from a different user" do
    user = create_user()
    other_user = create_user()

    assert_raise Ash.Error.Forbidden, fn ->
      user
      |> Ash.Changeset.for_update(:update_profile, %{full_name: "Hacked"})
      |> Ash.update!(actor: other_user)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/accounts/user_test.exs --max-failures 1`
Expected: FAIL — `:update_profile` action not found.

**Step 3: Add the `update_profile` action**

In `lib/angle/accounts/user.ex`, inside the `actions do` block, after the existing `remove_role` action, add:

```elixir
update :update_profile do
  description "Update the user's profile information"
  accept [:full_name, :phone_number, :location]
end
```

No additional policy needed — the existing update policy handles it:
```elixir
policy action_type([:update]) do
  authorize_if expr(id == ^actor(:id))
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/angle/accounts/user_test.exs`
Expected: PASS (all tests)

**Step 5: Run codegen (if needed)**

Run: `mix ash.codegen --dev`
If there are pending changes, run: `mix ecto.migrate`

**Step 6: Commit**

```bash
git add lib/angle/accounts/user.ex test/angle/accounts/user_test.exs
git commit -m "feat: add update_profile action to User resource"
```

---

## Task 2: Backend — Add RPC mutation and regenerate TypeScript

**Files:**
- Modify: `lib/angle/accounts.ex`
- Auto-generated: `assets/js/ash_rpc.ts`

**Step 1: Add the RPC action**

In `lib/angle/accounts.ex`, inside the `typescript_rpc do` block, within the `resource Angle.Accounts.User do` block, after `rpc_action :list_users, :read`, add:

```elixir
rpc_action :update_profile, :update_profile
```

The full block should look like:
```elixir
typescript_rpc do
  resource Angle.Accounts.User do
    rpc_action :list_users, :read
    rpc_action :update_profile, :update_profile

    typed_query :seller_profile, :read_public_profile do
      # ... existing config ...
    end
  end
end
```

**Step 2: Regenerate TypeScript**

Run: `mix ash_typescript.codegen`

**Step 3: Verify the generated function exists**

Check that `assets/js/ash_rpc.ts` now contains an `updateProfile` function:

```bash
grep "export async function updateProfile" assets/js/ash_rpc.ts
```

Expected: A line like `export async function updateProfile<Fields extends ...>(`

**Step 4: Verify TypeScript compiles**

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

**Step 5: Commit**

```bash
git add lib/angle/accounts.ex assets/js/ash_rpc.ts
git commit -m "feat: add updateProfile RPC mutation"
```

---

## Task 3: Backend — Update routes and SettingsController

**Files:**
- Modify: `lib/angle_web/router.ex`
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Create: `test/angle_web/controllers/settings_controller_test.exs`

**Step 1: Write the controller tests**

Create `test/angle_web/controllers/settings_controller_test.exs`:

```elixir
defmodule AngleWeb.SettingsControllerTest do
  use AngleWeb.ConnCase

  describe "GET /settings (index)" do
    test "renders settings/index page for authenticated user", %{conn: conn} do
      user = create_user(%{full_name: "Test User", email: "settings@example.com"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings")

      response = html_response(conn, 200)
      assert response =~ "settings/index"
      assert response =~ "Test User"
      assert response =~ "settings@example.com"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /settings/account" do
    test "renders settings/account page with user profile data", %{conn: conn} do
      user =
        create_user(%{
          full_name: "Account User",
          email: "account@example.com",
          phone_number: "08012345678"
        })

      # Set location directly since factory doesn't support it
      user
      |> Ecto.Changeset.change(%{location: "Lagos, Nigeria"})
      |> Angle.Repo.update!()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/account")

      response = html_response(conn, 200)
      assert response =~ "settings/account"
      assert response =~ "Account User"
      assert response =~ "account@example.com"
      assert response =~ "08012345678"
      assert response =~ "Lagos, Nigeria"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/account")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/angle_web/controllers/settings_controller_test.exs --max-failures 1`
Expected: FAIL — route or controller action not found.

**Step 3: Add the `/settings/account` route**

In `lib/angle_web/router.ex`, inside the protected scope (the one with `pipe_through [:browser, :require_auth]`), add the `/settings/account` route. The existing `/settings` route stays:

```elixir
# Protected routes
scope "/", AngleWeb do
  pipe_through [:browser, :require_auth]

  get "/dashboard", DashboardController, :index
  get "/bids", BidsController, :index
  get "/watchlist", WatchlistController, :index
  get "/items/new", ItemsController, :new
  get "/profile", ProfileController, :show
  get "/settings", SettingsController, :index
  get "/settings/account", SettingsController, :account
end
```

**Important:** Place `/settings/account` AFTER `/settings` so the more specific route is matched correctly by Phoenix.

**Step 4: Update the SettingsController**

Replace the contents of `lib/angle_web/controllers/settings_controller.ex`:

```elixir
defmodule AngleWeb.SettingsController do
  use AngleWeb, :controller

  def index(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/index")
  end

  def account(conn, _params) do
    conn
    |> assign_prop(:user, user_profile_data(conn))
    |> render_inertia("settings/account")
  end

  defp user_profile_data(conn) do
    user = conn.assigns.current_user

    %{
      id: user.id,
      email: to_string(user.email),
      full_name: user.full_name,
      phone_number: user.phone_number,
      location: user.location
    }
  end
end
```

**Step 5: Create stub pages so Inertia can resolve them**

Delete `assets/js/pages/settings.tsx` and create two stub pages so the controller can render without errors:

Create `assets/js/pages/settings/index.tsx`:
```tsx
import { Head } from "@inertiajs/react";

export default function SettingsIndex() {
  return (
    <>
      <Head title="Settings" />
      <div className="p-4">
        <h1>Settings</h1>
      </div>
    </>
  );
}
```

Create `assets/js/pages/settings/account.tsx`:
```tsx
import { Head } from "@inertiajs/react";

export default function SettingsAccount() {
  return (
    <>
      <Head title="Account Settings" />
      <div className="p-4">
        <h1>Account</h1>
      </div>
    </>
  );
}
```

**Step 6: Run tests to verify they pass**

Run: `mix test test/angle_web/controllers/settings_controller_test.exs`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/angle_web/router.ex lib/angle_web/controllers/settings_controller.ex \
  test/angle_web/controllers/settings_controller_test.exs \
  assets/js/pages/settings/index.tsx assets/js/pages/settings/account.tsx
git rm assets/js/pages/settings.tsx
git commit -m "feat: add settings routes, controller, and stub pages"
```

---

## Task 4: Frontend — Create settings feature components

**Files:**
- Create: `assets/js/features/settings/components/settings-layout.tsx`
- Create: `assets/js/features/settings/components/account-form.tsx`
- Create: `assets/js/features/settings/components/profile-image-section.tsx`
- Create: `assets/js/features/settings/components/verification-section.tsx`
- Create: `assets/js/features/settings/components/quick-sign-in-section.tsx`
- Create: `assets/js/features/settings/index.ts`

### Step 1: Create directory structure

```bash
mkdir -p assets/js/features/settings/components
```

### Step 2: Create SettingsLayout

Create `assets/js/features/settings/components/settings-layout.tsx`:

```tsx
import { Link, usePage } from "@inertiajs/react";
import { router } from "@inertiajs/react";
import { ArrowLeft, ChevronRight, LogOut } from "lucide-react";
import { cn } from "@/lib/utils";

const settingsMenuItems = [
  { label: "Account", href: "/settings/account" },
  { label: "Store", href: "#", disabled: true },
  { label: "Security", href: "#", disabled: true },
  { label: "Payments", href: "#", disabled: true },
  { label: "Notifications", href: "#", disabled: true },
  { label: "Preferences", href: "#", disabled: true },
  { label: "Legal", href: "#", disabled: true },
  { label: "Support", href: "#", disabled: true },
];

interface SettingsLayoutProps {
  title: string;
  children: React.ReactNode;
}

export function SettingsLayout({ title, children }: SettingsLayoutProps) {
  const { url } = usePage();

  const handleLogout = () => {
    router.post("/auth/logout");
  };

  return (
    <>
      {/* Mobile: back arrow + title */}
      <div className="flex items-center gap-3 px-4 py-3 lg:hidden">
        <Link
          href="/settings"
          className="flex size-9 items-center justify-center rounded-full border border-neutral-06"
        >
          <ArrowLeft className="size-4 text-neutral-02" />
        </Link>
        <h1 className="text-base font-semibold text-neutral-01">{title}</h1>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        {/* Sidebar */}
        <aside className="w-[240px] shrink-0">
          <nav className="space-y-1">
            {settingsMenuItems.map((item) => {
              const isActive = url.startsWith(item.href) && !item.disabled;
              return (
                <Link
                  key={item.label}
                  href={item.disabled ? "#" : item.href}
                  className={cn(
                    "block rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-neutral-08 text-neutral-01"
                      : "text-neutral-04 hover:text-neutral-02",
                    item.disabled && "cursor-not-allowed opacity-50"
                  )}
                  onClick={(e) => {
                    if (item.disabled) e.preventDefault();
                  }}
                >
                  {item.label}
                </Link>
              );
            })}
          </nav>

          <button
            onClick={handleLogout}
            className="mt-6 block w-full rounded-lg px-3 py-2.5 text-left text-sm font-medium text-red-500 transition-colors hover:bg-red-50"
          >
            Log Out
          </button>
        </aside>

        {/* Content area */}
        <div className="min-w-0 flex-1">
          {/* Breadcrumb */}
          <nav className="mb-6 flex items-center gap-1.5 text-xs text-neutral-04">
            <span>Settings</span>
            <ChevronRight className="size-3" />
            <span className="text-neutral-02">{title}</span>
          </nav>

          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 lg:hidden">{children}</div>
    </>
  );
}
```

### Step 3: Create AccountForm

Create `assets/js/features/settings/components/account-form.tsx`:

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { useAshMutation } from "@/hooks/use-ash-query";
import { updateProfile, buildCSRFHeaders } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { ProfileImageSection } from "./profile-image-section";
import { VerificationSection } from "./verification-section";
import { QuickSignInSection } from "./quick-sign-in-section";

const profileSchema = z.object({
  full_name: z.string().min(1, "Name is required"),
  phone_number: z.string().optional().or(z.literal("")),
  location: z.string().optional().or(z.literal("")),
});

type ProfileFormData = z.infer<typeof profileSchema>;

interface AccountFormProps {
  user: {
    id: string;
    email: string;
    full_name: string | null;
    phone_number: string | null;
    location: string | null;
  };
}

export function AccountForm({ user }: AccountFormProps) {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      full_name: user.full_name ?? "",
      phone_number: user.phone_number ?? "",
      location: user.location ?? "",
    },
  });

  const { mutate: saveProfile, isPending } = useAshMutation(
    (data: ProfileFormData) =>
      updateProfile({
        input: {
          fullName: data.full_name,
          phoneNumber: data.phone_number || null,
          location: data.location || null,
        },
        fields: ["id", "fullName", "phoneNumber", "location"],
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Profile updated successfully");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to update profile");
      },
    }
  );

  const onSubmit = (data: ProfileFormData) => {
    saveProfile(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
      {/* Profile Image */}
      <ProfileImageSection />

      {/* Form Fields */}
      <div className="space-y-5">
        {/* Name */}
        <div className="space-y-2">
          <Label htmlFor="full_name">Name</Label>
          <Input
            id="full_name"
            placeholder="Enter your full name"
            {...register("full_name")}
          />
          {errors.full_name && (
            <p className="text-xs text-red-500">{errors.full_name.message}</p>
          )}
        </div>

        {/* Email (read-only) */}
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            value={user.email}
            disabled
            className="bg-neutral-08 text-neutral-04"
          />
        </div>

        {/* Phone Number */}
        <div className="space-y-2">
          <Label htmlFor="phone_number">Phone Number</Label>
          <div className="flex gap-2">
            <div className="flex h-10 w-16 shrink-0 items-center justify-center rounded-md border border-input bg-neutral-08 text-sm text-neutral-04">
              234
            </div>
            <Input
              id="phone_number"
              placeholder="Enter phone number"
              {...register("phone_number")}
            />
          </div>
          {errors.phone_number && (
            <p className="text-xs text-red-500">
              {errors.phone_number.message}
            </p>
          )}
        </div>

        {/* Address */}
        <div className="space-y-2">
          <Label htmlFor="location">Address</Label>
          <Input
            id="location"
            placeholder="Enter your address"
            {...register("location")}
          />
          {errors.location && (
            <p className="text-xs text-red-500">{errors.location.message}</p>
          )}
        </div>
      </div>

      {/* Verification */}
      <VerificationSection />

      {/* Quick Sign In */}
      <QuickSignInSection />

      {/* Save Button */}
      <Button
        type="submit"
        disabled={isPending || !isDirty}
        className="w-full rounded-full"
      >
        {isPending ? "Saving..." : "Save Changes"}
      </Button>
    </form>
  );
}
```

**Note on `updateProfile` input fields:** The generated RPC function from Ash will use camelCase field names (`fullName`, `phoneNumber`, `location`). The `fields` array specifies which response fields to return. The actual field name casing in the generated code should be verified after codegen in Task 2. If the generated function uses snake_case (e.g., `full_name`), adjust accordingly.

### Step 4: Create ProfileImageSection

Create `assets/js/features/settings/components/profile-image-section.tsx`:

```tsx
import { User } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ProfileImageSection() {
  return (
    <div className="flex items-center gap-4">
      <div className="flex size-16 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-20">
        <User className="size-8 text-neutral-04 lg:size-10" />
      </div>
      <div className="flex gap-2">
        <Button type="button" variant="outline" size="sm" className="rounded-full">
          Change
        </Button>
        <Button type="button" variant="ghost" size="sm" className="rounded-full text-red-500">
          Delete
        </Button>
      </div>
    </div>
  );
}
```

### Step 5: Create VerificationSection

Create `assets/js/features/settings/components/verification-section.tsx`:

```tsx
import { ShieldCheck } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function VerificationSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-neutral-01">Verification</h3>
        <div className="flex items-center gap-3 rounded-xl bg-neutral-08 p-4">
          <ShieldCheck className="size-5 text-neutral-04" />
          <div className="flex-1">
            <p className="text-sm font-medium text-neutral-02">
              Government Issued ID
            </p>
            <p className="text-xs text-neutral-04">Uploaded</p>
          </div>
        </div>
      </div>
    </div>
  );
}
```

### Step 6: Create QuickSignInSection

Create `assets/js/features/settings/components/quick-sign-in-section.tsx`:

```tsx
import { Separator } from "@/components/ui/separator";

export function QuickSignInSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-neutral-01">Quick Sign In</h3>
        <div className="flex items-center justify-between rounded-xl bg-neutral-08 p-4">
          <div className="flex items-center gap-3">
            <svg className="size-5" viewBox="0 0 24 24">
              <path
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
                fill="#4285F4"
              />
              <path
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                fill="#34A853"
              />
              <path
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
                fill="#FBBC05"
              />
              <path
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                fill="#EA4335"
              />
            </svg>
            <span className="text-sm font-medium text-neutral-02">Google</span>
          </div>
          <span className="text-xs font-medium text-green-600">Connected</span>
        </div>
      </div>
    </div>
  );
}
```

### Step 7: Create barrel export

Create `assets/js/features/settings/index.ts`:

```ts
export { SettingsLayout } from "./components/settings-layout";
export { AccountForm } from "./components/account-form";
export { ProfileImageSection } from "./components/profile-image-section";
export { VerificationSection } from "./components/verification-section";
export { QuickSignInSection } from "./components/quick-sign-in-section";
```

### Step 8: Verify TypeScript compiles

Run: `cd assets && npx tsc --noEmit`
Expected: No errors. If `updateProfile` function name or input shape differs from what's expected, adjust `account-form.tsx` accordingly.

### Step 9: Commit

```bash
git add assets/js/features/settings/
git commit -m "feat: add settings feature components (layout, form, placeholders)"
```

---

## Task 5: Frontend — Create settings pages

**Files:**
- Modify: `assets/js/pages/settings/index.tsx` (replace stub)
- Modify: `assets/js/pages/settings/account.tsx` (replace stub)

### Step 1: Build the settings index page (mobile menu + desktop redirect)

Replace `assets/js/pages/settings/index.tsx`:

```tsx
import { useEffect } from "react";
import { Head, Link, router } from "@inertiajs/react";
import { User, ChevronRight, Shield, CreditCard, Bell, SlidersHorizontal, Scale, HelpCircle, LogOut } from "lucide-react";
import { useMediaQuery } from "@/hooks/use-media-query";

interface SettingsUser {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  location: string | null;
}

interface SettingsIndexProps {
  user: SettingsUser;
}

const menuItems = [
  { label: "Security", icon: Shield, disabled: true },
  { label: "Payments", icon: CreditCard, disabled: true },
  { label: "Notifications", icon: Bell, disabled: true },
  { label: "Preferences", icon: SlidersHorizontal, disabled: true },
  { label: "Legal", icon: Scale, disabled: true },
  { label: "Support", icon: HelpCircle, disabled: true },
];

export default function SettingsIndex({ user }: SettingsIndexProps) {
  const isDesktop = useMediaQuery("(min-width: 1024px)");

  // Desktop: redirect to account page
  useEffect(() => {
    if (isDesktop) {
      router.replace("/settings/account");
    }
  }, [isDesktop]);

  const handleLogout = () => {
    router.post("/auth/logout");
  };

  return (
    <>
      <Head title="Settings" />

      <div className="px-4 py-4 lg:hidden">
        <h1 className="mb-4 text-lg font-semibold text-neutral-01">Settings</h1>

        {/* Profile card */}
        <Link
          href="/settings/account"
          className="mb-4 flex items-center gap-3 rounded-2xl bg-neutral-08 p-4"
        >
          <div className="flex size-12 shrink-0 items-center justify-center rounded-full bg-neutral-06">
            <User className="size-6 text-neutral-04" />
          </div>
          <div className="min-w-0 flex-1">
            <div className="flex items-center gap-1">
              <p className="truncate text-sm font-medium text-neutral-01">
                {user.full_name || "Set up your profile"}
              </p>
              <ChevronRight className="size-4 shrink-0 text-neutral-04" />
            </div>
            <p className="truncate text-xs text-neutral-04">{user.email}</p>
          </div>
        </Link>

        {/* Menu items */}
        <div className="space-y-1">
          {menuItems.map((item) => (
            <div
              key={item.label}
              className="flex items-center justify-between rounded-lg px-3 py-3 text-neutral-04 opacity-50"
            >
              <div className="flex items-center gap-3">
                <item.icon className="size-5" />
                <span className="text-sm font-medium">{item.label}</span>
              </div>
              <ChevronRight className="size-4" />
            </div>
          ))}
        </div>

        {/* Log Out */}
        <button
          onClick={handleLogout}
          className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-3 text-red-500"
        >
          <LogOut className="size-5" />
          <span className="text-sm font-medium">Log Out</span>
        </button>
      </div>
    </>
  );
}
```

**Note:** This page needs a `useMediaQuery` hook. Check if it already exists at `assets/js/hooks/use-media-query.ts`. If not, create it:

```ts
// assets/js/hooks/use-media-query.ts
import { useState, useEffect } from "react";

export function useMediaQuery(query: string): boolean {
  const [matches, setMatches] = useState(false);

  useEffect(() => {
    const media = window.matchMedia(query);
    setMatches(media.matches);

    const listener = (e: MediaQueryListEvent) => setMatches(e.matches);
    media.addEventListener("change", listener);
    return () => media.removeEventListener("change", listener);
  }, [query]);

  return matches;
}
```

### Step 2: Build the settings account page

Replace `assets/js/pages/settings/account.tsx`:

```tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";

interface SettingsUser {
  id: string;
  email: string;
  full_name: string | null;
  phone_number: string | null;
  location: string | null;
}

interface SettingsAccountProps {
  user: SettingsUser;
}

export default function SettingsAccount({ user }: SettingsAccountProps) {
  return (
    <>
      <Head title="Account Settings" />
      <SettingsLayout title="Account">
        <AccountForm user={user} />
      </SettingsLayout>
    </>
  );
}
```

### Step 3: Verify TypeScript compiles

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

### Step 4: Commit

```bash
git add assets/js/pages/settings/ assets/js/hooks/use-media-query.ts
git commit -m "feat: implement settings pages (mobile menu + account form)"
```

---

## Task 6: Frontend — Update navigation links + final verification

**Files:**
- Modify: `assets/js/navigation/main-nav.tsx`

### Step 1: Update the desktop nav profile icon link

In `assets/js/navigation/main-nav.tsx`, find the User icon link that points to `/profile` and change it to `/settings/account`. Look for something like:

```tsx
<Link href="/profile" ...>
  <User className="..." />
</Link>
```

Change `href="/profile"` to `href="/settings/account"`.

Also update any mobile menu "Profile" link from `/profile` to `/settings/account`.

### Step 2: Verify TypeScript compiles

Run: `cd assets && npx tsc --noEmit`
Expected: No errors

### Step 3: Run full test suite

Run: `mix test`
Expected: All tests pass (including new settings controller tests)

### Step 4: Manual verification

Start the server: `mix phx.server`

Verify on desktop (http://localhost:4111):
1. Log in → click User icon in nav → should go to `/settings/account`
2. Settings page shows sidebar with "Account" active + breadcrumb "Settings > Account"
3. Form pre-populated with user data (name, email disabled, phone, address)
4. Edit name → "Save Changes" button enables → click → toast "Profile updated" → page refreshes with new data
5. Navigate to `/settings` → redirects to `/settings/account`

Verify on mobile (resize to < 1024px):
1. Bottom nav → Settings icon → shows settings menu at `/settings`
2. Profile card shows name + email with chevron
3. Tap profile card → goes to `/settings/account` with back arrow
4. Account form works same as desktop
5. Back arrow → returns to `/settings` menu

### Step 5: Commit

```bash
git add assets/js/navigation/main-nav.tsx
git commit -m "feat: update nav profile link to settings page"
```

---

## Task 7: Figma comparison and pixel-polish

**Figma references (from design doc):**
- Desktop Account: `node-id=352-14681`
- Mobile Settings menu: `node-id=352-14725`
- Mobile Account (variant A): `node-id=633-5727`
- Mobile Account (variant B): `node-id=678-7411`

### Step 1: Fetch Figma screenshots

Use the Figma MCP tool to fetch screenshots for each of the 4 designs above.

### Step 2: Take browser screenshots

Take screenshots of the implemented pages at matching viewports:
- Desktop `/settings/account` at 1440px width
- Mobile `/settings` at 390px width
- Mobile `/settings/account` at 390px width

### Step 3: Compare and document differences

For each view, compare the implementation screenshot against the Figma screenshot. Note any differences in:
- Spacing / padding / margins
- Font sizes and weights
- Colors
- Border radii
- Component sizing
- Layout alignment
- Missing or extra elements

### Step 4: Fix discrepancies

Apply CSS/layout fixes for any significant discrepancies found. Minor differences (anti-aliasing, font rendering) can be ignored.

### Step 5: Commit fixes

```bash
git add -A
git commit -m "fix: polish settings page to match Figma designs"
```

---

## Verification Checklist

After all tasks complete:

1. `cd assets && npx tsc --noEmit` — TypeScript compiles
2. `mix test` — all tests pass
3. Desktop: `/settings` redirects to `/settings/account`
4. Desktop: sidebar layout with account form, breadcrumb works
5. Mobile: `/settings` shows settings menu
6. Mobile: `/settings/account` shows back arrow + form
7. Profile update saves and refreshes correctly
8. Email field is read-only
9. Phone field has "234" prefix
10. Verification and Quick Sign In sections display as static placeholders
11. Implementation matches Figma designs (verified via screenshot comparison)
