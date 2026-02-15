# Store Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a Store section to the settings page backed by a new StoreProfile resource, allowing users to manage their seller profile (store name, contact, WhatsApp link, location, address, delivery preferences).

**Architecture:** New `Angle.Accounts.StoreProfile` resource with its own `store_profiles` table, connected to User via `has_one`. Migrate `store_name` from User to StoreProfile. Frontend follows the same pattern as the Account settings page: controller loads data as Inertia props, React form uses `useAshMutation` for upsert via RPC.

**Tech Stack:** Ash Framework, Phoenix/Inertia.js, React 19, React Hook Form + Zod, shadcn/ui Select component, TanStack Query

**Design doc:** `docs/plans/2026-02-15-store-settings-design.md`

**Figma references:** Desktop node `678-6906`, Mobile node `678-7347`, file `jk9qoWNcSpgUa8lsj7uXa9`

---

### Task 1: Create StoreProfile Ash Resource

Create the new resource with all attributes and a basic read action.

**Files:**
- Create: `lib/angle/accounts/store_profile.ex`
- Modify: `lib/angle/accounts.ex` (add to resources list)

**Step 1: Create the StoreProfile resource**

Create `lib/angle/accounts/store_profile.ex`:

```elixir
defmodule Angle.Accounts.StoreProfile do
  use Ash.Resource,
    otp_app: :angle,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  postgres do
    table "store_profiles"
    repo Angle.Repo
  end

  typescript do
    type_name "StoreProfile"
  end

  actions do
    defaults [:read]

    create :upsert do
      description "Create or update a store profile for a user"
      accept [:store_name, :contact_phone, :whatsapp_link, :location, :address, :delivery_preference]

      argument :user_id, :uuid do
        allow_nil? false
      end

      change set_attribute(:user_id, arg(:user_id))

      upsert? true
      upsert_identity :unique_user
      upsert_fields [
        :store_name,
        :contact_phone,
        :whatsapp_link,
        :location,
        :address,
        :delivery_preference
      ]
    end
  end

  policies do
    policy action(:read) do
      authorize_if always()
    end

    policy action(:upsert) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :store_name, :string, allow_nil?: false, public?: true
    attribute :contact_phone, :string, public?: true
    attribute :whatsapp_link, :string, public?: true
    attribute :location, :string, public?: true
    attribute :address, :string, public?: true
    attribute :delivery_preference, :string, public?: true, default: "you_arrange"

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user, [:user_id]
  end
end
```

**Step 2: Register in domain**

In `lib/angle/accounts.ex`, add to the `resources` block (after line 41):

```elixir
resource Angle.Accounts.StoreProfile
```

**Step 3: Generate migration and migrate**

Run:
```bash
mix ash.codegen --dev add_store_profiles
mix ash.migrate
```

Expected: Migration creates `store_profiles` table with all columns, unique index on `user_id`.

**Step 4: Verify compilation**

Run: `mix compile --warnings-as-errors`

Expected: PASS (no errors)

**Step 5: Commit**

```bash
git add lib/angle/accounts/store_profile.ex lib/angle/accounts.ex priv/repo/migrations/
git commit -m "feat: add StoreProfile resource with upsert action"
```

---

### Task 2: Test StoreProfile + Add Factory

Write tests for the upsert action and add a factory function.

**Files:**
- Create: `test/angle/accounts/store_profile_test.exs`
- Modify: `test/support/factory.ex`

**Step 1: Add factory function**

In `test/support/factory.ex`, add after the `create_bid` function (around line 156):

