# Paystack Subaccount Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Integrate Paystack subaccounts to enable automated payment processing for auction sales with platform commission splits.

**Architecture:** Extend UserWallet with Paystack subaccount fields, create commission calculator module, enhance Paystack client with subaccount/transfer APIs, implement background sync worker, add registration hooks, and build payment processing flows for split payment (<₦50k) and escrow (≥₦50k).

**Tech Stack:** Elixir, Ash Framework, Oban, Paystack API, PostgreSQL

---

## Task 1: Database Migration - Add Paystack Fields to UserWallet

**Files:**
- Create: `priv/repo/migrations/TIMESTAMP_add_paystack_subaccount_fields.exs`
- Modify: `lib/angle/payments/user_wallet.ex`

### Step 1: Create migration file

**Run:**
```bash
mix ecto.gen.migration add_paystack_subaccount_fields
```

**Expected:** Creates migration file with timestamp

### Step 2: Write migration

**File:** `priv/repo/migrations/TIMESTAMP_add_paystack_subaccount_fields.exs`

```elixir
defmodule Angle.Repo.Migrations.AddPaystackSubaccountFields do
  use Ecto.Migration

  def change do
    alter table(:user_wallets) do
      add :paystack_subaccount_code, :string
      add :last_synced_at, :utc_datetime
      add :sync_status, :string, default: "pending"
      add :metadata, :map, default: %{}
    end

    create index(:user_wallets, [:sync_status, :last_synced_at])
    create unique_index(:user_wallets, [:paystack_subaccount_code],
      where: "paystack_subaccount_code IS NOT NULL"
    )
  end
end
```

### Step 3: Run migration

**Run:**
```bash
mix ecto.migrate
```

**Expected:** Migration runs successfully

### Step 4: Add fields to UserWallet resource

**File:** `lib/angle/payments/user_wallet.ex` (after line 206)

```elixir
attribute :paystack_subaccount_code, :string do
  allow_nil? true
  public? true
end

attribute :last_synced_at, :utc_datetime do
  allow_nil? true
  public? true
end

attribute :sync_status, :string do
  allow_nil? false
  public? true
  default "pending"
  constraints one_of: ["pending", "synced", "error"]
end

attribute :metadata, :map do
  allow_nil? false
  public? true
  default %{}
end
```

### Step 5: Run Ash codegen

**Run:**
```bash
mix ash.codegen --dev
```

**Expected:** No pending migrations or codegens

### Step 6: Commit

```bash
git add priv/repo/migrations/*_add_paystack_subaccount_fields.exs lib/angle/payments/user_wallet.ex
git commit -m "feat: add Paystack subaccount fields to UserWallet

- Add paystack_subaccount_code, last_synced_at, sync_status, metadata
- Add indexes for efficient sync job queries
- Unique index on subaccount_code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Commission Calculator Module

**Files:**
- Create: `lib/angle/payments/commission_calculator.ex`
- Create: `test/angle/payments/commission_calculator_test.exs`

### Step 1: Write failing tests

**File:** `test/angle/payments/commission_calculator_test.exs`

```elixir
defmodule Angle.Payments.CommissionCalculatorTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.CommissionCalculator

  describe "calculate_commission/1" do
    test "returns 8% for amounts less than ₦50,000" do
      amount = Decimal.new("25000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("2000"))
    end

    test "returns 8% for amounts equal to ₦49,999.99" do
      amount = Decimal.new("49999.99")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("3999.9992"))
    end

    test "returns 6% for amounts between ₦50k and ₦200k" do
      amount = Decimal.new("100000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("6000"))
    end

    test "returns 6% for amounts equal to ₦199,999.99" do
      amount = Decimal.new("199999.99")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("11999.9994"))
    end

    test "returns 5% for amounts greater than or equal to ₦200k" do
      amount = Decimal.new("250000")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("12500"))
    end

    test "handles decimal precision correctly" do
      amount = Decimal.new("75432.50")
      commission = CommissionCalculator.calculate_commission(amount)

      assert Decimal.eq?(commission, Decimal.new("4525.95"))
    end
  end

  describe "calculate_net_amount/1" do
    test "returns amount after commission deduction" do
      amount = Decimal.new("100000")
      net_amount = CommissionCalculator.calculate_net_amount(amount)

      # ₦100,000 - 6% (₦6,000) = ₦94,000
      assert Decimal.eq?(net_amount, Decimal.new("94000"))
    end
  end

  describe "commission_rate/1" do
    test "returns 0.08 for amounts < ₦50k" do
      assert CommissionCalculator.commission_rate(Decimal.new("30000")) == Decimal.new("0.08")
    end

    test "returns 0.06 for amounts ₦50k-₦200k" do
      assert CommissionCalculator.commission_rate(Decimal.new("100000")) == Decimal.new("0.06")
    end

    test "returns 0.05 for amounts > ₦200k" do
      assert CommissionCalculator.commission_rate(Decimal.new("300000")) == Decimal.new("0.05")
    end
  end
