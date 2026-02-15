# Payments Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Payments section to Settings with Paystack-integrated card management, bank account payouts, and auto-charge toggle.

**Architecture:** New `Angle.Payments` domain with PaymentMethod and PayoutMethod resources. Paystack API integration via Req for card tokenization and bank verification. Frontend renders lists, triggers Paystack inline popup for cards, and shows a bank form dialog for payouts.

**Tech Stack:** Ash Framework, Req (HTTP), Paystack REST API + Inline JS, React, shadcn/ui, React Hook Form + Zod, TanStack Query

---

## Task 1: Paystack API Client Module

**Files:**
- Create: `lib/angle/payments/paystack.ex`
- Modify: `config/config.exs` (add paystack config)
- Modify: `config/dev.exs` (add dev key placeholder)
- Modify: `config/runtime.exs` (read from env)
- Modify: `mix.exs` (ensure `req` is a dependency — likely already present)

**What to build:**

`Angle.Payments.Paystack` module with these functions:

```elixir
defmodule Angle.Payments.Paystack do
  @base_url "https://api.paystack.co"

  def initialize_transaction(email, amount_kobo, opts \\ [])
  # POST /transaction/initialize
  # Returns {:ok, %{authorization_url, access_code, reference}} | {:error, reason}

  def verify_transaction(reference)
  # GET /transaction/verify/:reference
  # Returns {:ok, %{status, amount, authorization: %{...}}} | {:error, reason}

  def list_banks()
  # GET /bank
  # Returns {:ok, [%{name, code, ...}]} | {:error, reason}

  def resolve_account(account_number, bank_code)
  # GET /bank/resolve?account_number=X&bank_code=Y
  # Returns {:ok, %{account_number, account_name}} | {:error, reason}

  def create_transfer_recipient(name, account_number, bank_code)
  # POST /transferrecipient
  # Returns {:ok, %{recipient_code, ...}} | {:error, reason}

  defp secret_key(), do: Application.get_env(:angle, :paystack_secret_key)
  defp headers(), do: [{"authorization", "Bearer #{secret_key()}"}, {"content-type", "application/json"}]
end
```

**Config:**
```elixir
# config/config.exs
config :angle, :paystack_secret_key, "sk_test_xxx"

# config/runtime.exs
config :angle, :paystack_secret_key, System.get_env("PAYSTACK_SECRET_KEY") || Application.get_env(:angle, :paystack_secret_key)
```

**Step 1:** Check if `req` is already in mix.exs deps. If not, add it.
**Step 2:** Add Paystack config to config files.
**Step 3:** Create the Paystack module with all 5 functions.
**Step 4:** Verify compilation: `mix compile`

---

## Task 2: PaymentMethod Ash Resource

**Files:**
- Create: `lib/angle/payments/payment_method.ex`
- Create: `lib/angle/payments.ex` (domain)
- Modify: `config/config.exs` (register domain)

**What to build:**

```elixir
defmodule Angle.Payments.PaymentMethod do
  use Ash.Resource,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payment_methods"
    repo Angle.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :card_type, :string, allow_nil?: false
    attribute :last_four, :string, allow_nil?: false
    attribute :exp_month, :string, allow_nil?: false
    attribute :exp_year, :string, allow_nil?: false
    attribute :authorization_code, :string, allow_nil?: false, sensitive?: true
    attribute :bank, :string
    attribute :is_default, :boolean, default: false
    attribute :paystack_reference, :string, allow_nil?: false, sensitive?: true
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User, allow_nil?: false
  end

  identities do
    identity :unique_reference, [:paystack_reference]  # Replay prevention
  end

  actions do
    defaults []

    create :create do
      accept [:card_type, :last_four, :exp_month, :exp_year, :authorization_code, :bank, :is_default, :paystack_reference]
      argument :user_id, :uuid, allow_nil?: false
      change manage_relationship(:user_id, :user, type: :append)
    end

    read :list_by_user do
      filter expr(user_id == ^actor(:id))
      # Only safe fields — authorization_code and paystack_reference excluded via field policy or select
    end

    destroy :destroy do
    end
  end

  policies do
    policy action(:create) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end
    policy action(:list_by_user) do
      authorize_if always()  # Filter already scopes to actor
    end
    policy action(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  field_policies do
    field_policy [:authorization_code, :paystack_reference] do
      authorize_if never()  # Never expose to API consumers
    end
    field_policy :* do
      authorize_if always()
    end
  end
end
```