```elixir
@doc """
Creates a store profile for a user.

## Options

  * `:store_name` - defaults to a unique generated store name
  * `:contact_phone` - optional
  * `:whatsapp_link` - optional
  * `:location` - optional
  * `:address` - optional
  * `:delivery_preference` - defaults to "you_arrange"
  * `:user_id` - the UUID of the user (creates one if not provided)

"""
def create_store_profile(attrs \\ %{}) do
  user_id = Map.get_lazy(attrs, :user_id, fn -> create_user().id end)

  params =
    %{
      store_name: Map.get(attrs, :store_name, "Store #{System.unique_integer([:positive])}"),
      user_id: user_id,
      delivery_preference: Map.get(attrs, :delivery_preference, "you_arrange")
    }
    |> maybe_put(:contact_phone, Map.get(attrs, :contact_phone))
    |> maybe_put(:whatsapp_link, Map.get(attrs, :whatsapp_link))
    |> maybe_put(:location, Map.get(attrs, :location))
    |> maybe_put(:address, Map.get(attrs, :address))

  Ash.create!(Angle.Accounts.StoreProfile, params, action: :upsert, authorize?: false)
end
```

**Step 2: Write tests**

Create `test/angle/accounts/store_profile_test.exs`:

```elixir
defmodule Angle.Accounts.StoreProfileTest do
  use Angle.DataCase, async: true

  describe "upsert action" do
    test "creates a store profile for a user" do
      user = create_user()

      profile =
        create_store_profile(%{
          user_id: user.id,
          store_name: "My Test Store",
          contact_phone: "08012345678",
          whatsapp_link: "wa.me/2348012345678",
          location: "Lagos",
          address: "9A, Bade drive, Lagos",
          delivery_preference: "seller_delivers"
        })

      assert profile.store_name == "My Test Store"
      assert profile.contact_phone == "08012345678"
      assert profile.whatsapp_link == "wa.me/2348012345678"
      assert profile.location == "Lagos"
      assert profile.address == "9A, Bade drive, Lagos"
      assert profile.delivery_preference == "seller_delivers"
      assert profile.user_id == user.id
    end

    test "upserts (updates) when store profile already exists for user" do
      user = create_user()
      _first = create_store_profile(%{user_id: user.id, store_name: "Original"})

      updated = create_store_profile(%{user_id: user.id, store_name: "Updated Name"})

      assert updated.store_name == "Updated Name"
      assert updated.user_id == user.id

      # Verify only one store profile exists for this user
      profiles =
        Angle.Accounts.StoreProfile
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read!(authorize?: false)

      assert length(profiles) == 1
    end

    test "requires store_name" do
      user = create_user()

      assert_raise Ash.Error.Invalid, fn ->
        Ash.create!(
          Angle.Accounts.StoreProfile,
          %{user_id: user.id},
          action: :upsert,
          authorize?: false
        )
      end
    end

    test "defaults delivery_preference to you_arrange" do
      user = create_user()
      profile = create_store_profile(%{user_id: user.id, store_name: "My Store"})

      assert profile.delivery_preference == "you_arrange"
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/angle/accounts/store_profile_test.exs`

Expected: 4 tests, 0 failures

**Step 4: Commit**

```bash
git add test/angle/accounts/store_profile_test.exs test/support/factory.ex
git commit -m "test: add StoreProfile tests and factory function"
```

---

### Task 3: Update User Resource — Migrate store_name, Add Relationship

Move `store_name` from User to StoreProfile and add the `has_one` relationship.

**Files:**
- Modify: `lib/angle/accounts/user.ex`

**Step 1: Update User resource**

In `lib/angle/accounts/user.ex`:

1. Remove `store_name` attribute (line 468):
   ```elixir
   # DELETE this line:
   attribute :store_name, :string, public?: true
   ```

2. Add `has_one` relationship in the `relationships` block (after line 495):
   ```elixir
   has_one :store_profile, Angle.Accounts.StoreProfile do
     destination_attribute :user_id
     public? true
   end
   ```

**Step 2: Generate migration for removing store_name**

Run:
```bash
mix ash.codegen --dev remove_store_name_from_users
mix ash.migrate
```

Expected: Migration removes `store_name` column from `users` table.