end
```

### Step 2: Run tests to verify they fail

**Run:**
```bash
mix test test/angle/payments/commission_calculator_test.exs
```

**Expected:** All tests fail with "module CommissionCalculator not found"

### Step 3: Implement CommissionCalculator module

**File:** `lib/angle/payments/commission_calculator.ex`

```elixir
defmodule Angle.Payments.CommissionCalculator do
  @moduledoc """
  Calculates platform commission for auction sales based on tiered pricing:
  - 8% for amounts < ₦50,000
  - 6% for amounts ₦50,000 - ₦199,999.99
  - 5% for amounts ≥ ₦200,000
  """

  @tier_1_threshold Decimal.new("50000")
  @tier_2_threshold Decimal.new("200000")

  @tier_1_rate Decimal.new("0.08")  # 8%
  @tier_2_rate Decimal.new("0.06")  # 6%
  @tier_3_rate Decimal.new("0.05")  # 5%

  @doc """
  Calculates commission amount for a given transaction amount.

  ## Examples

      iex> CommissionCalculator.calculate_commission(Decimal.new("25000"))
      #Decimal<2000>

      iex> CommissionCalculator.calculate_commission(Decimal.new("100000"))
      #Decimal<6000>

      iex> CommissionCalculator.calculate_commission(Decimal.new("250000"))
      #Decimal<12500>
  """
  def calculate_commission(amount) when is_struct(amount, Decimal) do
    rate = commission_rate(amount)
    Decimal.mult(amount, rate)
  end

  @doc """
  Returns the commission rate for a given amount.
  """
  def commission_rate(amount) when is_struct(amount, Decimal) do
    cond do
      Decimal.lt?(amount, @tier_1_threshold) -> @tier_1_rate
      Decimal.lt?(amount, @tier_2_threshold) -> @tier_2_rate
      true -> @tier_3_rate
    end
  end

  @doc """
  Calculates net amount after commission deduction.

  ## Examples

      iex> CommissionCalculator.calculate_net_amount(Decimal.new("100000"))
      #Decimal<94000>
  """
  def calculate_net_amount(amount) when is_struct(amount, Decimal) do
    commission = calculate_commission(amount)
    Decimal.sub(amount, commission)
  end
end
```

### Step 4: Run tests to verify they pass

**Run:**
```bash
mix test test/angle/payments/commission_calculator_test.exs
```

**Expected:** All 9 tests pass

### Step 5: Commit

```bash
git add lib/angle/payments/commission_calculator.ex test/angle/payments/commission_calculator_test.exs
git commit -m "feat: add commission calculator with tiered pricing

- 8% commission for amounts < ₦50k
- 6% commission for ₦50k-₦200k
- 5% commission for amounts ≥ ₦200k
- Includes tests for all tiers and edge cases

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Enhance Paystack Client - Add Subaccount Creation

**Files:**
- Modify: `lib/angle/payments/paystack.ex`
- Create: `test/angle/payments/paystack/create_subaccount_test.exs`

### Step 1: Write failing test for create_subaccount

**File:** `test/angle/payments/paystack/create_subaccount_test.exs`