**Domain:**
```elixir
defmodule Angle.Payments do
  use Ash.Domain

  resources do
    resource Angle.Payments.PaymentMethod
    resource Angle.Payments.PayoutMethod
  end
end
```

**Step 1:** Create the domain module `lib/angle/payments.ex`
**Step 2:** Create the PaymentMethod resource
**Step 3:** Register domain in `config/config.exs` under `ash_domains`
**Step 4:** Run `mix ash.codegen add_payment_methods --dev`
**Step 5:** Run `mix ecto.migrate` to create the table
**Step 6:** Verify: `mix compile`

---

## Task 3: PayoutMethod Ash Resource

**Files:**
- Create: `lib/angle/payments/payout_method.ex`
- Modify: `lib/angle/payments.ex` (add resource)

**What to build:**

```elixir
defmodule Angle.Payments.PayoutMethod do
  use Ash.Resource,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "payout_methods"
    repo Angle.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :bank_name, :string, allow_nil?: false
    attribute :bank_code, :string, allow_nil?: false
    attribute :account_number, :string, allow_nil?: false
    attribute :account_name, :string, allow_nil?: false
    attribute :recipient_code, :string, allow_nil?: false, sensitive?: true
    attribute :is_default, :boolean, default: false
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :user, Angle.Accounts.User, allow_nil?: false
  end

  actions do
    defaults []

    create :create do
      accept [:bank_name, :bank_code, :account_number, :account_name, :recipient_code, :is_default]
      argument :user_id, :uuid, allow_nil?: false
      change manage_relationship(:user_id, :user, type: :append)
    end

    read :list_by_user do
      filter expr(user_id == ^actor(:id))
    end

    destroy :destroy do
    end
  end

  policies do
    policy action(:create) do
      authorize_if expr(^arg(:user_id) == ^actor(:id))
    end
    policy action(:list_by_user) do
      authorize_if always()
    end
    policy action(:destroy) do
      authorize_if expr(user_id == ^actor(:id))
    end
  end

  field_policies do
    field_policy :recipient_code do
      authorize_if never()
    end
    field_policy :* do
      authorize_if always()
    end
  end
end
```

**Step 1:** Create the PayoutMethod resource
**Step 2:** Add to domain resources
**Step 3:** Run `mix ash.codegen add_payout_methods --dev`
**Step 4:** Run `mix ecto.migrate`
**Step 5:** Verify: `mix compile`

---

## Task 4: Add auto_charge to User + Custom Actions

**Files:**
- Modify: `lib/angle/accounts/user.ex` (add auto_charge attribute + update_auto_charge action)
- Create: `lib/angle/payments/changes/initialize_card.ex` (custom change for Paystack init)
- Create: `lib/angle/payments/changes/verify_and_save_card.ex` (custom change for card verification)
- Create: `lib/angle/payments/changes/add_payout.ex` (custom change for bank resolution + recipient)

**auto_charge attribute on User:**
```elixir
attribute :auto_charge, :boolean, default: false
```

**update_auto_charge action on User:**
```elixir
update :update_auto_charge do
  accept [:auto_charge]
end
```

**Custom RPC actions on domain (not on resources — these are multi-step orchestrations):**

We need Phoenix controller actions (not Ash RPC) for the Paystack flows because they involve external API calls + resource creation. The controller will:

1. `initialize_card_charge` — calls Paystack, returns access_code
2. `verify_and_save_card` — verifies transaction, creates PaymentMethod
3. `add_payout_method` — resolves bank, creates recipient, creates PayoutMethod
4. `list_banks` — proxies Paystack bank list (cacheable)