**Note:** If there is existing `store_name` data in the database, create a data migration step in the migration file to copy it to `store_profiles` before dropping the column. The migration should:
1. For each user row with a non-null `store_name`, INSERT into `store_profiles` (id=gen_random_uuid(), user_id=user.id, store_name=user.store_name, delivery_preference='you_arrange', inserted_at=now(), updated_at=now())
2. Then drop the `store_name` column

**Step 3: Run all tests**

Run: `mix test`

Expected: All tests pass. If any test references `store_name` on User, update it to use StoreProfile instead.

**Step 4: Commit**

```bash
git add lib/angle/accounts/user.ex priv/repo/migrations/
git commit -m "refactor: migrate store_name from User to StoreProfile"
```

---

### Task 4: Register RPC Action + TypeScript Codegen

Add the upsert RPC action and run codegen to generate TypeScript functions.

**Files:**
- Modify: `lib/angle/accounts.ex`

**Step 1: Add RPC action for StoreProfile**

In `lib/angle/accounts.ex`, add inside `typescript_rpc do` block, after the User resource section (after line 31):

```elixir
resource Angle.Accounts.StoreProfile do
  rpc_action :upsert_store_profile, :upsert
end
```

**Step 2: Run TypeScript codegen**

Run:
```bash
mix ash_typescript.codegen
```

Expected: `assets/js/ash_rpc.ts` is updated with `upsertStoreProfile` function and `UpsertStoreProfileInput` type.

**Step 3: Verify the generated types**

Check that `assets/js/ash_rpc.ts` contains:
- `UpsertStoreProfileInput` with fields: `storeName`, `contactPhone`, `whatsappLink`, `location`, `address`, `deliveryPreference`, `userId`
- `upsertStoreProfile` function

**Step 4: Compile everything**

Run: `mix compile && cd assets && npx tsc --noEmit`

Expected: Both pass.

**Step 5: Commit**

```bash
git add lib/angle/accounts.ex assets/js/ash_rpc.ts
git commit -m "feat: add StoreProfile upsert RPC action"
```

---

### Task 5: Settings Controller + Route + Tests

Add the `/settings/store` route, controller action, and tests.

**Files:**
- Modify: `lib/angle_web/router.ex` (line 113)
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Modify: `test/angle_web/controllers/settings_controller_test.exs`

**Step 1: Write the controller test**

Add to `test/angle_web/controllers/settings_controller_test.exs`, after the existing `describe` blocks:

```elixir
describe "GET /settings/store" do
  test "renders settings/store page with store profile data", %{conn: conn} do
    user = create_user(%{email: "store@example.com"})

    _store_profile =
      create_store_profile(%{
        user_id: user.id,
        store_name: "Test Store",
        contact_phone: "08012345678",
        whatsapp_link: "wa.me/2348012345678",
        location: "Lagos",
        address: "9A, Bade drive, Lagos",
        delivery_preference: "seller_delivers"
      })

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/settings/store")

    response = html_response(conn, 200)
    assert response =~ "settings/store"
    assert response =~ "Test Store"
    assert response =~ "08012345678"
    assert response =~ "Lagos"
  end

  test "renders settings/store page when user has no store profile", %{conn: conn} do
    user = create_user(%{email: "nostore@example.com"})

    conn =
      conn
      |> init_test_session(%{current_user_id: user.id})
      |> get(~p"/settings/store")

    response = html_response(conn, 200)
    assert response =~ "settings/store"
  end

  test "redirects to login when not authenticated", %{conn: conn} do
    conn = get(conn, ~p"/settings/store")
    assert redirected_to(conn) == ~p"/auth/login"
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/angle_web/controllers/settings_controller_test.exs`

Expected: FAIL (route not found / action not defined)

**Step 3: Add route**

In `lib/angle_web/router.ex`, add after line 113 (`get "/settings/account"`):

```elixir
get "/settings/store", SettingsController, :store
```

**Step 4: Add controller action**