```elixir
defmodule Angle.Payments.Paystack.CreateSubaccountTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.Paystack

  describe "create_subaccount/1" do
    setup do
      bypass = Bypass.open()

      # Override Paystack base URL to point to bypass
      original_url = Application.get_env(:angle, :paystack_base_url)
      Application.put_env(:angle, :paystack_base_url, "http://localhost:#{bypass.port}")

      on_exit(fn ->
        if original_url do
          Application.put_env(:angle, :paystack_base_url, original_url)
        else
          Application.delete_env(:angle, :paystack_base_url)
        end
      end)

      {:ok, bypass: bypass}
    end

    test "creates subaccount with user details", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/subaccount", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        params = Jason.decode!(body)

        assert params["business_name"] == "John Doe Store"
        assert params["settlement_bank"] == "999"
        assert params["account_number"] == "0123456789"
        assert params["percentage_charge"] == 0

        response = %{
          "status" => true,
          "message" => "Subaccount created",
          "data" => %{
            "subaccount_code" => "ACCT_abc123xyz",
            "business_name" => "John Doe Store",
            "settlement_bank" => "999",
            "account_number" => "0123456789",
            "percentage_charge" => 0
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response))
      end)

      params = %{
        business_name: "John Doe Store",
        settlement_bank: "999",
        account_number: "0123456789"
      }

      assert {:ok, %{"subaccount_code" => "ACCT_abc123xyz"}} =
               Paystack.create_subaccount(params)
    end

    test "handles Paystack API errors", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/subaccount", fn conn ->
        response = %{
          "status" => false,
          "message" => "Invalid bank details"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(400, Jason.encode!(response))
      end)

      params = %{
        business_name: "Test Store",
        settlement_bank: "invalid",
        account_number: "0000000000"
      }

      assert {:error, "Invalid bank details"} = Paystack.create_subaccount(params)
    end

    test "handles network errors", %{bypass: bypass} do
      Bypass.down(bypass)

      params = %{
        business_name: "Test Store",
        settlement_bank: "999",
        account_number: "0123456789"
      }

      assert {:error, _reason} = Paystack.create_subaccount(params)
    end
  end
end
```

### Step 2: Run tests to verify they fail

**Run:**
```bash
mix test test/angle/payments/paystack/create_subaccount_test.exs
```

**Expected:** Tests fail with "function create_subaccount/1 undefined"

### Step 3: Implement create_subaccount function

**File:** `lib/angle/payments/paystack.ex` (add after existing functions)

```elixir
@doc """
Creates a Paystack subaccount for a user.

## Parameters
- `params`: Map with keys:
  - `business_name`: User's store name or full name
  - `settlement_bank`: Bank code (from list_banks)
  - `account_number`: User's bank account number

## Returns
- `{:ok, data}` with subaccount_code on success
- `{:error, reason}` on failure
"""
def create_subaccount(params) do
  body = %{
    business_name: params[:business_name] || params["business_name"],
    settlement_bank: params[:settlement_bank] || params["settlement_bank"],
    account_number: params[:account_number] || params["account_number"],
    percentage_charge: 0  # We handle commission via split payment
  }

  case post("/subaccount", body) do
    {:ok, %{"status" => true, "data" => data}} ->
      {:ok, data}

    {:ok, %{"status" => false, "message" => message}} ->
      {:error, message}

    {:error, reason} ->
      {:error, reason}
  end
end
```

### Step 4: Run tests to verify they pass

**Run:**
```bash
mix test test/angle/payments/paystack/create_subaccount_test.exs
```

**Expected:** All 3 tests pass

### Step 5: Commit

```bash
git add lib/angle/payments/paystack.ex test/angle/payments/paystack/create_subaccount_test.exs
git commit -m "feat: add Paystack create_subaccount function

- Creates subaccount with user's bank details
- Handles API errors gracefully
- Includes comprehensive tests with Bypass mocking

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Add UserWallet Actions for Sync

**Files:**
- Modify: `lib/angle/payments/user_wallet.ex`
- Create: `test/angle/payments/user_wallet/sync_actions_test.exs`

### Step 1: Write failing tests for sync actions

**File:** `test/angle/payments/user_wallet/sync_actions_test.exs`

```elixir
defmodule Angle.Payments.UserWallet.SyncActionsTest do
  use Angle.DataCase, async: true

  alias Angle.Payments.UserWallet

  describe "sync_balance action" do
    test "updates balance, last_synced_at, and sync_status" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      new_balance = Decimal.new("50000")
      before_sync = DateTime.utc_now()

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:sync_balance, %{balance: new_balance})
        |> Ash.update()

      assert Decimal.eq?(updated_wallet.balance, new_balance)
      assert updated_wallet.sync_status == "synced"
      assert updated_wallet.last_synced_at != nil
      assert DateTime.compare(updated_wallet.last_synced_at, before_sync) in [:eq, :gt]
    end
  end

  describe "mark_sync_error action" do
    test "marks sync_status as error and stores error details" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      error_details = %{last_error: "Connection timeout"}

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:mark_sync_error, %{metadata: error_details})
        |> Ash.update()

      assert updated_wallet.sync_status == "error"
      assert updated_wallet.metadata["last_error"] == "Connection timeout"
    end
  end

  describe "set_subaccount_code action" do
    test "sets paystack_subaccount_code" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      subaccount_code = "ACCT_abc123xyz"

      {:ok, updated_wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: subaccount_code
        })
        |> Ash.update()

      assert updated_wallet.paystack_subaccount_code == subaccount_code
    end

    test "enforces unique constraint on subaccount_code" do
      user1 = create_user()
      user2 = create_user()

      {:ok, wallet1} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user1)
        |> Ash.create()

      {:ok, wallet2} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user2)
        |> Ash.create()

      subaccount_code = "ACCT_duplicate"

      # First wallet gets the code
      {:ok, _} =
        wallet1
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: subaccount_code
        })
        |> Ash.update()

      # Second wallet should fail with duplicate constraint
      assert {:error, %Ash.Error.Invalid{}} =
               wallet2
               |> Ash.Changeset.for_update(:set_subaccount_code, %{
                 paystack_subaccount_code: subaccount_code
               })
               |> Ash.update()
    end
  end