These will be API endpoints in the router, not RPC actions.

**Step 1:** Add `auto_charge` attribute to User resource
**Step 2:** Add `update_auto_charge` action to User
**Step 3:** Register `update_auto_charge` as RPC action in Accounts domain
**Step 4:** Run `mix ash.codegen add_auto_charge --dev`
**Step 5:** Run `mix ecto.migrate`
**Step 6:** Run `mix ash_typescript.codegen`
**Step 7:** Verify: `mix compile`

---

## Task 5: Payment Controller Endpoints

**Files:**
- Create: `lib/angle_web/controllers/payments_controller.ex`
- Modify: `lib/angle_web/router.ex`

**Controller actions:**

```elixir
defmodule AngleWeb.PaymentsController do
  use AngleWeb, :controller

  # POST /api/payments/initialize-card
  def initialize_card(conn, _params)
  # Calls Paystack.initialize_transaction(user.email, 5000)
  # Returns JSON: %{access_code, reference}

  # POST /api/payments/verify-card
  def verify_card(conn, %{"reference" => reference})
  # Calls Paystack.verify_transaction(reference)
  # Validates: status=success, amount=5000, reference not reused
  # Creates PaymentMethod from authorization data
  # Returns JSON: %{success: true, payment_method: safe_fields}

  # DELETE /api/payments/payment-methods/:id
  def delete_payment_method(conn, %{"id" => id})
  # Destroys PaymentMethod (owner-only via policy)

  # POST /api/payments/add-payout
  def add_payout(conn, %{"bank_code" => _, "account_number" => _})
  # Calls Paystack.resolve_account, then create_transfer_recipient
  # Creates PayoutMethod
  # Returns JSON: %{success: true, payout_method: safe_fields}

  # DELETE /api/payments/payout-methods/:id
  def delete_payout_method(conn, %{"id" => id})
  # Destroys PayoutMethod (owner-only via policy)

  # GET /api/payments/banks
  def list_banks(conn, _params)
  # Proxies Paystack.list_banks() — consider caching
  # Returns JSON: %{banks: [%{name, code}]}
end
```

**Routes (under authenticated scope):**
```elixir
scope "/api/payments", AngleWeb do
  pipe_through [:browser, :require_auth]

  post "/initialize-card", PaymentsController, :initialize_card
  post "/verify-card", PaymentsController, :verify_card
  delete "/payment-methods/:id", PaymentsController, :delete_payment_method
  post "/add-payout", PaymentsController, :add_payout
  delete "/payout-methods/:id", PaymentsController, :delete_payout_method
  get "/banks", PaymentsController, :list_banks
end
```

**Step 1:** Create PaymentsController with all 6 actions
**Step 2:** Add routes to router
**Step 3:** Verify: `mix compile`

---

## Task 6: Settings Controller — Payments Page

**Files:**
- Modify: `lib/angle_web/controllers/settings_controller.ex`
- Modify: `lib/angle_web/router.ex`

**New action:**
```elixir
def payments(conn, _params) do
  user = conn.assigns.current_user

  payment_methods = list_payment_methods(user)
  payout_methods = list_payout_methods(user)

  conn
  |> assign_prop(:user, user_payments_data(conn))
  |> assign_prop(:payment_methods, payment_methods)
  |> assign_prop(:payout_methods, payout_methods)
  |> render_inertia("settings/payments")
end
```

Helper functions serialize data for frontend, masking account numbers (e.g., "200956****").

**Route:** `get "/settings/payments", SettingsController, :payments`

**Step 1:** Add `payments` action to SettingsController
**Step 2:** Add helper functions for serialization + masking
**Step 3:** Add route
**Step 4:** Verify: `mix compile`

---

## Task 7: Frontend — Payments Page + Components