In `lib/angle_web/controllers/settings_controller.ex`, add after the `account` function:

```elixir
def store(conn, _params) do
  user = conn.assigns.current_user

  store_profile =
    Angle.Accounts.StoreProfile
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read_one!(authorize?: false)

  conn
  |> assign_prop(:user, user_profile_data(conn))
  |> assign_prop(:store_profile, store_profile_data(store_profile))
  |> render_inertia("settings/store")
end
```

Add the helper function:

```elixir
defp store_profile_data(nil), do: nil

defp store_profile_data(profile) do
  %{
    id: profile.id,
    store_name: profile.store_name,
    contact_phone: profile.contact_phone,
    whatsapp_link: profile.whatsapp_link,
    location: profile.location,
    address: profile.address,
    delivery_preference: profile.delivery_preference
  }
end
```

Add `require Ash.Query` at the top of the module (after `use AngleWeb, :controller`).

**Step 5: Create stub page** (so the Inertia render works)

Create `assets/js/pages/settings/store.tsx`:

```tsx
import { Head } from "@inertiajs/react";

export default function SettingsStore() {
  return (
    <>
      <Head title="Store Settings" />
      <div>Store settings placeholder</div>
    </>
  );
}
```

**Step 6: Run tests**

Run: `mix test test/angle_web/controllers/settings_controller_test.exs`

Expected: All tests pass (including existing account tests).

**Step 7: Commit**

```bash
git add lib/angle_web/router.ex lib/angle_web/controllers/settings_controller.ex test/angle_web/controllers/settings_controller_test.exs assets/js/pages/settings/store.tsx
git commit -m "feat: add /settings/store route, controller action, and tests"
```

---

### Task 6: Frontend — Store Form Component

Build the store form with all fields matching the Figma designs.

**Files:**
- Create: `assets/js/features/settings/components/store-form.tsx`
- Create: `assets/js/features/settings/components/store-verification-section.tsx`
- Create: `assets/js/features/settings/components/store-logo-section.tsx`
- Modify: `assets/js/features/settings/index.ts`

**Reference:** The account form (`features/settings/components/account-form.tsx`) is the pattern to follow. The Figma desktop design (node `678-6906`) shows the exact layout.

**Step 1: Create store logo section (static placeholder)**

Create `assets/js/features/settings/components/store-logo-section.tsx`:

```tsx
import { Monitor, Camera } from "lucide-react";
import { Button } from "@/components/ui/button";

export function StoreLogoSection() {
  return (
    <div className="flex items-center gap-4">
      <div className="flex size-16 shrink-0 items-center justify-center rounded-2xl bg-neutral-08 lg:size-20">
        <Monitor className="size-8 text-primary-600 lg:size-10" />
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold text-neutral-01">Store logo</p>
        <div className="flex items-center gap-2">
          <Button type="button" variant="outline" size="sm" className="rounded-full">
            Change
            <Camera className="size-4" />
          </Button>
          <Button type="button" variant="ghost" size="sm" className="rounded-full text-neutral-04">
            Delete
          </Button>
        </div>
      </div>
    </div>
  );
}
```

**Step 2: Create store verification section (two cards)**

Create `assets/js/features/settings/components/store-verification-section.tsx`:

```tsx
import { FileText, Trash2 } from "lucide-react";
import { Separator } from "@/components/ui/separator";

const verificationItems = [
  {
    label: "Personal id",
    filename: "Emmanuella's drivers license.pdf",
    badge: "Drivers license",
    date: "19/06/25",
  },
  {
    label: "Business ID",
    filename: "CAC reg doc.pdf",
    badge: "CAC registration",
    date: "19/06/25",
  },
];

export function StoreVerificationSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-4">
        <h3 className="text-sm font-semibold text-neutral-01">Verification</h3>
        {verificationItems.map((item) => (
          <div key={item.label} className="space-y-1.5">
            <p className="text-xs font-medium text-neutral-04">{item.label}</p>
            <div className="flex items-center gap-3 rounded-xl bg-neutral-08 p-4">
              <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary-600/10">
                <FileText className="size-5 text-primary-600" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-neutral-01">
                  {item.filename}
                </p>
                <span className="mt-0.5 inline-block rounded-full bg-green-100 px-2 py-0.5 text-[10px] font-medium text-green-700">
                  {item.badge}
                </span>
              </div>
              <button
                type="button"
                className="shrink-0 text-neutral-04 hover:text-red-500"
              >
                <Trash2 className="size-4" />
              </button>
            </div>
            <p className="text-xs text-neutral-04">
              Verification Date {item.date}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
```

**Step 3: Create the store form**

Create `assets/js/features/settings/components/store-form.tsx`:

```tsx
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { ChevronDown } from "lucide-react";
import { useAshMutation } from "@/hooks/use-ash-query";
import { upsertStoreProfile, buildCSRFHeaders } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Separator } from "@/components/ui/separator";
import { StoreLogoSection } from "./store-logo-section";
import { StoreVerificationSection } from "./store-verification-section";

const NIGERIAN_STATES = [
  "Abia", "Adamawa", "Akwa Ibom", "Anambra", "Bauchi", "Bayelsa", "Benue",
  "Borno", "Cross River", "Delta", "Ebonyi", "Edo", "Ekiti", "Enugu",
  "FCT Abuja", "Gombe", "Imo", "Jigawa", "Kaduna", "Kano", "Katsina",
  "Kebbi", "Kogi", "Kwara", "Lagos", "Nasarawa", "Niger", "Ogun", "Ondo",
  "Osun", "Oyo", "Plateau", "Rivers", "Sokoto", "Taraba", "Yobe", "Zamfara",
] as const;

const DELIVERY_OPTIONS = [
  { value: "you_arrange", label: "You arrange delivery" },
  { value: "seller_delivers", label: "Seller delivers" },
  { value: "pickup_only", label: "Pickup only" },
] as const;

const storeSchema = z.object({
  store_name: z.string().min(1, "Store name is required"),
  contact_phone: z.string().optional().or(z.literal("")),
  whatsapp_link: z.string().optional().or(z.literal("")),
  location: z.string().optional().or(z.literal("")),
  address: z.string().optional().or(z.literal("")),
  delivery_preference: z.string().default("you_arrange"),
});

type StoreFormData = z.infer<typeof storeSchema>;

interface StoreFormProps {
  userId: string;
  storeProfile: {
    id: string;
    store_name: string;
    contact_phone: string | null;
    whatsapp_link: string | null;
    location: string | null;
    address: string | null;
    delivery_preference: string | null;
  } | null;
}

export function StoreForm({ userId, storeProfile }: StoreFormProps) {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isDirty },
  } = useForm<StoreFormData>({
    resolver: zodResolver(storeSchema),
    defaultValues: {
      store_name: storeProfile?.store_name ?? "",
      contact_phone: storeProfile?.contact_phone ?? "",
      whatsapp_link: storeProfile?.whatsapp_link ?? "",
      location: storeProfile?.location ?? "",
      address: storeProfile?.address ?? "",
      delivery_preference: storeProfile?.delivery_preference ?? "you_arrange",
    },
  });

  const { mutate: saveStore, isPending } = useAshMutation(
    (data: StoreFormData) =>
      upsertStoreProfile({
        input: {
          userId: userId,
          storeName: data.store_name,
          contactPhone: data.contact_phone || null,
          whatsappLink: data.whatsapp_link || null,
          location: data.location || null,
          address: data.address || null,
          deliveryPreference: data.delivery_preference || "you_arrange",
        },
        fields: ["id", "storeName", "contactPhone", "whatsappLink", "location", "address", "deliveryPreference"],
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Store profile updated successfully");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to update store profile");
      },
    }
  );

  const onSubmit = (data: StoreFormData) => {
    saveStore(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
      {/* Store Logo */}
      <StoreLogoSection />

      {/* Form Fields */}
      <div className="space-y-5">
        {/* Store Name */}
        <div className="space-y-2">
          <Label htmlFor="store_name">Store Name</Label>
          <Input
            id="store_name"
            placeholder="Enter store name"
            {...register("store_name")}
          />
          {errors.store_name && (
            <p className="text-xs text-red-500">{errors.store_name.message}</p>
          )}
        </div>

        {/* Contact */}
        <div className="space-y-2">
          <Label htmlFor="contact_phone">Contact</Label>
          <div className="flex gap-2">
            <div className="flex h-10 shrink-0 items-center gap-1 rounded-md border border-input bg-neutral-08 px-2 text-sm text-neutral-04">
              <span className="text-xs leading-none">🇳🇬</span>
              <span>234</span>
              <ChevronDown className="size-3" />
            </div>
            <Input
              id="contact_phone"
              placeholder="Enter phone number"
              {...register("contact_phone")}
            />
          </div>
          {errors.contact_phone && (
            <p className="text-xs text-red-500">{errors.contact_phone.message}</p>
          )}
        </div>

        {/* WhatsApp Link */}
        <div className="space-y-2">
          <Label htmlFor="whatsapp_link">Whatsapp Link</Label>
          <div className="flex gap-2">
            <div className="flex h-10 shrink-0 items-center rounded-md border border-input bg-neutral-08 px-3 text-sm text-neutral-04">
              http://
            </div>
            <Input
              id="whatsapp_link"
              placeholder="wa.me/234"
              {...register("whatsapp_link")}
            />
          </div>
          {errors.whatsapp_link && (
            <p className="text-xs text-red-500">{errors.whatsapp_link.message}</p>
          )}
        </div>

        {/* Location (dropdown) */}
        <div className="space-y-2">
          <Label>Location</Label>
          <Controller
            name="location"
            control={control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger>
                  <SelectValue placeholder="Select state" />
                </SelectTrigger>
                <SelectContent>
                  {NIGERIAN_STATES.map((state) => (
                    <SelectItem key={state} value={state}>
                      {state}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          {errors.location && (
            <p className="text-xs text-red-500">{errors.location.message}</p>
          )}
        </div>

        {/* Address */}
        <div className="space-y-2">
          <Label htmlFor="address">Address</Label>
          <Input
            id="address"
            placeholder="Enter your address"
            {...register("address")}
          />
          {errors.address && (
            <p className="text-xs text-red-500">{errors.address.message}</p>
          )}
        </div>
      </div>

      {/* Verification */}
      <StoreVerificationSection />

      {/* Preferences */}
      <div>
        <Separator className="mb-5" />
        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-neutral-01">Preferences</h3>
          <div className="space-y-2">
            <Label>Delivery</Label>
            <Controller
              name="delivery_preference"
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select delivery option" />
                  </SelectTrigger>
                  <SelectContent>
                    {DELIVERY_OPTIONS.map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
        </div>
      </div>

      {/* Save Button */}
      <Button
        type="submit"
        disabled={isPending || !isDirty}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isPending ? "Saving..." : "Save Changes"}
      </Button>
    </form>
  );
}
```

**Step 4: Update barrel exports**

In `assets/js/features/settings/index.ts`, add:

```typescript
export { StoreForm } from "./components/store-form";
export { StoreLogoSection } from "./components/store-logo-section";
export { StoreVerificationSection } from "./components/store-verification-section";

export interface StoreProfileData {
  id: string;
  store_name: string;
  contact_phone: string | null;
  whatsapp_link: string | null;
  location: string | null;
  address: string | null;
  delivery_preference: string | null;
}
```

**Step 5: TypeScript check**

Run: `cd assets && npx tsc --noEmit`