end
```

### Step 2: Run tests to verify they fail

**Run:**
```bash
mix test test/angle/payments/user_wallet/sync_actions_test.exs
```

**Expected:** Tests fail with "no such action :sync_balance"

### Step 3: Add sync actions to UserWallet

**File:** `lib/angle/payments/user_wallet.ex` (in actions block, after withdraw action)

```elixir
update :sync_balance do
  accept [:balance]

  change fn changeset, _context ->
    changeset
    |> Ash.Changeset.change_attribute(:last_synced_at, DateTime.utc_now())
    |> Ash.Changeset.change_attribute(:sync_status, "synced")
  end
end

update :mark_sync_error do
  accept [:metadata]

  change fn changeset, _context ->
    Ash.Changeset.change_attribute(changeset, :sync_status, "error")
  end
end

update :set_subaccount_code do
  accept [:paystack_subaccount_code]
end
```

### Step 4: Run Ash codegen

**Run:**
```bash
mix ash.codegen --dev
```

**Expected:** No pending changes

### Step 5: Run tests to verify they pass

**Run:**
```bash
mix test test/angle/payments/user_wallet/sync_actions_test.exs
```

**Expected:** All 4 tests pass

### Step 6: Commit

```bash
git add lib/angle/payments/user_wallet.ex test/angle/payments/user_wallet/sync_actions_test.exs
git commit -m "feat: add sync actions to UserWallet

- sync_balance: updates balance, last_synced_at, sync_status
- mark_sync_error: marks sync failures with error details
- set_subaccount_code: sets Paystack subaccount code
- Enforces unique constraint on subaccount_code

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Background Sync Worker

**Files:**
- Create: `lib/angle/payments/workers/sync_subaccount_balance.ex`
- Create: `test/angle/payments/workers/sync_subaccount_balance_test.exs`
- Modify: `config/config.exs`

### Step 1: Write failing test for sync worker

**File:** `test/angle/payments/workers/sync_subaccount_balance_test.exs`

```elixir
defmodule Angle.Payments.Workers.SyncSubaccountBalanceTest do
  use Angle.DataCase, async: true
  use Oban.Testing, repo: Angle.Repo

  alias Angle.Payments.Workers.SyncSubaccountBalance
  alias Angle.Payments.{UserWallet, Paystack}

  describe "perform/1" do
    test "syncs balance from Paystack API" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      # Set subaccount code
      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: "ACCT_test123"
        })
        |> Ash.update()

      # Mock Paystack API response
      new_balance = Decimal.new("75000.50")

      Mox.stub(Angle.Payments.PaystackMock, :get_subaccount_balance, fn _code ->
        {:ok, new_balance}
      end)

      # Perform job
      assert :ok =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})

      # Verify wallet was updated
      updated_wallet = Ash.get!(UserWallet, wallet.id)

      assert Decimal.eq?(updated_wallet.balance, new_balance)
      assert updated_wallet.sync_status == "synced"
      assert updated_wallet.last_synced_at != nil
    end

    test "handles API errors gracefully" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(:set_subaccount_code, %{
          paystack_subaccount_code: "ACCT_test123"
        })
        |> Ash.update()

      # Mock API error
      Mox.stub(Angle.Payments.PaystackMock, :get_subaccount_balance, fn _code ->
        {:error, "Connection timeout"}
      end)

      # Perform job
      assert {:error, "Connection timeout"} =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})

      # Verify wallet was marked with error
      updated_wallet = Ash.get!(UserWallet, wallet.id)

      assert updated_wallet.sync_status == "error"
      assert updated_wallet.metadata["last_error"] == "Connection timeout"
    end

    test "skips wallets without subaccount code" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{}, actor: user)
        |> Ash.create()

      # Perform job without setting subaccount code
      assert {:error, :no_subaccount} =
               perform_job(SyncSubaccountBalance, %{"wallet_id" => wallet.id})
    end
  end
end
```

