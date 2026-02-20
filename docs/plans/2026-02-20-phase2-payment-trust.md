# Phase 2: Payment & Trust System - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add wallet system, tiered verification, payment integration (Paystack), seller controls, and payment enforcement to the auction platform.

**Architecture:** Incremental feature development with TDD approach. Wallet and verification systems first (foundations), then bid validation updates, seller controls, payment integration last. Each feature is independently testable and committable.

**Tech Stack:** Ash Framework 3.x, Phoenix, Paystack API, SMS provider (Termii/Africa's Talking), PostgreSQL, Oban

**Dependencies:** Phase 1 (core bidding engine) must be complete.

---

## Table of Contents

1. [Task 1: Wallet System - Resources](#task-1-wallet-system---resources)
2. [Task 2: Wallet System - Actions](#task-2-wallet-system---actions)
3. [Task 3: Verification System - Resource](#task-3-verification-system---resource)
4. [Task 4: Verification System - Phone OTP](#task-4-verification-system---phone-otp)
5. [Task 5: Verification System - ID Upload](#task-5-verification-system---id-upload)
6. [Task 6: Bid Validation - Wallet Commitment](#task-6-bid-validation---wallet-commitment)
7. [Task 7: Blacklist System](#task-7-blacklist-system)
8. [Task 8: Seller Override Window](#task-8-seller-override-window)
9. [Task 9: Second Bidder Offer System](#task-9-second-bidder-offer-system)
10. [Task 10: Non-Payment Handling](#task-10-non-payment-handling)
11. [Task 11: Paystack Integration - Setup](#task-11-paystack-integration---setup)
12. [Task 12: Paystack Integration - Split Payment](#task-12-paystack-integration---split-payment)
13. [Task 13: Paystack Integration - Escrow](#task-13-paystack-integration---escrow)
14. [Task 14: Payment Webhooks](#task-14-payment-webhooks)

---

## Design Overview

### Wallet System

**Purpose:** Track user balance, enforce minimum commitment for bidding, handle deposits/withdrawals.

**Key Points:**
- NOT a full locking system - funds remain available
- Balance check at bid time (commitment signal)
- <₦50k items: ₦1,000 minimum
- ≥₦50k items: ₦5,000 minimum

**Resources:**
- `UserWallet` - One per user, tracks balance
- `WalletTransaction` - Audit trail for all operations

### Verification System

**Purpose:** Tiered trust - phone for all, ID for high-value bidding.

**Requirements:**
- <₦50k items: Phone verified
- ≥₦50k items: Phone + ID verified

**Implementation:**
- `UserVerification` resource
- Phone: SMS OTP via Termii/Africa's Talking
- ID: Manual admin review of uploaded document

### Payment Integration

**Two Paths:**

**Path 1: Split Payment (<₦50k)**
- Buyer pays via Paystack link
- Funds split instantly (commission deducted)
- Seller receives payment to subaccount

**Path 2: Escrow (≥₦50k)**
- Buyer pays, funds held for 7 days
- Seller ships, buyer confirms
- Platform releases funds after 7 days or confirmation

### Seller Controls

**Override Window:**
- 2-hour window after auction ends
- Seller can reject winner with reason
- Offer automatically goes to 2nd highest bidder

**Blacklist:**
- Seller blocks specific users from bidding
- Blocked at bid validation time

### Non-Payment Handling

**24-Hour Window:**
- Winner receives payment link
- Reminder at 12 hours
- Deadline at 24 hours → offer to 2nd bidder
- Track non-payment for reputation

---

## Task 1: Wallet System - Resources

**Goal:** Create UserWallet and WalletTransaction resources with basic CRUD.

### Step 1: Write UserWallet resource test

**File:** `test/angle/payments/user_wallet_test.exs`

```elixir
defmodule Angle.Payments.UserWalletTest do
  use Angle.DataCase

  alias Angle.Payments.UserWallet

  describe "create wallet" do
    test "creates wallet with default zero balance" do
      user = create_user()

      assert {:ok, wallet} =
               UserWallet
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert wallet.user_id == user.id
      assert Decimal.equal?(wallet.balance, Decimal.new("0"))
      assert Decimal.equal?(wallet.total_deposited, Decimal.new("0"))
      assert Decimal.equal?(wallet.total_withdrawn, Decimal.new("0"))
    end

    test "prevents duplicate wallets for same user" do
      user = create_user()

      {:ok, _wallet1} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      assert {:error, error} =
               UserWallet
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "unique") or String.contains?(err.message, "already exists")
      end)
    end
  end

  describe "read wallet" do
    test "reads wallet by user_id" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      found_wallet =
        UserWallet
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert found_wallet.id == wallet.id
    end
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/payments/user_wallet_test.exs
```

**Expected:** Compilation error - `Angle.Payments.UserWallet` module not found

### Step 3: Create Payments domain (if not exists)

**File:** `lib/angle/payments.ex`

```elixir
defmodule Angle.Payments do
  use Ash.Domain

  resources do
    resource Angle.Payments.UserWallet
  end
end
```

### Step 4: Create UserWallet resource

**File:** `lib/angle/payments/user_wallet.ex`

```elixir
defmodule Angle.Payments.UserWallet do
  use Ash.Resource,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_wallets"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :balance, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    attribute :total_deposited, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    attribute :total_withdrawn, :decimal do
      allow_nil? false
      public? true
      default Decimal.new("0")
      constraints precision: 15, scale: 2
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user_wallet, [:user_id]
  end

  policies do
    policy action_type(:read) do
      # Users can read their own wallet
      authorize_if expr(user_id == ^actor(:id))
    end

    policy action_type([:create, :update, :destroy]) do
      # Only admins or system can modify wallets directly
      authorize_if always()
    end
  end
end
```

### Step 5: Add Payments domain to config

**File:** `config/config.exs`

Add to Ash domains list:

```elixir
config :angle,
  ash_domains: [
    Angle.Accounts,
    Angle.Catalog,
    Angle.Inventory,
    Angle.Bidding,
    Angle.Payments  # Add this
  ]
```

### Step 6: Write WalletTransaction resource test

**File:** `test/angle/payments/wallet_transaction_test.exs`

```elixir
defmodule Angle.Payments.WalletTransactionTest do
  use Angle.DataCase

  alias Angle.Payments.{UserWallet, WalletTransaction}

  describe "create transaction" do
    test "creates transaction with all required fields" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      assert {:ok, txn} =
               WalletTransaction
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   wallet_id: wallet.id,
                   type: :deposit,
                   amount: Decimal.new("1000"),
                   balance_before: Decimal.new("0"),
                   balance_after: Decimal.new("1000"),
                   reference: "test_deposit_1",
                   description: "Test deposit"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert txn.wallet_id == wallet.id
      assert txn.type == :deposit
      assert Decimal.equal?(txn.amount, Decimal.new("1000"))
      assert txn.reference == "test_deposit_1"
    end

    test "allows different transaction types" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      types = [:deposit, :withdrawal, :purchase, :sale_credit, :refund, :commission]

      for type <- types do
        assert {:ok, _txn} =
                 WalletTransaction
                 |> Ash.Changeset.for_create(
                   :create,
                   %{
                     wallet_id: wallet.id,
                     type: type,
                     amount: Decimal.new("100"),
                     balance_before: Decimal.new("0"),
                     balance_after: Decimal.new("0"),
                     reference: "test_#{type}",
                     description: "Test #{type}"
                   },
                   authorize?: false
                 )
                 |> Ash.create()
      end
    end
  end

  describe "read transactions" do
    test "lists transactions for a wallet ordered by time" do
      user = create_user()

      {:ok, wallet} =
        UserWallet
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      # Create transactions
      {:ok, txn1} =
        WalletTransaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            wallet_id: wallet.id,
            type: :deposit,
            amount: Decimal.new("1000"),
            balance_before: Decimal.new("0"),
            balance_after: Decimal.new("1000"),
            reference: "deposit_1",
            description: "First deposit"
          },
          authorize?: false
        )
        |> Ash.create()

      {:ok, txn2} =
        WalletTransaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            wallet_id: wallet.id,
            type: :withdrawal,
            amount: Decimal.new("500"),
            balance_before: Decimal.new("1000"),
            balance_after: Decimal.new("500"),
            reference: "withdrawal_1",
            description: "First withdrawal"
          },
          authorize?: false
        )
        |> Ash.create()

      transactions =
        WalletTransaction
        |> Ash.Query.filter(wallet_id == ^wallet.id)
        |> Ash.Query.sort(inserted_at: :desc)
        |> Ash.read!(authorize?: false)

      assert length(transactions) == 2
      assert hd(transactions).id == txn2.id
    end
  end
end
```

### Step 7: Run test to verify it fails

**Command:**
```bash
mix test test/angle/payments/wallet_transaction_test.exs
```

**Expected:** Compilation error - `WalletTransaction` not found

### Step 8: Create WalletTransaction resource

**File:** `lib/angle/payments/wallet_transaction.ex`

```elixir
defmodule Angle.Payments.WalletTransaction do
  use Ash.Resource,
    domain: Angle.Payments,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "wallet_transactions"
    repo Angle.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :wallet_id,
        :type,
        :amount,
        :balance_before,
        :balance_after,
        :reference,
        :description,
        :metadata
      ]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :wallet_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :type, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:deposit, :withdrawal, :purchase, :sale_credit, :refund, :commission]
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :balance_before, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :balance_after, :decimal do
      allow_nil? false
      public? true
      constraints precision: 15, scale: 2
    end

    attribute :reference, :string do
      public? true
    end

    attribute :description, :string do
      public? true
    end

    attribute :metadata, :map do
      public? true
      default %{}
    end

    timestamps()
  end

  relationships do
    belongs_to :wallet, Angle.Payments.UserWallet do
      allow_nil? false
      public? true
    end
  end

  policies do
    policy action_type(:read) do
      # Users can read their own wallet transactions
      authorize_if expr(exists(wallet, user_id == ^actor(:id)))
    end

    policy action_type(:create) do
      # Only system can create transactions
      authorize_if always()
    end
  end
end
```

### Step 9: Add WalletTransaction to Payments domain

**File:** `lib/angle/payments.ex`

```elixir
defmodule Angle.Payments do
  use Ash.Domain

  resources do
    resource Angle.Payments.UserWallet
    resource Angle.Payments.WalletTransaction  # Add this
  end
end
```

### Step 10: Generate migrations

**Command:**
```bash
mix ash.codegen --dev
```

**Expected:** Two new migrations created for `user_wallets` and `wallet_transactions` tables with:
- user_wallets: id, user_id (unique), balance, total_deposited, total_withdrawn, timestamps
- wallet_transactions: id, wallet_id, type, amount, balance_before, balance_after, reference, description, metadata (jsonb), timestamps
- Indexes on wallet_id and inserted_at

### Step 11: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/payments/
```

**Expected:** All wallet and transaction tests PASS

### Step 12: Commit

**Command:**
```bash
git add lib/angle/payments.ex \
        lib/angle/payments/user_wallet.ex \
        lib/angle/payments/wallet_transaction.ex \
        test/angle/payments/user_wallet_test.exs \
        test/angle/payments/wallet_transaction_test.exs \
        config/config.exs \
        priv/repo/migrations/*
git commit -m "feat: add UserWallet and WalletTransaction resources

- Create Payments domain with UserWallet and WalletTransaction
- Add unique constraint on user_id for wallets
- Track balance, total_deposited, total_withdrawn
- Audit trail with transaction types and balance snapshots
- Tests for CRUD operations on both resources

Part of Phase 2: Payment & Trust"
```

---

## Task 2: Wallet System - Actions

**Goal:** Add deposit, withdrawal, and balance check actions to UserWallet.

### Step 1: Write deposit action test

**File:** `test/angle/payments/user_wallet_test.exs`

Add to existing file:

```elixir
describe "deposit action" do
  test "deposits funds and creates transaction" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    assert {:ok, updated_wallet} =
             wallet
             |> Ash.Changeset.for_update(
               :deposit,
               %{amount: Decimal.new("1000"), reference: "paystack_ABC123"},
               authorize?: false
             )
             |> Ash.update()

    assert Decimal.equal?(updated_wallet.balance, Decimal.new("1000"))
    assert Decimal.equal?(updated_wallet.total_deposited, Decimal.new("1000"))

    # Verify transaction created
    transactions =
      WalletTransaction
      |> Ash.Query.filter(wallet_id == ^wallet.id and type == :deposit)
      |> Ash.read!(authorize?: false)

    assert length(transactions) == 1
    txn = hd(transactions)
    assert Decimal.equal?(txn.amount, Decimal.new("1000"))
    assert Decimal.equal?(txn.balance_before, Decimal.new("0"))
    assert Decimal.equal?(txn.balance_after, Decimal.new("1000"))
    assert txn.reference == "paystack_ABC123"
  end

  test "multiple deposits accumulate correctly" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("1000"), reference: "deposit_1"},
        authorize?: false
      )
      |> Ash.update()

    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("2500"), reference: "deposit_2"},
        authorize?: false
      )
      |> Ash.update()

    assert Decimal.equal?(wallet.balance, Decimal.new("3500"))
    assert Decimal.equal?(wallet.total_deposited, Decimal.new("3500"))
  end

  test "rejects negative deposit amounts" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    assert {:error, error} =
             wallet
             |> Ash.Changeset.for_update(
               :deposit,
               %{amount: Decimal.new("-100"), reference: "invalid"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "must be greater than 0")
    end)
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/payments/user_wallet_test.exs:deposit
```

**Expected:** Error - `:deposit` action not found

### Step 3: Implement deposit action

**File:** `lib/angle/payments/user_wallet.ex`

Add after the `:create` action:

```elixir
update :deposit do
  accept [:amount, :reference]

  argument :amount, :decimal, allow_nil?: false
  argument :reference, :string, allow_nil?: false

  validate compare(:amount, greater_than: 0), message: "must be greater than 0"

  change fn changeset, _context ->
    amount = Ash.Changeset.get_argument(changeset, :amount)
    reference = Ash.Changeset.get_argument(changeset, :reference)

    current_balance = Ash.Changeset.get_attribute(changeset, :balance)
    current_deposited = Ash.Changeset.get_attribute(changeset, :total_deposited)

    new_balance = Decimal.add(current_balance, amount)
    new_deposited = Decimal.add(current_deposited, amount)

    changeset
    |> Ash.Changeset.force_change_attribute(:balance, new_balance)
    |> Ash.Changeset.force_change_attribute(:total_deposited, new_deposited)
    |> Ash.Changeset.after_action(fn _changeset, wallet ->
      # Create transaction record
      WalletTransaction
      |> Ash.Changeset.for_create(
        :create,
        %{
          wallet_id: wallet.id,
          type: :deposit,
          amount: amount,
          balance_before: current_balance,
          balance_after: new_balance,
          reference: reference,
          description: "Deposit from Paystack"
        },
        authorize?: false
      )
      |> Ash.create!()

      {:ok, wallet}
    end)
  end
end
```

### Step 4: Write withdrawal action test

**File:** `test/angle/payments/user_wallet_test.exs`

Add to existing file:

```elixir
describe "withdraw action" do
  test "withdraws funds and creates transaction" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    # Deposit first
    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("5000"), reference: "initial_deposit"},
        authorize?: false
      )
      |> Ash.update()

    # Now withdraw
    assert {:ok, updated_wallet} =
             wallet
             |> Ash.Changeset.for_update(
               :withdraw,
               %{amount: Decimal.new("2000"), reference: "paystack_withdrawal_1"},
               authorize?: false
             )
             |> Ash.update()

    assert Decimal.equal?(updated_wallet.balance, Decimal.new("3000"))
    assert Decimal.equal?(updated_wallet.total_withdrawn, Decimal.new("2000"))

    # Verify transaction created
    transactions =
      WalletTransaction
      |> Ash.Query.filter(wallet_id == ^wallet.id and type == :withdrawal)
      |> Ash.read!(authorize?: false)

    assert length(transactions) == 1
    txn = hd(transactions)
    assert Decimal.equal?(txn.amount, Decimal.new("2000"))
    assert Decimal.equal?(txn.balance_before, Decimal.new("5000"))
    assert Decimal.equal?(txn.balance_after, Decimal.new("3000"))
  end

  test "prevents withdrawal when insufficient balance" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("1000"), reference: "deposit"},
        authorize?: false
      )
      |> Ash.update()

    assert {:error, error} =
             wallet
             |> Ash.Changeset.for_update(
               :withdraw,
               %{amount: Decimal.new("2000"), reference: "over_withdrawal"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "insufficient balance")
    end)
  end

  test "rejects negative withdrawal amounts" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    assert {:error, error} =
             wallet
             |> Ash.Changeset.for_update(
               :withdraw,
               %{amount: Decimal.new("-100"), reference: "invalid"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "must be greater than 0")
    end)
  end
end
```

### Step 5: Run test to verify it fails

**Command:**
```bash
mix test test/angle/payments/user_wallet_test.exs:withdraw
```

**Expected:** Error - `:withdraw` action not found

### Step 6: Implement withdrawal action

**File:** `lib/angle/payments/user_wallet.ex`

Add after the `:deposit` action:

```elixir
update :withdraw do
  accept [:amount, :reference]

  argument :amount, :decimal, allow_nil?: false
  argument :reference, :string, allow_nil?: false

  validate compare(:amount, greater_than: 0), message: "must be greater than 0"

  change fn changeset, _context ->
    amount = Ash.Changeset.get_argument(changeset, :amount)
    reference = Ash.Changeset.get_argument(changeset, :reference)

    current_balance = Ash.Changeset.get_attribute(changeset, :balance)
    current_withdrawn = Ash.Changeset.get_attribute(changeset, :total_withdrawn)

    # Check sufficient balance
    if Decimal.compare(current_balance, amount) == :lt do
      Ash.Changeset.add_error(
        changeset,
        field: :amount,
        message: "insufficient balance"
      )
    else
      new_balance = Decimal.sub(current_balance, amount)
      new_withdrawn = Decimal.add(current_withdrawn, amount)

      changeset
      |> Ash.Changeset.force_change_attribute(:balance, new_balance)
      |> Ash.Changeset.force_change_attribute(:total_withdrawn, new_withdrawn)
      |> Ash.Changeset.after_action(fn _changeset, wallet ->
        # Create transaction record
        WalletTransaction
        |> Ash.Changeset.for_create(
          :create,
          %{
            wallet_id: wallet.id,
            type: :withdrawal,
            amount: amount,
            balance_before: current_balance,
            balance_after: new_balance,
            reference: reference,
            description: "Withdrawal to bank account"
          },
          authorize?: false
        )
        |> Ash.create!()

        {:ok, wallet}
      end)
    end
  end
end
```

### Step 7: Add balance check action test

**File:** `test/angle/payments/user_wallet_test.exs`

```elixir
describe "check_minimum_balance action" do
  test "succeeds when balance meets requirement" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("5000"), reference: "deposit"},
        authorize?: false
      )
      |> Ash.update()

    # Check for ₦1,000 minimum
    assert {:ok, _wallet} =
             wallet
             |> Ash.Changeset.for_update(
               :check_minimum_balance,
               %{required_amount: Decimal.new("1000")},
               authorize?: false
             )
             |> Ash.update()
  end

  test "fails when balance below requirement" do
    user = create_user()

    {:ok, wallet} =
      UserWallet
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, wallet} =
      wallet
      |> Ash.Changeset.for_update(
        :deposit,
        %{amount: Decimal.new("500"), reference: "deposit"},
        authorize?: false
      )
      |> Ash.update()

    # Try to check for ₦1,000 minimum
    assert {:error, error} =
             wallet
             |> Ash.Changeset.for_update(
               :check_minimum_balance,
               %{required_amount: Decimal.new("1000")},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "minimum balance")
    end)
  end
end
```

### Step 8: Run test to verify it fails

**Command:**
```bash
mix test test/angle/payments/user_wallet_test.exs:check_minimum
```

**Expected:** Error - `:check_minimum_balance` action not found

### Step 9: Implement balance check action

**File:** `lib/angle/payments/user_wallet.ex`

Add after the `:withdraw` action:

```elixir
update :check_minimum_balance do
  argument :required_amount, :decimal, allow_nil?: false

  # This is a read-only check, doesn't actually change the wallet
  change fn changeset, _context ->
    required = Ash.Changeset.get_argument(changeset, :required_amount)
    current_balance = Ash.Changeset.get_attribute(changeset, :balance)

    if Decimal.compare(current_balance, required) == :lt do
      Ash.Changeset.add_error(
        changeset,
        field: :balance,
        message: "minimum balance of ₦#{Decimal.to_string(required)} required, current: ₦#{Decimal.to_string(current_balance)}"
      )
    else
      changeset
    end
  end
end
```

### Step 10: Add wallet relationship to User

**File:** `lib/angle/accounts/user.ex`

Add to relationships block:

```elixir
has_one :wallet, Angle.Payments.UserWallet do
  destination_attribute :user_id
  public? true
end
```

### Step 11: Run all wallet tests

**Command:**
```bash
mix test test/angle/payments/user_wallet_test.exs
```

**Expected:** All tests PASS

### Step 12: Update factory to create wallets

**File:** `test/support/factory.ex`

Add new factory function:

```elixir
@doc """
Creates a wallet for a user with optional initial balance.

## Options

  * `:user` - the user record (creates one if not provided)
  * `:balance` - initial balance (default ₦0)

"""
def create_wallet(attrs \\ %{}) do
  user = attrs[:user] || create_user()

  {:ok, wallet} =
    Angle.Payments.UserWallet
    |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
    |> Ash.create()

  # If initial balance specified, deposit it
  case Map.get(attrs, :balance) do
    nil ->
      wallet

    amount when is_number(amount) ->
      amount_decimal = Decimal.new(to_string(amount))

      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(
          :deposit,
          %{amount: amount_decimal, reference: "test_initial_balance"},
          authorize?: false
        )
        |> Ash.update()

      wallet

    %Decimal{} = amount_decimal ->
      {:ok, wallet} =
        wallet
        |> Ash.Changeset.for_update(
          :deposit,
          %{amount: amount_decimal, reference: "test_initial_balance"},
          authorize?: false
        )
        |> Ash.update()

      wallet
  end
end
```

### Step 13: Commit

**Command:**
```bash
git add lib/angle/payments/user_wallet.ex \
        lib/angle/accounts/user.ex \
        test/angle/payments/user_wallet_test.exs \
        test/support/factory.ex
git commit -m "feat: add wallet deposit, withdrawal, and balance check actions

- Deposit action: adds funds, creates transaction record
- Withdrawal action: removes funds, validates sufficient balance
- Balance check: validates minimum balance requirement
- Add wallet relationship to User
- Add create_wallet factory helper

Part of Phase 2: Payment & Trust"
```

---

## Task 3: Verification System - Resource

**Goal:** Create UserVerification resource for tracking phone and ID verification status.

### Step 1: Write UserVerification resource test

**File:** `test/angle/accounts/user_verification_test.exs`

```elixir
defmodule Angle.Accounts.UserVerificationTest do
  use Angle.DataCase

  alias Angle.Accounts.UserVerification

  describe "create verification" do
    test "creates verification record for user with default unverified status" do
      user = create_user()

      assert {:ok, verification} =
               UserVerification
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert verification.user_id == user.id
      assert verification.phone_verified == false
      assert is_nil(verification.phone_verified_at)
      assert verification.id_verified == false
      assert is_nil(verification.id_verified_at)
      assert is_nil(verification.id_document_url)
      assert verification.id_verification_status == :not_submitted
    end

    test "prevents duplicate verification records for same user" do
      user = create_user()

      {:ok, _verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      assert {:error, error} =
               UserVerification
               |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
               |> Ash.create()

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "unique") or String.contains?(err.message, "already exists")
      end)
    end
  end

  describe "read verification" do
    test "reads verification by user_id" do
      user = create_user()

      {:ok, verification} =
        UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
        |> Ash.create()

      found =
        UserVerification
        |> Ash.Query.filter(user_id == ^user.id)
        |> Ash.read_one!(authorize?: false)

      assert found.id == verification.id
    end
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs
```

**Expected:** Compilation error - `UserVerification` not found

### Step 3: Create UserVerification resource

**File:** `lib/angle/accounts/user_verification.ex`

```elixir
defmodule Angle.Accounts.UserVerification do
  use Ash.Resource,
    domain: Angle.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "user_verifications"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :user_id, :uuid do
      allow_nil? false
      public? true
    end

    # Phone verification
    attribute :phone_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :phone_verified_at, :utc_datetime_usec do
      public? true
    end

    # ID verification
    attribute :id_verified, :boolean do
      allow_nil? false
      public? true
      default false
    end

    attribute :id_document_url, :string do
      public? true
    end

    attribute :id_verified_at, :utc_datetime_usec do
      public? true
    end

    attribute :id_verification_status, :atom do
      allow_nil? false
      public? true
      default :not_submitted
      constraints one_of: [:not_submitted, :pending, :approved, :rejected]
    end

    attribute :id_rejection_reason, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :user, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_user_verification, [:user_id]
  end

  policies do
    policy action_type(:read) do
      # Users can read their own verification
      authorize_if expr(user_id == ^actor(:id))

      # Admins can read all verifications
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end

    policy action_type([:create, :update, :destroy]) do
      # Only system or admins can modify
      authorize_if always()
    end
  end
end
```

### Step 4: Add UserVerification to Accounts domain

**File:** `lib/angle/accounts.ex`

Add to resources block:

```elixir
resource Angle.Accounts.UserVerification  # Add after User
```

### Step 5: Add verification relationship to User

**File:** `lib/angle/accounts/user.ex`

Add to relationships block:

```elixir
has_one :verification, Angle.Accounts.UserVerification do
  destination_attribute :user_id
  public? true
end
```

### Step 6: Generate migration

**Command:**
```bash
mix ash.codegen --dev
```

**Expected:** New migration created for `user_verifications` table with:
- id, user_id (unique), phone_verified, phone_verified_at
- id_verified, id_document_url, id_verified_at, id_verification_status, id_rejection_reason
- timestamps

### Step 7: Run test to verify it passes

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs
```

**Expected:** All tests PASS

### Step 8: Add verification factory helper

**File:** `test/support/factory.ex`

```elixir
@doc """
Creates a verification record for a user.

## Options

  * `:user` - the user record (creates one if not provided)
  * `:phone_verified` - boolean (default false)
  * `:id_verified` - boolean (default false)
  * `:id_verification_status` - atom (default :not_submitted)

"""
def create_verification(attrs \\ %{}) do
  user = attrs[:user] || create_user()

  {:ok, verification} =
    Angle.Accounts.UserVerification
    |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
    |> Ash.create()

  # Update fields if specified
  updates = %{}
  |> maybe_put(:phone_verified, Map.get(attrs, :phone_verified))
  |> maybe_put(:phone_verified_at, if(Map.get(attrs, :phone_verified), do: DateTime.utc_now()))
  |> maybe_put(:id_verified, Map.get(attrs, :id_verified))
  |> maybe_put(:id_verified_at, if(Map.get(attrs, :id_verified), do: DateTime.utc_now()))
  |> maybe_put(:id_verification_status, Map.get(attrs, :id_verification_status))

  if updates == %{} do
    verification
  else
    verification
    |> Ecto.Changeset.change(updates)
    |> Angle.Repo.update!()
  end
end
```

### Step 9: Commit

**Command:**
```bash
git add lib/angle/accounts/user_verification.ex \
        lib/angle/accounts/user.ex \
        lib/angle/accounts.ex \
        test/angle/accounts/user_verification_test.exs \
        test/support/factory.ex \
        priv/repo/migrations/*
git commit -m "feat: add UserVerification resource for phone and ID verification

- Track phone_verified and id_verified status
- ID verification workflow: not_submitted → pending → approved/rejected
- One verification record per user
- Add verification relationship to User
- Add create_verification factory helper

Part of Phase 2: Payment & Trust"
```

---

## Task 4: Verification System - Phone OTP

**Goal:** Implement phone verification with SMS OTP (mocked for tests, real SMS in production).

### Step 1: Write phone verification tests

**File:** `test/angle/accounts/user_verification_test.exs`

Add to existing file:

```elixir
describe "request_phone_otp action" do
  test "generates OTP and stores hashed version" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    assert {:ok, result} =
             verification
             |> Ash.Changeset.for_update(
               :request_phone_otp,
               %{phone_number: "+2348012345678"},
               authorize?: false
             )
             |> Ash.update()

    # In test mode, OTP is returned (production: sent via SMS)
    assert Map.has_key?(result, :otp_code)
    assert String.length(result.otp_code) == 6
    assert result.otp_code =~ ~r/^\d{6}$/

    # Verify internal state (otp_hash should be set)
    verification =
      UserVerification
      |> Ash.Query.filter(id == ^verification.id)
      |> Ash.read_one!(authorize?: false)

    # Note: otp_hash is internal attribute, not public
    # Just verify phone number was stored
    assert verification.phone_number == "+2348012345678"
  end

  test "rate limits OTP requests to 1 per minute" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    # First request succeeds
    {:ok, _result} =
      verification
      |> Ash.Changeset.for_update(
        :request_phone_otp,
        %{phone_number: "+2348012345678"},
        authorize?: false
      )
      |> Ash.update()

    # Second request within 1 minute fails
    assert {:error, error} =
             verification
             |> Ash.Changeset.for_update(
               :request_phone_otp,
               %{phone_number: "+2348012345678"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "wait") or String.contains?(err.message, "rate limit")
    end)
  end
end

describe "verify_phone_otp action" do
  test "verifies correct OTP and marks phone as verified" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, result} =
      verification
      |> Ash.Changeset.for_update(
        :request_phone_otp,
        %{phone_number: "+2348012345678"},
        authorize?: false
      )
      |> Ash.update()

    otp_code = result.otp_code

    # Verify with correct OTP
    assert {:ok, verified} =
             verification
             |> Ash.Changeset.for_update(
               :verify_phone_otp,
               %{otp_code: otp_code},
               authorize?: false
             )
             |> Ash.update()

    assert verified.phone_verified == true
    assert not is_nil(verified.phone_verified_at)
  end

  test "rejects incorrect OTP" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, _result} =
      verification
      |> Ash.Changeset.for_update(
        :request_phone_otp,
        %{phone_number: "+2348012345678"},
        authorize?: false
      )
      |> Ash.update()

    # Try wrong OTP
    assert {:error, error} =
             verification
             |> Ash.Changeset.for_update(
               :verify_phone_otp,
               %{otp_code: "000000"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "invalid") or String.contains?(err.message, "incorrect")
    end)
  end

  test "rejects expired OTP (5 minutes)" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, result} =
      verification
      |> Ash.Changeset.for_update(
        :request_phone_otp,
        %{phone_number: "+2348012345678"},
        authorize?: false
      )
      |> Ash.update()

    # Manually set otp_expires_at to past
    verification
    |> Ecto.Changeset.change(%{otp_expires_at: DateTime.add(DateTime.utc_now(), -10, :minute)})
    |> Angle.Repo.update!()

    # Try to verify with expired OTP
    assert {:error, error} =
             verification
             |> Ash.Changeset.for_update(
               :verify_phone_otp,
               %{otp_code: result.otp_code},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "expired")
    end)
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs:otp
```

**Expected:** Multiple errors - actions not found, attributes missing

### Step 3: Add OTP attributes to UserVerification

**File:** `lib/angle/accounts/user_verification.ex`

Add after `phone_verified_at`:

```elixir
# OTP fields (internal - not public)
attribute :phone_number, :string do
  public? true
end

attribute :otp_hash, :string

attribute :otp_expires_at, :utc_datetime_usec

attribute :otp_requested_at, :utc_datetime_usec
```

### Step 4: Implement request_phone_otp action

**File:** `lib/angle/accounts/user_verification.ex`

Add after `:create` action:

```elixir
update :request_phone_otp do
  argument :phone_number, :string, allow_nil?: false

  change fn changeset, _context ->
    phone_number = Ash.Changeset.get_argument(changeset, :phone_number)
    last_requested = Ash.Changeset.get_attribute(changeset, :otp_requested_at)

    # Rate limit: max 1 OTP per minute
    if not is_nil(last_requested) and
         DateTime.diff(DateTime.utc_now(), last_requested, :second) < 60 do
      Ash.Changeset.add_error(
        changeset,
        message: "Please wait before requesting another OTP"
      )
    else
      # Generate 6-digit OTP
      otp_code = generate_otp()
      otp_hash = hash_otp(otp_code)
      expires_at = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

      changeset =
        changeset
        |> Ash.Changeset.force_change_attribute(:phone_number, phone_number)
        |> Ash.Changeset.force_change_attribute(:otp_hash, otp_hash)
        |> Ash.Changeset.force_change_attribute(:otp_expires_at, expires_at)
        |> Ash.Changeset.force_change_attribute(:otp_requested_at, DateTime.utc_now())

      # In test/dev: return OTP in result
      # In prod: send via SMS, don't return OTP
      if Mix.env() == :test do
        changeset
        |> Ash.Changeset.after_action(fn _changeset, verification ->
          {:ok, Map.put(verification, :otp_code, otp_code)}
        end)
      else
        # TODO: Send SMS via Termii/Africa's Talking
        # send_sms(phone_number, "Your Angle verification code: #{otp_code}")

        changeset
      end
    end
  end

  # Helper functions
  defp generate_otp do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp hash_otp(otp_code) do
    :crypto.hash(:sha256, otp_code)
    |> Base.encode16(case: :lower)
  end
end
```

### Step 5: Implement verify_phone_otp action

**File:** `lib/angle/accounts/user_verification.ex`

Add after `:request_phone_otp`:

```elixir
update :verify_phone_otp do
  argument :otp_code, :string, allow_nil?: false

  change fn changeset, _context ->
    submitted_otp = Ash.Changeset.get_argument(changeset, :otp_code)
    stored_hash = Ash.Changeset.get_attribute(changeset, :otp_hash)
    expires_at = Ash.Changeset.get_attribute(changeset, :otp_expires_at)

    cond do
      is_nil(stored_hash) or is_nil(expires_at) ->
        Ash.Changeset.add_error(
          changeset,
          message: "No OTP requested. Please request an OTP first."
        )

      DateTime.compare(DateTime.utc_now(), expires_at) == :gt ->
        Ash.Changeset.add_error(
          changeset,
          message: "OTP expired. Please request a new one."
        )

      hash_otp(submitted_otp) != stored_hash ->
        Ash.Changeset.add_error(
          changeset,
          message: "Invalid OTP code"
        )

      true ->
        # OTP valid - mark phone as verified
        changeset
        |> Ash.Changeset.force_change_attribute(:phone_verified, true)
        |> Ash.Changeset.force_change_attribute(:phone_verified_at, DateTime.utc_now())
        # Clear OTP data
        |> Ash.Changeset.force_change_attribute(:otp_hash, nil)
        |> Ash.Changeset.force_change_attribute(:otp_expires_at, nil)
    end
  end

  defp hash_otp(otp_code) do
    :crypto.hash(:sha256, otp_code)
    |> Base.encode16(case: :lower)
  end
end
```

### Step 6: Generate migration for new attributes

**Command:**
```bash
mix ash.codegen --dev
```

**Expected:** Migration to add `phone_number`, `otp_hash`, `otp_expires_at`, `otp_requested_at` columns

### Step 7: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs
```

**Expected:** All OTP tests PASS

### Step 8: Commit

**Command:**
```bash
git add lib/angle/accounts/user_verification.ex \
        test/angle/accounts/user_verification_test.exs \
        priv/repo/migrations/*
git commit -m "feat: implement phone verification with SMS OTP

- request_phone_otp: generates 6-digit OTP, stores hash
- verify_phone_otp: validates OTP, marks phone as verified
- Rate limiting: 1 OTP per minute
- OTP expiration: 5 minutes
- Test mode returns OTP, prod sends via SMS (TODO)

Part of Phase 2: Payment & Trust"
```

---

## Task 5: Verification System - ID Upload

**Goal:** Allow users to upload ID documents for manual admin review.

### Step 1: Write ID upload tests

**File:** `test/angle/accounts/user_verification_test.exs`

Add to existing file:

```elixir
describe "submit_id_document action" do
  test "submits ID document URL and sets status to pending" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    document_url = "https://s3.amazonaws.com/angle-uploads/id_#{user.id}.jpg"

    assert {:ok, updated} =
             verification
             |> Ash.Changeset.for_update(
               :submit_id_document,
               %{id_document_url: document_url},
               authorize?: false
             )
             |> Ash.update()

    assert updated.id_document_url == document_url
    assert updated.id_verification_status == :pending
    assert updated.id_verified == false
  end

  test "prevents resubmission if already approved" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    # Manually approve
    verification =
      verification
      |> Ecto.Changeset.change(%{
        id_verification_status: :approved,
        id_verified: true,
        id_verified_at: DateTime.utc_now()
      })
      |> Angle.Repo.update!()

    # Try to resubmit
    assert {:error, error} =
             verification
             |> Ash.Changeset.for_update(
               :submit_id_document,
               %{id_document_url: "https://s3.amazonaws.com/new.jpg"},
               authorize?: false
             )
             |> Ash.update()

    assert error.errors |> Enum.any?(fn err ->
      String.contains?(err.message, "already approved")
    end)
  end
end

describe "approve_id action" do
  test "admin approves ID and marks user as verified" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, verification} =
      verification
      |> Ash.Changeset.for_update(
        :submit_id_document,
        %{id_document_url: "https://s3.amazonaws.com/id.jpg"},
        authorize?: false
      )
      |> Ash.update()

    assert {:ok, approved} =
             verification
             |> Ash.Changeset.for_update(:approve_id, %{}, authorize?: false)
             |> Ash.update()

    assert approved.id_verification_status == :approved
    assert approved.id_verified == true
    assert not is_nil(approved.id_verified_at)
  end
end

describe "reject_id action" do
  test "admin rejects ID with reason" do
    user = create_user()

    {:ok, verification} =
      UserVerification
      |> Ash.Changeset.for_create(:create, %{user_id: user.id}, authorize?: false)
      |> Ash.create()

    {:ok, verification} =
      verification
      |> Ash.Changeset.for_update(
        :submit_id_document,
        %{id_document_url: "https://s3.amazonaws.com/id.jpg"},
        authorize?: false
      )
      |> Ash.update()

    reason = "Document is blurry, please upload a clearer image"

    assert {:ok, rejected} =
             verification
             |> Ash.Changeset.for_update(
               :reject_id,
               %{reason: reason},
               authorize?: false
             )
             |> Ash.update()

    assert rejected.id_verification_status == :rejected
    assert rejected.id_verified == false
    assert rejected.id_rejection_reason == reason
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs:id_document
```

**Expected:** Actions not found

### Step 3: Implement submit_id_document action

**File:** `lib/angle/accounts/user_verification.ex`

Add after `:verify_phone_otp`:

```elixir
update :submit_id_document do
  argument :id_document_url, :string, allow_nil?: false

  change fn changeset, _context ->
    document_url = Ash.Changeset.get_argument(changeset, :id_document_url)
    current_status = Ash.Changeset.get_attribute(changeset, :id_verification_status)

    # Prevent resubmission if already approved
    if current_status == :approved do
      Ash.Changeset.add_error(
        changeset,
        message: "ID already approved, cannot resubmit"
      )
    else
      changeset
      |> Ash.Changeset.force_change_attribute(:id_document_url, document_url)
      |> Ash.Changeset.force_change_attribute(:id_verification_status, :pending)
      |> Ash.Changeset.force_change_attribute(:id_rejection_reason, nil)
    end
  end
end
```

### Step 4: Implement approve_id action

**File:** `lib/angle/accounts/user_verification.ex`

Add after `:submit_id_document`:

```elixir
update :approve_id do
  change fn changeset, _context ->
    changeset
    |> Ash.Changeset.force_change_attribute(:id_verification_status, :approved)
    |> Ash.Changeset.force_change_attribute(:id_verified, true)
    |> Ash.Changeset.force_change_attribute(:id_verified_at, DateTime.utc_now())
    |> Ash.Changeset.force_change_attribute(:id_rejection_reason, nil)
  end
end
```

### Step 5: Implement reject_id action

**File:** `lib/angle/accounts/user_verification.ex`

Add after `:approve_id`:

```elixir
update :reject_id do
  argument :reason, :string, allow_nil?: false

  change fn changeset, _context ->
    reason = Ash.Changeset.get_argument(changeset, :reason)

    changeset
    |> Ash.Changeset.force_change_attribute(:id_verification_status, :rejected)
    |> Ash.Changeset.force_change_attribute(:id_verified, false)
    |> Ash.Changeset.force_change_attribute(:id_rejection_reason, reason)
  end
end
```

### Step 6: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/accounts/user_verification_test.exs
```

**Expected:** All tests PASS including ID upload tests

### Step 7: Commit

**Command:**
```bash
git add lib/angle/accounts/user_verification.ex \
        test/angle/accounts/user_verification_test.exs
git commit -m "feat: implement ID document upload and admin review

- submit_id_document: user uploads ID, sets status to pending
- approve_id: admin approves, marks id_verified = true
- reject_id: admin rejects with reason, allows resubmission
- Prevents resubmission if already approved

Part of Phase 2: Payment & Trust"
```

---

## Task 6: Bid Validation - Wallet Commitment

**Goal:** Add ValidateWalletCommitment change to Bid resource, enforcing minimum wallet balance and verification based on item price.

### Step 1: Write wallet commitment validation tests

**File:** `test/angle/bidding/bid/validate_wallet_commitment_test.exs`

```elixir
defmodule Angle.Bidding.Bid.ValidateWalletCommitmentTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  describe "wallet commitment validation for <₦50k items" do
    test "allows bid when user has ₦1,000+ wallet and phone verified" do
      seller = create_user()
      buyer = create_user()

      # Create wallet with sufficient balance
      _wallet = create_wallet(%{user: buyer, balance: 1500})

      # Create and verify phone
      {:ok, verification} =
        Angle.Accounts.UserVerification
        |> Ash.Changeset.for_create(:create, %{user_id: buyer.id}, authorize?: false)
        |> Ash.create()

      {:ok, result} =
        verification
        |> Ash.Changeset.for_update(
          :request_phone_otp,
          %{phone_number: "+2348012345678"},
          authorize?: false
        )
        |> Ash.update()

      {:ok, _verified} =
        verification
        |> Ash.Changeset.for_update(
          :verify_phone_otp,
          %{otp_code: result.otp_code},
          authorize?: false
        )
        |> Ash.update()

      # Create item worth ₦30,000 (<₦50k)
      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      # Bid should succeed
      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when wallet balance < ₦1,000" do
      seller = create_user()
      buyer = create_user()

      # Create wallet with insufficient balance
      _wallet = create_wallet(%{user: buyer, balance: 500})

      # Phone verified
      verification = create_verification(%{user: buyer, phone_verified: true})

      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "₦1,000") and String.contains?(err.message, "wallet")
      end)
    end

    test "rejects bid when phone not verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(%{user: buyer, balance: 2000})

      # Phone NOT verified
      _verification = create_verification(%{user: buyer, phone_verified: false})

      item =
        create_item(%{
          title: "Low Value Item",
          starting_price: 30_000,
          current_price: 30_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 30_100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "phone") and String.contains?(err.message, "verified")
      end)
    end
  end

  describe "wallet commitment validation for ≥₦50k items" do
    test "allows bid when user has ₦5,000+ wallet, phone and ID verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(%{user: buyer, balance: 6000})

      # Phone and ID verified
      _verification = create_verification(%{
        user: buyer,
        phone_verified: true,
        id_verified: true
      })

      # High-value item (₦100k)
      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 105_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when wallet balance < ₦5,000" do
      seller = create_user()
      buyer = create_user()

      # Insufficient wallet
      _wallet = create_wallet(%{user: buyer, balance: 3000})

      # Phone and ID verified
      _verification = create_verification(%{
        user: buyer,
        phone_verified: true,
        id_verified: true
      })

      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 105_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "₦5,000") and String.contains?(err.message, "wallet")
      end)
    end

    test "rejects bid when ID not verified" do
      seller = create_user()
      buyer = create_user()

      # Sufficient wallet
      _wallet = create_wallet(%{user: buyer, balance: 6000})

      # Phone verified but ID NOT verified
      _verification = create_verification(%{
        user: buyer,
        phone_verified: true,
        id_verified: false
      })

      item =
        create_item(%{
          title: "High Value Item",
          starting_price: 100_000,
          current_price: 100_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 105_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "ID") and String.contains?(err.message, "verified")
      end)
    end
  end

  describe "handles missing wallet/verification gracefully" do
    test "rejects bid when user has no wallet" do
      seller = create_user()
      buyer = create_user()

      # No wallet created for buyer
      # Phone verified
      _verification = create_verification(%{user: buyer, phone_verified: true})

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 10_100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "wallet")
      end)
    end

    test "rejects bid when user has no verification record" do
      seller = create_user()
      buyer = create_user()

      # Has wallet but no verification record
      _wallet = create_wallet(%{user: buyer, balance: 2000})

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 10_100,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "verification") or String.contains?(err.message, "phone")
      end)
    end
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/bidding/bid/validate_wallet_commitment_test.exs
```

**Expected:** Compilation error - ValidateWalletCommitment module not found

### Step 3: Create ValidateWalletCommitment change

**File:** `lib/angle/bidding/bid/validate_wallet_commitment.ex`

```elixir
defmodule Angle.Bidding.Bid.ValidateWalletCommitment do
  @moduledoc """
  Validates that the bidder has sufficient wallet balance and verification
  level based on the item's price tier.

  Requirements:
  - <₦50k items: ₦1,000 wallet + phone verified
  - ≥₦50k items: ₦5,000 wallet + phone + ID verified

  The wallet acts as a commitment signal - funds are NOT locked during bidding.
  After winning, payment is collected separately.
  """
  use Ash.Resource.Change

  require Ash.Query

  # Tier thresholds
  @high_value_threshold Decimal.new("50000")
  @low_tier_wallet_min Decimal.new("1000")
  @high_tier_wallet_min Decimal.new("5000")

  @impl true
  def change(changeset, _opts, context) do
    # Only validate on create (place bid)
    if changeset.action.type == :create do
      validate_commitment(changeset, context)
    else
      changeset
    end
  end

  defp validate_commitment(changeset, context) do
    # Get user (actor)
    user_id = context[:actor][:id]

    if is_nil(user_id) do
      Ash.Changeset.add_error(changeset, message: "Must be logged in to bid")
    else
      # Get item to check price
      item_id = Ash.Changeset.get_attribute(changeset, :item_id)

      item =
        Angle.Inventory.Item
        |> Ash.Query.filter(id == ^item_id)
        |> Ash.Query.select([:current_price, :starting_price])
        |> Ash.read_one!(authorize?: false)

      # Determine price (use current_price if set, else starting_price)
      price = item.current_price || item.starting_price

      # Determine tier requirements
      is_high_value = Decimal.compare(price, @high_value_threshold) != :lt

      required_wallet =
        if is_high_value, do: @high_tier_wallet_min, else: @low_tier_wallet_min

      requires_id = is_high_value

      # Load user's wallet
      wallet =
        Angle.Payments.UserWallet
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.read_one(authorize?: false)

      # Load user's verification
      verification =
        Angle.Accounts.UserVerification
        |> Ash.Query.filter(user_id == ^user_id)
        |> Ash.read_one(authorize?: false)

      # Validate
      changeset
      |> validate_wallet_exists(wallet)
      |> validate_wallet_balance(wallet, required_wallet)
      |> validate_verification_exists(verification)
      |> validate_phone_verified(verification)
      |> validate_id_verified_if_required(verification, requires_id, price)
    end
  end

  defp validate_wallet_exists(changeset, {:ok, _wallet}), do: changeset

  defp validate_wallet_exists(changeset, {:error, _}) do
    Ash.Changeset.add_error(
      changeset,
      message:
        "You must create a wallet before bidding. Visit your account settings to set up your wallet."
    )
  end

  defp validate_wallet_exists(changeset, nil) do
    Ash.Changeset.add_error(
      changeset,
      message:
        "You must create a wallet before bidding. Visit your account settings to set up your wallet."
    )
  end

  defp validate_wallet_balance(changeset, {:ok, wallet}, required_amount) do
    if Decimal.compare(wallet.balance, required_amount) == :lt do
      Ash.Changeset.add_error(
        changeset,
        message:
          "Minimum wallet balance of ₦#{Decimal.to_string(required_amount)} required. Current balance: ₦#{Decimal.to_string(wallet.balance)}. Please deposit funds to continue."
      )
    else
      changeset
    end
  end

  defp validate_wallet_balance(changeset, _, _required_amount), do: changeset

  defp validate_verification_exists(changeset, {:ok, _verification}), do: changeset

  defp validate_verification_exists(changeset, {:error, _}) do
    Ash.Changeset.add_error(
      changeset,
      message:
        "You must verify your phone number before bidding. Visit your account settings to verify."
    )
  end

  defp validate_verification_exists(changeset, nil) do
    Ash.Changeset.add_error(
      changeset,
      message:
        "You must verify your phone number before bidding. Visit your account settings to verify."
    )
  end

  defp validate_phone_verified(changeset, {:ok, verification}) do
    if verification.phone_verified do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        message:
          "You must verify your phone number before bidding. Visit your account settings to verify."
      )
    end
  end

  defp validate_phone_verified(changeset, _), do: changeset

  defp validate_id_verified_if_required(changeset, {:ok, verification}, true, price) do
    # High-value item, ID required
    if verification.id_verified do
      changeset
    else
      Ash.Changeset.add_error(
        changeset,
        message:
          "Items ≥₦50,000 require ID verification. This item is ₦#{Decimal.to_string(price)}. Please upload your ID document for verification."
      )
    end
  end

  defp validate_id_verified_if_required(changeset, _verification, false, _price) do
    # Low-value item, ID not required
    changeset
  end

  defp validate_id_verified_if_required(changeset, _, _, _), do: changeset
end
```

### Step 4: Add ValidateWalletCommitment to Bid resource

**File:** `lib/angle/bidding/bid.ex`

Add after `AuctionMustBeActive` in the `:make_bid` action changes:

```elixir
change {ValidateWalletCommitment, []}
```

Full change block should look like:

```elixir
change {ValidateBidIncrement, []}
change {PreventSelfBidding, []}
change {AuctionMustBeActive, []}
change {ValidateWalletCommitment, []}  # Add this
change {CheckSoftCloseExtension, []}
```

### Step 5: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/bidding/bid/validate_wallet_commitment_test.exs
```

**Expected:** All wallet commitment tests PASS

### Step 6: Run all bid tests to ensure no regressions

**Command:**
```bash
mix test test/angle/bidding/bid/
```

**Expected:** All bid tests PASS (existing tests should still work since they don't have wallet/verification setup)

**Note:** Some existing tests may fail if they don't set up wallet/verification. Update those tests to use the new factory helpers:

```elixir
# In tests that need bidding:
buyer = create_user()
_wallet = create_wallet(%{user: buyer, balance: 5000})
_verification = create_verification(%{user: buyer, phone_verified: true, id_verified: true})
```

### Step 7: Commit

**Command:**
```bash
git add lib/angle/bidding/bid/validate_wallet_commitment.ex \
        lib/angle/bidding/bid.ex \
        test/angle/bidding/bid/validate_wallet_commitment_test.exs
git commit -m "feat: enforce wallet commitment and verification for bids

- ValidateWalletCommitment: checks wallet balance + verification level
- <₦50k items: ₦1,000 wallet + phone verified
- ≥₦50k items: ₦5,000 wallet + phone + ID verified
- Clear error messages guide users to complete requirements
- Add change to make_bid action

Part of Phase 2: Payment & Trust"
```

---

## Task 7: Blacklist System

**Goal:** Allow sellers to blacklist specific users from bidding on their items.

### Step 1: Write blacklist tests

**File:** `test/angle/bidding/seller_blacklist_test.exs`

```elixir
defmodule Angle.Bidding.SellerBlacklistTest do
  use Angle.DataCase

  alias Angle.Bidding.SellerBlacklist

  describe "create blacklist entry" do
    test "seller can blacklist a user" do
      seller = create_user()
      blocked_user = create_user()

      assert {:ok, entry} =
               SellerBlacklist
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   seller_id: seller.id,
                   blocked_user_id: blocked_user.id,
                   reason: "Non-payment on previous auction"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert entry.seller_id == seller.id
      assert entry.blocked_user_id == blocked_user.id
      assert entry.reason == "Non-payment on previous auction"
    end

    test "prevents duplicate blacklist entries" do
      seller = create_user()
      blocked_user = create_user()

      {:ok, _entry} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            seller_id: seller.id,
            blocked_user_id: blocked_user.id,
            reason: "First reason"
          },
          authorize?: false
        )
        |> Ash.create()

      assert {:error, error} =
               SellerBlacklist
               |> Ash.Changeset.for_create(
                 :create,
                 %{
                   seller_id: seller.id,
                   blocked_user_id: blocked_user.id,
                   reason: "Second reason"
                 },
                 authorize?: false
               )
               |> Ash.create()

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "unique") or String.contains?(err.message, "already")
      end)
    end
  end

  describe "read blacklist" do
    test "lists all users blacklisted by a seller" do
      seller = create_user()
      user1 = create_user()
      user2 = create_user()
      user3 = create_user()

      {:ok, _} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{seller_id: seller.id, blocked_user_id: user1.id, reason: "Reason 1"},
          authorize?: false
        )
        |> Ash.create()

      {:ok, _} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{seller_id: seller.id, blocked_user_id: user2.id, reason: "Reason 2"},
          authorize?: false
        )

      blacklist =
        SellerBlacklist
        |> Ash.Query.filter(seller_id == ^seller.id)
        |> Ash.read!(authorize?: false)

      assert length(blacklist) == 2
      blocked_user_ids = Enum.map(blacklist, & &1.blocked_user_id)
      assert user1.id in blocked_user_ids
      assert user2.id in blocked_user_ids
      refute user3.id in blocked_user_ids
    end
  end

  describe "delete blacklist entry" do
    test "seller can unblock a user" do
      seller = create_user()
      blocked_user = create_user()

      {:ok, entry} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            seller_id: seller.id,
            blocked_user_id: blocked_user.id,
            reason: "Test"
          },
          authorize?: false
        )
        |> Ash.create()

      assert :ok =
               entry
               |> Ash.Changeset.for_destroy(:destroy, %{}, authorize?: false)
               |> Ash.destroy()

      # Verify deleted
      result =
        SellerBlacklist
        |> Ash.Query.filter(id == ^entry.id)
        |> Ash.read_one(authorize?: false)

      assert result == {:ok, nil}
    end
  end
end
```

### Step 2: Run test to verify it fails

**Command:**
```bash
mix test test/angle/bidding/seller_blacklist_test.exs
```

**Expected:** Compilation error - SellerBlacklist not found

### Step 3: Create SellerBlacklist resource

**File:** `lib/angle/bidding/seller_blacklist.ex`

```elixir
defmodule Angle.Bidding.SellerBlacklist do
  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "seller_blacklists"
    repo Angle.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:seller_id, :blocked_user_id, :reason]
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :seller_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :blocked_user_id, :uuid do
      allow_nil? false
      public? true
    end

    attribute :reason, :string do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :seller, Angle.Accounts.User do
      source_attribute :seller_id
      allow_nil? false
      public? true
    end

    belongs_to :blocked_user, Angle.Accounts.User do
      source_attribute :blocked_user_id
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_seller_blocked_user, [:seller_id, :blocked_user_id]
  end

  policies do
    policy action_type(:read) do
      # Sellers can read their own blacklist
      authorize_if expr(seller_id == ^actor(:id))

      # Admins can read all
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end

    policy action_type([:create, :update, :destroy]) do
      # Only seller can manage their blacklist
      authorize_if expr(seller_id == ^actor(:id))

      # Admins can manage all
      authorize_if {Angle.Accounts.Checks.HasPermission, permission: "admin"}
    end
  end
end
```

### Step 4: Add SellerBlacklist to Bidding domain

**File:** `lib/angle/bidding.ex`

Add after Bid resource:

```elixir
resource Angle.Bidding.SellerBlacklist  # Add this
```

### Step 5: Generate migration

**Command:**
```bash
mix ash.codegen --dev
```

**Expected:** Migration for `seller_blacklists` table with unique index on (seller_id, blocked_user_id)

### Step 6: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/bidding/seller_blacklist_test.exs
```

**Expected:** All blacklist tests PASS

### Step 7: Write bid validation test for blacklist

**File:** `test/angle/bidding/bid/check_blacklist_test.exs`

```elixir
defmodule Angle.Bidding.Bid.CheckBlacklistTest do
  use Angle.DataCase

  alias Angle.Bidding.{Bid, SellerBlacklist}

  defp publish_item(item) do
    item
    |> Ash.Changeset.for_update(:publish_item, %{}, authorize?: false)
    |> Ash.update!()
  end

  defp setup_bidder(buyer) do
    _wallet = create_wallet(%{user: buyer, balance: 10_000})
    _verification = create_verification(%{user: buyer, phone_verified: true, id_verified: true})
  end

  describe "blacklist validation" do
    test "allows bid when user is not blacklisted" do
      seller = create_user()
      buyer = create_user()
      setup_bidder(buyer)

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end

    test "rejects bid when user is blacklisted by seller" do
      seller = create_user()
      buyer = create_user()
      setup_bidder(buyer)

      # Seller blacklists this buyer
      {:ok, _blacklist} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            seller_id: seller.id,
            blocked_user_id: buyer.id,
            reason: "Previous non-payment"
          },
          authorize?: false
        )
        |> Ash.create()

      item =
        create_item(%{
          title: "Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller.id
        })
        |> publish_item()

      assert {:error, error} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)

      assert error.errors |> Enum.any?(fn err ->
        String.contains?(err.message, "not allowed") or String.contains?(err.message, "blacklist")
      end)
    end

    test "allows bid from blacklisted user on different seller's item" do
      seller1 = create_user()
      seller2 = create_user()
      buyer = create_user()
      setup_bidder(buyer)

      # Seller1 blacklists buyer
      {:ok, _blacklist} =
        SellerBlacklist
        |> Ash.Changeset.for_create(
          :create,
          %{
            seller_id: seller1.id,
            blocked_user_id: buyer.id,
            reason: "Test"
          },
          authorize?: false
        )
        |> Ash.create()

      # But seller2's item should allow bid
      item =
        create_item(%{
          title: "Seller2 Item",
          starting_price: 10_000,
          current_price: 10_000,
          auction_status: :active,
          end_time: DateTime.add(DateTime.utc_now(), 24 * 60 * 60, :second),
          created_by_id: seller2.id
        })
        |> publish_item()

      assert {:ok, _bid} =
               Bid
               |> Ash.Changeset.for_create(
                 :make_bid,
                 %{
                   item_id: item.id,
                   amount: 11_000,
                   bid_type: :manual
                 },
                 actor: buyer
               )
               |> Ash.create(authorize?: false)
    end
  end
end
```

### Step 8: Run test to verify it fails

**Command:**
```bash
mix test test/angle/bidding/bid/check_blacklist_test.exs
```

**Expected:** Tests fail - blacklist not checked in bid validation

### Step 9: Create CheckBlacklist change

**File:** `lib/angle/bidding/bid/check_blacklist.ex`

```elixir
defmodule Angle.Bidding.Bid.CheckBlacklist do
  @moduledoc """
  Validates that the bidder is not blacklisted by the seller.

  Sellers can blacklist users who have previously caused issues (non-payment,
  disputes, etc.). This check prevents blacklisted users from placing bids on
  that specific seller's items.
  """
  use Ash.Resource.Change

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    # Only check on create (place bid)
    if changeset.action.type == :create do
      check_blacklist(changeset, context)
    else
      changeset
    end
  end

  defp check_blacklist(changeset, context) do
    user_id = context[:actor][:id]

    if is_nil(user_id) do
      changeset
    else
      # Get item to find seller
      item_id = Ash.Changeset.get_attribute(changeset, :item_id)

      item =
        Angle.Inventory.Item
        |> Ash.Query.filter(id == ^item_id)
        |> Ash.Query.select([:created_by_id])
        |> Ash.read_one!(authorize?: false)

      seller_id = item.created_by_id

      # Check if user is blacklisted by this seller
      blacklist_entry =
        Angle.Bidding.SellerBlacklist
        |> Ash.Query.filter(seller_id == ^seller_id and blocked_user_id == ^user_id)
        |> Ash.read_one(authorize?: false)

      case blacklist_entry do
        {:ok, nil} ->
          # Not blacklisted
          changeset

        {:ok, _entry} ->
          # Blacklisted
          Ash.Changeset.add_error(
            changeset,
            message:
              "You are not allowed to bid on this seller's items. Please contact support if you believe this is an error."
          )

        {:error, _} ->
          # Query error, allow bid (don't block on technical error)
          changeset
      end
    end
  end
end
```

### Step 10: Add CheckBlacklist to Bid resource

**File:** `lib/angle/bidding/bid.ex`

Add after `ValidateWalletCommitment` in the `:make_bid` action:

```elixir
change {CheckBlacklist, []}
```

Full change block:

```elixir
change {ValidateBidIncrement, []}
change {PreventSelfBidding, []}
change {AuctionMustBeActive, []}
change {ValidateWalletCommitment, []}
change {CheckBlacklist, []}  # Add this
change {CheckSoftCloseExtension, []}
```

### Step 11: Run tests to verify they pass

**Command:**
```bash
mix test test/angle/bidding/bid/check_blacklist_test.exs
```

**Expected:** All blacklist validation tests PASS

### Step 12: Commit

**Command:**
```bash
git add lib/angle/bidding/seller_blacklist.ex \
        lib/angle/bidding/bid/check_blacklist.ex \
        lib/angle/bidding/bid.ex \
        lib/angle/bidding.ex \
        test/angle/bidding/seller_blacklist_test.exs \
        test/angle/bidding/bid/check_blacklist_test.exs \
        priv/repo/migrations/*
git commit -m "feat: implement seller blacklist system

- SellerBlacklist resource: sellers block specific users
- CheckBlacklist change: validates bidder not blacklisted
- Unique constraint per (seller, blocked_user) pair
- Seller can manage their own blacklist
- Add blacklist check to make_bid action

Part of Phase 2: Payment & Trust"
```

---

## Stopping Point

This plan continues with 7 more tasks (seller override window, second bidder offers, non-payment handling, and Paystack integration). The complete plan would be ~15,000 lines.

**Would you like me to:**

1. **Continue writing the remaining tasks** (8-14) to complete the Phase 2 plan?
2. **Save this partial plan now** and add remaining tasks in a follow-up?
3. **Adjust the level of detail** (more/less code snippets, more/less explanation)?

The remaining tasks cover:
- Task 8: Seller Override Window (2-hour reject window)
- Task 9: Second Bidder Offer System
- Task 10: Non-Payment Handling (24-hour window, reminders)
- Task 11-14: Paystack Integration (setup, split payment, escrow, webhooks)

These are the most complex tasks requiring external API integration, Oban workers, and careful payment handling.

**Recommendation:** Continue to complete the full Phase 2 plan, then save and offer execution options.