**Files:**
- Create: `assets/js/pages/settings/payments.tsx`
- Create: `assets/js/features/settings/components/payment-methods-section.tsx`
- Create: `assets/js/features/settings/components/payout-methods-section.tsx`
- Create: `assets/js/features/settings/components/auto-charge-section.tsx`
- Modify: `assets/js/features/settings/index.ts` (barrel exports)
- Modify: `assets/js/features/settings/components/settings-layout.tsx` (enable Payments)
- Modify: `assets/js/pages/settings/index.tsx` (enable Payments in mobile)

**Payments page:**
```tsx
export default function SettingsPayments({ user, payment_methods, payout_methods }) {
  return (
    <SettingsLayout title="Payments">
      <div className="space-y-8">
        <PaymentMethodsSection methods={payment_methods} userEmail={user.email} />
        <PayoutMethodsSection methods={payout_methods} />
        <AutoChargeSection userId={user.id} autoCharge={user.auto_charge} />
      </div>
    </SettingsLayout>
  );
}
```

**PaymentMethodsSection:**
- Renders list of saved cards (Visa/Mastercard icon, masked number, expiry)
- Kebab menu with "Remove" option
- "+ New Payment Method" button that triggers Paystack inline popup
- On popup success, calls verify-card endpoint, then `router.reload()`

**PayoutMethodsSection:**
- Renders list of saved bank accounts (bank icon, name, masked account number, "default" badge)
- "Remove" link on each
- "+ New Payout Method" opens a dialog/form with bank selector + account number input
- On submit, calls add-payout endpoint, then `router.reload()`

**AutoChargeSection:**
- shadcn Switch component
- Label: "Auto-charge"
- Description: "Your saved payment method would automatically be charged when you win a bid"
- On toggle, calls `updateAutoCharge` RPC via `useAshMutation`, then `router.reload()`

**Paystack Inline JS:**
- Add `<script src="https://js.paystack.co/v2/inline.js">` — load in the payments page or via a custom hook
- Use `resumeTransaction(accessCode, callbacks)` pattern

**Step 1:** Create auto-charge-section.tsx (simplest component)
**Step 2:** Create payment-methods-section.tsx with Paystack integration
**Step 3:** Create payout-methods-section.tsx with bank form dialog
**Step 4:** Create payments.tsx page
**Step 5:** Update barrel exports in index.ts
**Step 6:** Enable Payments in settings-layout.tsx and index.tsx
**Step 7:** Verify: `cd assets && npx tsc --noEmit`

---

## Task 8: Tests

**Files:**
- Create: `test/angle/payments/payment_method_test.exs`
- Create: `test/angle/payments/payout_method_test.exs`
- Create: `test/angle_web/controllers/payments_controller_test.exs`
- Modify: `test/angle_web/controllers/settings_controller_test.exs`
- Modify: `test/support/factory.ex` (add payment/payout factory functions)

**Test coverage:**
1. PaymentMethod resource: create, list_by_user (only own), destroy (only own), field policies (authorization_code never exposed)
2. PayoutMethod resource: create, list_by_user, destroy, field policies (recipient_code never exposed)
3. PaymentsController: initialize-card, verify-card (mock Paystack), delete endpoints, list-banks
4. SettingsController: GET /settings/payments renders, redirects when unauthenticated
5. Security: replay prevention (duplicate reference rejected), cross-user access denied

**Step 1:** Add factory functions
**Step 2:** Write resource tests
**Step 3:** Write controller tests (with Paystack mocking)
**Step 4:** Write settings controller tests
**Step 5:** Verify: `mix test`

---

## Task 9: Browser Verification + Cleanup

**Step 1:** Start server, navigate to /settings/payments
**Step 2:** Verify desktop layout matches Figma
**Step 3:** Verify mobile layout matches Figma
**Step 4:** Test add card flow (with Paystack test keys)
**Step 5:** Test add bank account flow
**Step 6:** Test auto-charge toggle
**Step 7:** Test remove card and remove bank account
**Step 8:** Finalize migrations: `mix ash.codegen finalize_payments`
**Step 9:** Run full test suite: `mix test`