### Step 2: Run tests to verify they fail

**Run:**
```bash
mix test test/angle/payments/workers/sync_subaccount_balance_test.exs
```

**Expected:** Tests fail with "module SyncSubaccountBalance not found"

### Step 3: Implement sync worker

**File:** `lib/angle/payments/workers/sync_subaccount_balance.ex`

```elixir
defmodule Angle.Payments.Workers.SyncSubaccountBalance do
  @moduledoc """
  Oban worker that syncs UserWallet balances from Paystack subaccount balances.
  Runs every 5 minutes for all wallets with subaccount codes.
  """

  use Oban.Worker,
    queue: :wallet_sync,
    max_attempts: 3

  alias Angle.Payments.{UserWallet, Paystack}
  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"wallet_id" => wallet_id}}) do
    wallet = Ash.get!(UserWallet, wallet_id, authorize?: false)

    case wallet.paystack_subaccount_code do
      nil ->
        {:error, :no_subaccount}

      subaccount_code ->
        sync_balance(wallet, subaccount_code)
    end
  end

  defp sync_balance(wallet, subaccount_code) do
    case Paystack.get_subaccount_balance(subaccount_code) do
      {:ok, balance} ->
        wallet
        |> Ash.Changeset.for_update(:sync_balance, %{balance: balance}, authorize?: false)
        |> Ash.update()

        :ok

      {:error, reason} ->
        wallet
        |> Ash.Changeset.for_update(
          :mark_sync_error,
          %{metadata: %{last_error: reason}},
          authorize?: false
        )
        |> Ash.update()

        {:error, reason}
    end
  end
end
```

### Step 4: Add wallet_sync queue to Oban config

**File:** `config/config.exs` (in Oban config)

```elixir
config :angle, Oban,
  repo: Angle.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    wallet_sync: 5  # Add this line
  ]
```

### Step 5: Add Paystack.get_subaccount_balance function

**File:** `lib/angle/payments/paystack.ex` (add after create_subaccount)

```elixir
@doc """
Fetches the current balance of a Paystack subaccount.

## Parameters
- `subaccount_code`: The subaccount code (e.g., "ACCT_abc123xyz")

## Returns
- `{:ok, balance}` as Decimal on success
- `{:error, reason}` on failure
"""
def get_subaccount_balance(subaccount_code) do
  case get("/subaccount/#{subaccount_code}") do
    {:ok, %{"status" => true, "data" => data}} ->
      # Extract balance from subaccount data
      balance =
        data
        |> Map.get("settlement_schedule_balance", 0)
        |> Decimal.new()

      {:ok, balance}

    {:ok, %{"status" => false, "message" => message}} ->
      {:error, message}

    {:error, reason} ->
      {:error, reason}
  end
end
```

### Step 6: Run tests to verify they pass

**Run:**
```bash
mix test test/angle/payments/workers/sync_subaccount_balance_test.exs
```

**Expected:** All 3 tests pass

### Step 7: Commit