Expected: PASS (or only pre-existing errors, none from new store files)

**Step 6: Commit**

```bash
git add assets/js/features/settings/
git commit -m "feat: add store form and supporting components"
```

---

### Task 7: Frontend — Store Page + Enable Sidebar Link

Wire up the store page and enable the Store menu item.

**Files:**
- Modify: `assets/js/pages/settings/store.tsx` (replace stub)
- Modify: `assets/js/features/settings/components/settings-layout.tsx` (line 20)
- Modify: `assets/js/pages/settings/index.tsx` (enable Store in mobile menu)

**Step 1: Replace the stub store page**

Replace `assets/js/pages/settings/store.tsx` with:

```tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, StoreForm } from "@/features/settings";
import type { SettingsUser, StoreProfileData } from "@/features/settings";

interface SettingsStoreProps {
  user: SettingsUser;
  store_profile: StoreProfileData | null;
}

export default function SettingsStore({ user, store_profile }: SettingsStoreProps) {
  return (
    <>
      <Head title="Store Settings" />
      <SettingsLayout title="Store" breadcrumbSuffix="Store Profile">
        <StoreForm userId={user.id} storeProfile={store_profile} />
      </SettingsLayout>
    </>
  );
}
```

**Step 2: Update SettingsLayout to support breadcrumb suffix**

The Figma shows "Store > Store Profile" as the breadcrumb. Update `settings-layout.tsx`:

1. Add `breadcrumbSuffix` to the props interface:

```tsx
interface SettingsLayoutProps {
  title: string;
  breadcrumbSuffix?: string;
  children: React.ReactNode;
}
```

2. Update the function signature and breadcrumb rendering:

```tsx
export function SettingsLayout({ title, breadcrumbSuffix, children }: SettingsLayoutProps) {
```

Update the breadcrumb nav (around line 95-99) to show the suffix:

```tsx
<nav className="mb-6 flex items-center gap-1.5 text-xs text-neutral-04">
  <span>Settings</span>
  <ChevronRight className="size-3" />
  <span className={breadcrumbSuffix ? "" : "text-neutral-02"}>{title}</span>
  {breadcrumbSuffix && (
    <>
      <ChevronRight className="size-3" />
      <span className="text-neutral-02">{breadcrumbSuffix}</span>
    </>
  )}
</nav>
```

3. Enable the Store menu item (line 20):

```tsx
// Change from:
{ label: "Store", href: "#", disabled: true, icon: Store },
// To:
{ label: "Store", href: "/settings/store", icon: Store },
```

**Step 3: Update mobile settings index**

In `assets/js/pages/settings/index.tsx`, add Store to the mobile menu. The `menuItems` array currently has Store disabled. Add it as a Link instead of a div:

The settings/index page currently renders all items as `<div>` with `cursor-not-allowed`. Store needs to be a clickable `<Link>` like the profile card. The simplest approach: add a separate Store link card below the profile card, or make Store the first menu item that's not disabled.

Update the menu items array to enable Store:

```tsx
const menuItems = [
  { label: "Store", icon: Store, href: "/settings/store" },
  { label: "Security", icon: Shield, disabled: true },
  { label: "Payments", icon: CreditCard, disabled: true },
  { label: "Notifications", icon: Bell, disabled: true },
  { label: "Preferences", icon: SlidersHorizontal, disabled: true },
  { label: "Legal", icon: Scale, disabled: true },
  { label: "Support", icon: HelpCircle, disabled: true },
];
```

Then update the rendering logic to handle items with `href`:

```tsx
{menuItems.map((item) => {
  if (item.href) {
    return (
      <Link
        key={item.label}
        href={item.href}
        className="flex items-center justify-between rounded-lg px-3 py-3 text-neutral-01"
      >
        <div className="flex items-center gap-3">
          <item.icon className="size-5" />
          <span className="text-sm font-medium">{item.label}</span>
        </div>
        <ChevronRight className="size-4 text-neutral-04" />
      </Link>
    );
  }
  return (
    <div
      key={item.label}
      className="flex cursor-not-allowed items-center justify-between rounded-lg px-3 py-3 text-neutral-04"
    >
      <div className="flex items-center gap-3">
        <item.icon className="size-5" />
        <span className="text-sm font-medium">{item.label}</span>
      </div>
      <ChevronRight className="size-4" />
    </div>
  );
})}
```

Also import `Store` from lucide-react if not already imported, and import `Link` from `@inertiajs/react`.

**Step 4: TypeScript check**

Run: `cd assets && npx tsc --noEmit`

Expected: PASS

**Step 5: Commit**

```bash
git add assets/js/pages/settings/store.tsx assets/js/pages/settings/index.tsx assets/js/features/settings/components/settings-layout.tsx
git commit -m "feat: wire up store settings page and enable sidebar link"
```

---

### Task 8: Update Public Store Page

The public store page (`/store/:identifier`) currently reads `store_name` from the User resource via the `seller_profile` typed query. Update it to load from StoreProfile.

**Files:**
- Modify: `lib/angle/accounts.ex` (seller_profile typed query)
- Modify: `lib/angle/accounts/user.ex` (read_public_profile action — may need to load store_profile)

**Step 1: Update the seller_profile typed query**

The `seller_profile` typed query in `lib/angle/accounts.ex` (lines 15-30) currently includes `:store_name` as a field. Since `store_name` has been removed from User, this will break.

Two options:
1. Add a calculation on User that delegates to `store_profile.store_name`
2. Remove `:store_name` from the typed query fields and load it separately in the store controller

**Recommended: Add a calculation.** In `lib/angle/accounts/user.ex`, add to the `calculations` block:

```elixir
calculate :store_name, :string do
  description "Store name from the user's store profile"
  calculation fn records, _context ->
    # Load store profiles for all records
    user_ids = Enum.map(records, & &1.id)

    profiles =
      Angle.Accounts.StoreProfile
      |> Ash.Query.filter(user_id in ^user_ids)
      |> Ash.read!(authorize?: false)
      |> Map.new(fn p -> {p.user_id, p.store_name} end)

    Enum.map(records, fn record ->
      Map.get(profiles, record.id)
    end)
  end
end
```

Make it public so it's available in typed queries:

```elixir
calculate :store_name, :string, public?: true do
```

This way the `seller_profile` typed query keeps working with `:store_name` as a field, but it now reads from StoreProfile instead of a User attribute.

**Step 2: Run all tests**

Run: `mix test`

Expected: All tests pass.

**Step 3: Verify TypeScript codegen still works**

Run: `mix ash_typescript.codegen`

Verify `seller_profile` typed query still includes `storeName` in its fields.

**Step 4: Commit**

```bash
git add lib/angle/accounts/user.ex lib/angle/accounts.ex assets/js/ash_rpc.ts
git commit -m "refactor: add store_name calculation to maintain seller_profile compatibility"
```

---

### Task 9: Final Verification

Run the full test suite and do a visual check.

**Step 1: Run all tests**

Run: `mix test`

Expected: All tests pass.

**Step 2: TypeScript check**

Run: `cd assets && npx tsc --noEmit`

Expected: PASS (or only pre-existing errors)

**Step 3: Manual verification**

Start the server: `mix phx.server`

Check:
1. Navigate to `http://localhost:4111/settings` — Store should be enabled in mobile menu
2. Navigate to `http://localhost:4111/settings/store` — Form should render with all fields
3. Fill in store name, select a location, set delivery preference, click Save — should succeed
4. Reload page — saved data should persist
5. Navigate to `http://localhost:4111/settings/account` — should still work
6. Check sidebar — Store should be highlighted when on `/settings/store`

**Step 4: Commit any final fixes**

If any visual tweaks are needed after comparing with Figma, commit them.