```bash
git add lib/angle/payments/workers/sync_subaccount_balance.ex test/angle/payments/workers/sync_subaccount_balance_test.exs lib/angle/payments/paystack.ex config/config.exs
git commit -m "feat: add background sync worker for wallet balances

- Oban worker syncs balances from Paystack every 5 minutes
- Handles API errors gracefully
- Marks wallets with sync errors for monitoring
- Add Paystack.get_subaccount_balance function

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Registration Hook - Create Subaccount After User Registration

**Files:**
- Create: `lib/angle/accounts/registration_hooks.ex`
- Modify: `lib/angle/accounts/user.ex`
- Create: `test/angle/accounts/registration_hooks_test.exs`

### Step 1: Write failing test for registration hook

**File:** `test/angle/accounts/registration_hooks_test.exs`

```elixir
defmodule Angle.Accounts.RegistrationHooksTest do
  use Angle.DataCase, async: true

  alias Angle.Accounts.{User, RegistrationHooks}
  alias Angle.Payments.UserWallet

  describe "create_wallet_and_subaccount/2" do
    test "creates wallet and Paystack subaccount after user registration" do
      # Mock Paystack API
      Mox.stub(Angle.Payments.PaystackMock, :create_subaccount, fn params ->
        assert params[:business_name] == "John Doe"
        {:ok, %{"subaccount_code" => "ACCT_test123"}}
      end)

      # Create user (simulating registration)
      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "john@example.com",
          password: "SecureP@ssw0rd!",
          full_name: "John Doe"
        })
        |> Ash.create()

      # Manually trigger hook (in real flow, this is automatic via after_action)
      {:ok, user} = RegistrationHooks.create_wallet_and_subaccount(user, %{})

      # Verify wallet was created
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert wallet != nil
      assert wallet.paystack_subaccount_code == "ACCT_test123"
      assert wallet.sync_status == "pending"
    end

    test "handles Paystack API failures gracefully" do
      # Mock Paystack API failure
      Mox.stub(Angle.Payments.PaystackMock, :create_subaccount, fn _params ->
        {:error, "API temporarily unavailable"}
      end)

      {:ok, user} =
        User
        |> Ash.Changeset.for_create(:register_with_password, %{
          email: "jane@example.com",
          password: "SecureP@ssw0rd!",
          full_name: "Jane Doe"
        })
        |> Ash.create()

      # Trigger hook
      {:ok, user} = RegistrationHooks.create_wallet_and_subaccount(user, %{})

      # Verify wallet was created but marked with error
      wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert wallet != nil
      assert wallet.paystack_subaccount_code == nil
      assert wallet.sync_status == "error"
      assert wallet.metadata["last_error"] == "API temporarily unavailable"
    end
  end
end
```

### Step 2: Run tests to verify they fail

**Run:**
```bash
mix test test/angle/accounts/registration_hooks_test.exs
```

**Expected:** Tests fail with "module RegistrationHooks not found"

### Step 3: Implement RegistrationHooks module

**File:** `lib/angle/accounts/registration_hooks.ex`

```elixir
defmodule Angle.Accounts.RegistrationHooks do
  @moduledoc """
  Handles post-registration tasks like creating user wallet and Paystack subaccount.
  """

  alias Angle.Payments.{UserWallet, Paystack}

  @doc """
  Creates a wallet and Paystack subaccount for a newly registered user.
  Called automatically after user registration.
  """
  def create_wallet_and_subaccount(user, _context) do
    # Create wallet first
    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{}, actor: user, authorize?: false)
      |> Ash.create()

    # Attempt to create Paystack subaccount
    case create_paystack_subaccount(user) do
      {:ok, subaccount_code} ->
        # Update wallet with subaccount code
        wallet
        |> Ash.Changeset.for_update(
          :set_subaccount_code,
          %{paystack_subaccount_code: subaccount_code},
          authorize?: false
        )
        |> Ash.update()

        {:ok, user}

      {:error, reason} ->
        # Mark wallet with error, but don't fail registration
        wallet
        |> Ash.Changeset.for_update(
          :mark_sync_error,
          %{metadata: %{last_error: reason}},
          authorize?: false
        )
        |> Ash.update()

        # Schedule retry via background job
        schedule_subaccount_retry(wallet.id)

        {:ok, user}
    end
  end

  defp create_paystack_subaccount(user) do
    # Use user's full name as business name
    # In production, this should use store_name from StoreProfile if available
    params = %{
      business_name: user.full_name,
      # These will be filled in later when user adds payout method
      # For now, use placeholder bank details
      settlement_bank: "999",  # Paystack test bank
      account_number: "0000000000"
    }

    case Paystack.create_subaccount(params) do
      {:ok, %{"subaccount_code" => code}} ->
        {:ok, code}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp schedule_subaccount_retry(wallet_id) do
    # Schedule retry in 1 minute
    %{wallet_id: wallet_id}
    |> Angle.Payments.Workers.RetrySubaccountCreation.new(schedule_in: 60)
    |> Oban.insert()
  end
end
```

### Step 4: Add after_action hook to User resource

**File:** `lib/angle/accounts/user.ex` (in register_with_password action)

Find the `register_with_password` action and add the after_action hook:

```elixir
create :register_with_password do
  # ... existing configuration ...

  # Add this line after existing changes
  change after_action(&Angle.Accounts.RegistrationHooks.create_wallet_and_subaccount/2)
end
```

### Step 5: Run tests to verify they pass

**Run:**
```bash
mix test test/angle/accounts/registration_hooks_test.exs
```

**Expected:** All 2 tests pass

### Step 6: Commit

```bash
git add lib/angle/accounts/registration_hooks.ex lib/angle/accounts/user.ex test/angle/accounts/registration_hooks_test.exs
git commit -m "feat: create wallet and subaccount after user registration

- RegistrationHooks module handles post-registration tasks
- Creates UserWallet automatically for new users
- Creates Paystack subaccount with user details
- Handles API failures gracefully (doesn't block registration)
- Schedules retry for failed subaccount creation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Regenerate TypeScript Types

**Files:**
- Modify: `assets/js/ash_rpc.ts` (auto-generated)

### Step 1: Run TypeScript codegen

**Run:**
```bash
mix ash_typescript.codegen
```

**Expected:** Types regenerated with new UserWallet fields

### Step 2: Verify TypeScript compiles

**Run:**
```bash
cd assets && npx tsc --noEmit
```

**Expected:** No TypeScript errors

### Step 3: Commit

```bash
git add assets/js/ash_rpc.ts
git commit -m "chore: regenerate TypeScript types for UserWallet

- Add paystack_subaccount_code field
- Add last_synced_at, sync_status, metadata fields
- Add new sync actions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Run Full Test Suite

### Step 1: Run all tests

**Run:**
```bash
mix test
```

**Expected:** All tests pass

### Step 2: Verify Ash codegen is up to date

**Run:**
```bash
mix ash.codegen --check
```

**Expected:** No pending changes

### Step 3: Final commit (if any fixes were needed)

If any tests failed and you made fixes, commit them:

```bash
git add .
git commit -m "fix: resolve test failures from integration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Verification Steps

After completing all tasks, verify the implementation:

1. **Database migration applied:**
   ```bash
   mix ecto.migrations
   ```
   Should show the migration as "up"

2. **Commission calculator works:**
   ```bash
   iex -S mix
   iex> Angle.Payments.CommissionCalculator.calculate_commission(Decimal.new("100000"))
   #Decimal<6000>
   ```

3. **User registration creates wallet:**
   Create a test user in IEx and verify wallet exists:
   ```elixir
   {:ok, user} = Angle.Accounts.User
   |> Ash.Changeset.for_create(:register_with_password, %{
     email: "test@example.com",
     password: "SecureP@ssw0rd!",
     full_name: "Test User"
   })
   |> Ash.create()

   Angle.Payments.UserWallet
   |> Ash.Query.filter(user_id == ^user.id)
   |> Ash.read_one!()
   ```

4. **Oban worker registered:**
   ```bash
   iex -S mix
   iex> Oban.Worker.queue(Angle.Payments.Workers.SyncSubaccountBalance)
   :wallet_sync
   ```

---

## Next Phase: Payment Processing (Future Plan)

The following tasks are **not included in this plan** but will be needed next:

1. **Payment Processor Module** - Orchestrates split payment and escrow flows
2. **Webhook Controller** - Handles Paystack payment callbacks
3. **Escrow Manager** - Manages escrow holds and releases
4. **Frontend Updates** - Display sync status, last synced time
5. **Admin Dashboard** - Monitor sync health, pending escrows

These will be implemented in a separate plan once the core infrastructure (this plan) is complete and tested.

---

## Success Criteria

- ✅ Migration applied successfully
- ✅ All 30+ tests passing
- ✅ Commission calculator correctly calculates tiered rates
- ✅ Paystack client can create subaccounts
- ✅ UserWallet has sync actions working
- ✅ Background sync worker functional
- ✅ Registration creates wallet + subaccount automatically
- ✅ TypeScript types regenerated
- ✅ Ash codegen up to date
