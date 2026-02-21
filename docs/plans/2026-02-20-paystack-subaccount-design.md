# Paystack Subaccount Integration Design

**Date:** 2026-02-20
**Status:** Approved
**Context:** Phase 2 Payment & Trust - Enables real payment processing for auction bidding

## Goal

Integrate Paystack subaccounts to enable automated payment processing for auction sales with platform commission splits. This replaces the basic wallet table implementation with production-ready payment infrastructure.

## Requirements Summary

Based on user decisions:
- **Subaccount Creation:** After user registration (immediate)
- **Settlement:** Manual withdrawal by seller (not automatic)
- **Escrow:** Hold funds in platform account for ≥₦50k items, transfer after conditions met
- **Wallet Table:** Keep for display/tracking, Paystack is source of truth
- **Commission:** Deducted at settlement time (when transferring to seller subaccount)

## Architecture Overview

### Core Components

**1. UserWallet Resource (Enhanced)**
- Add `paystack_subaccount_code` field to store Paystack subaccount identifier
- Keep existing `balance`, `total_deposited`, `total_withdrawn` fields as display cache
- Add `last_synced_at` timestamp to track when balance was last synced from Paystack
- Add `sync_status` enum: `synced`, `pending`, `error` to track sync health

**2. Paystack Client Module (Enhanced)**

Extend `Angle.Payments.Paystack` with new functions:
- `create_subaccount(user_params)` - Creates subaccount for new user
- `create_split_payment(amount, subaccount_code, commission)` - For <₦50k items
- `transfer_to_subaccount(subaccount_code, amount)` - For escrow releases
- `get_subaccount_balance(subaccount_code)` - For sync job
- `create_transfer_to_bank(recipient_code, amount)` - For seller withdrawals

**3. Background Sync Job**

Oban worker: `Angle.Payments.Workers.SyncSubaccountBalance`
- Runs every 5 minutes
- Fetches balance from Paystack API
- Updates `user_wallets` table
- Handles API failures gracefully (marks `sync_status: error`)

### Database Schema Changes

```elixir
# Migration: Add Paystack subaccount fields to user_wallets
alter table(:user_wallets) do
  add :paystack_subaccount_code, :string
  add :last_synced_at, :utc_datetime
  add :sync_status, :string, default: "pending"
  add :metadata, :map, default: %{}
end

create index(:user_wallets, [:sync_status, :last_synced_at])
create unique_index(:user_wallets, [:paystack_subaccount_code])
```

### Trigger Points

- **Subaccount creation**: During user registration flow (after email confirmed)
- **Split payment**: When auction ends with winning bid <₦50k
- **Escrow transfer**: When escrow conditions met for bid ≥₦50k
- **Seller withdrawal**: User clicks "Withdraw" button in Settings → Payments

---

## Payment Flows

### Flow A: Split Payment (Items <₦50k)

**Trigger:** Auction ends, winning bid amount is below ₦50,000

**Steps:**
1. Buyer initiates payment via Paystack Payment Page
2. Payment request includes split configuration:
   ```elixir
   %{
     amount: winning_bid_amount,
     email: buyer_email,
     subaccount: seller_subaccount_code,
     transaction_charge: calculate_commission(winning_bid_amount),
     bearer: "account"  # Seller pays commission
   }
   ```
3. Paystack automatically:
   - Collects full amount from buyer
   - Deducts platform commission (8%/6%/5% based on tier)
   - Deposits net amount into seller's subaccount
4. Webhook callback confirms payment success
5. Update `user_wallets.balance` immediately (optimistic update before sync)
6. Create `WalletTransaction` record with type `:auction_sale`

**Commission Calculation:**
```elixir
def calculate_commission(amount) do
  cond do
    Decimal.lt?(amount, Decimal.new("50000")) ->
      Decimal.mult(amount, Decimal.new("0.08"))  # 8%

    Decimal.lt?(amount, Decimal.new("200000")) ->
      Decimal.mult(amount, Decimal.new("0.06"))  # 6%

    true ->
      Decimal.mult(amount, Decimal.new("0.05"))  # 5%
  end
end
```

---

### Flow B: Escrow (Items ≥₦50k)

**Trigger:** Auction ends, winning bid amount is ≥₦50,000

**Phase 1 - Payment Collection:**
1. Buyer initiates payment via Paystack Payment Page
2. Payment goes to **platform account** (no split configuration)
3. Webhook callback confirms payment
4. Create `WalletTransaction` with type `:escrow_hold`, status `:pending`
5. Store escrow metadata: `{buyer_id, seller_id, bid_id, amount, expected_release_date}`

**Phase 2 - Escrow Release (after conditions met):**
1. System or admin triggers escrow release
2. Calculate commission amount
3. Call Paystack Transfer API:
   ```elixir
   Paystack.transfer_to_subaccount(
     seller_subaccount_code,
     amount_after_commission,
     reason: "Auction sale - Item #{item_id}"
   )
   ```
4. Update seller's `user_wallets.balance` with net amount
5. Create `WalletTransaction` with type `:auction_sale`, status `:completed`
6. Mark original escrow transaction as `:released`

**Escrow Conditions (to be implemented):**
- Auto-release after 7 days (configurable)
- OR buyer confirms delivery
- OR admin manually releases

---

### Flow C: Seller Withdrawal

**Trigger:** Seller clicks "Withdraw" in Settings → Payments, enters amount

**Steps:**
1. Check `user_wallets.balance >= requested_amount`
2. Validate seller has verified bank account (payout method)
3. Call Paystack Transfer API to seller's bank:
   ```elixir
   Paystack.create_transfer(
     recipient_code: seller_payout_method.recipient_code,
     amount: amount_in_kobo,
     reason: "Wallet withdrawal"
   )
   ```
4. Update `user_wallets.balance` (deduct amount)
5. Update `total_withdrawn`
6. Create `WalletTransaction` with type `:withdrawal`, status `:pending`
7. Webhook confirms transfer completion → update status to `:completed`

---

## Error Handling & Edge Cases

### Subaccount Creation Failures

**Scenario:** Paystack API fails during user registration

**Handling:**
1. User registration completes successfully (don't block registration)
2. Mark `user_wallets.sync_status = "error"`
3. Store error details in `metadata` field
4. Retry via background job (exponential backoff: 1min, 5min, 15min, 1hr)
5. Alert admin if fails after 5 retries
6. User can still browse/bid, but cannot create listings until subaccount exists

---

### Payment Webhook Failures

**Scenario:** Webhook doesn't arrive or arrives late

**Handling:**
1. Payment status check via polling (backup mechanism)
2. Query Paystack API every 30s for 5 minutes after payment initiated
3. If no confirmation after 5 minutes, mark payment as `:verification_needed`
4. Admin dashboard shows pending verifications
5. Manual reconciliation tool to verify and apply payment

---

### Sync Job Failures

**Scenario:** Paystack API rate limit or network error during balance sync

**Handling:**
1. Catch API errors, don't crash job
2. Mark affected wallets with `sync_status = "error"`
3. Continue syncing other wallets
4. Retry failed wallets on next run (5 min later)
5. If wallet fails 3 consecutive syncs, alert admin
6. UI shows "Last synced: X minutes ago" with warning if >30min

---

### Insufficient Platform Balance for Escrow

**Scenario:** Platform account balance too low to process escrow transfer

**Handling:**
1. Check platform balance before transfer
2. If insufficient, queue transfer for later (store in `escrow_pending_transfers` table)
3. Alert admin immediately (Slack/email)
4. Retry every hour until platform balance sufficient
5. Show seller "Payment processing" status in UI

---

### Duplicate Payment Webhooks

**Scenario:** Paystack sends same webhook multiple times

**Handling:**
1. Check `WalletTransaction` for existing record with same `paystack_reference`
2. If exists, return `200 OK` but skip processing
3. Log idempotency hit for monitoring
4. Ensure all payment processing uses Paystack reference as idempotency key

---

## Background Sync Implementation

### Oban Worker: `SyncSubaccountBalance`

**Configuration:**
```elixir
# config/config.exs
config :angle, Oban,
  queues: [
    wallet_sync: 5,  # 5 concurrent workers
    # ... other queues
  ]
```

**Job Definition:**
```elixir
defmodule Angle.Payments.Workers.SyncSubaccountBalance do
  use Oban.Worker,
    queue: :wallet_sync,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"wallet_id" => wallet_id}}) do
    wallet = Angle.Payments.UserWallet |> Ash.get!(wallet_id)

    case Angle.Payments.Paystack.get_subaccount_balance(wallet.paystack_subaccount_code) do
      {:ok, balance} ->
        wallet
        |> Ash.Changeset.for_update(:sync_balance, %{
          balance: balance,
          last_synced_at: DateTime.utc_now(),
          sync_status: "synced"
        })
        |> Ash.update()

      {:error, reason} ->
        wallet
        |> Ash.Changeset.for_update(:mark_sync_error, %{
          sync_status: "error",
          metadata: %{last_error: reason}
        })
        |> Ash.update()

        {:error, reason}
    end
  end
end
```

**Scheduler (runs every 5 minutes):**
```elixir
# Enqueue sync jobs for all active wallets
Angle.Payments.UserWallet
|> Ash.Query.filter(paystack_subaccount_code != nil)
|> Ash.read!()
|> Enum.each(fn wallet ->
  %{wallet_id: wallet.id}
  |> SyncSubaccountBalance.new()
  |> Oban.insert()
end)
```

**New Actions on UserWallet:**
- `sync_balance` - Updates balance from sync job
- `mark_sync_error` - Marks sync failure

---

## Testing Strategy

### Unit Tests

**Paystack Client Tests:**
```elixir
# test/angle/payments/paystack_test.exs
describe "create_subaccount/1" do
  test "creates subaccount with user details"
  test "handles Paystack API errors gracefully"
  test "returns subaccount_code on success"
end

describe "calculate_commission/1" do
  test "returns 8% for amounts < ₦50k"
  test "returns 6% for amounts ₦50k-₦200k"
  test "returns 5% for amounts > ₦200k"
  test "handles decimal precision correctly"
end

describe "create_split_payment/3" do
  test "configures split with correct commission"
  test "sets bearer to account (seller pays)"
end
```

**UserWallet Tests:**
```elixir
# test/angle/payments/user_wallet_test.exs
describe "sync_balance action" do
  test "updates balance and last_synced_at"
  test "marks sync_status as synced"
end

describe "withdrawal with Paystack integration" do
  test "calls Paystack Transfer API"
  test "handles insufficient balance"
  test "creates transaction record"
  test "updates total_withdrawn"
end
```

---

### Integration Tests

**Split Payment Flow:**
```elixir
# test/angle/payments/split_payment_integration_test.exs
test "complete split payment flow for auction < ₦50k" do
  # Setup: Create seller with subaccount, item, winning bid
  # Execute: Process payment with split
  # Assert:
  #   - Seller balance updated
  #   - Commission deducted correctly
  #   - Transaction record created
  #   - Webhook processed idempotently
end
```

**Escrow Flow:**
```elixir
# test/angle/payments/escrow_integration_test.exs
test "complete escrow flow for auction ≥ ₦50k" do
  # Setup: High-value item, winning bid
  # Execute:
  #   - Payment to platform account
  #   - Escrow hold created
  #   - Trigger release
  # Assert:
  #   - Transfer to subaccount called
  #   - Commission calculated correctly
  #   - Seller balance updated
  #   - Escrow transaction marked released
end
```

**Sync Job:**
```elixir
# test/angle/payments/workers/sync_subaccount_balance_test.exs
test "syncs balance from Paystack API" do
  # Mock Paystack API response
  # Execute job
  # Assert wallet updated with new balance
end

test "handles API failures gracefully" do
  # Mock API error
  # Execute job
  # Assert sync_status marked as error
end
```

---

## Deployment & Rollout

### Pre-Deployment Checklist

**Paystack Configuration:**
- [ ] Production API keys configured in environment
- [ ] Test subaccount creation in Paystack test mode
- [ ] Webhook URLs configured: `/webhooks/paystack`
- [ ] Platform settlement account verified
- [ ] Test mode end-to-end flow validated

**Database:**
- [ ] Migration for `paystack_subaccount_code` field deployed
- [ ] Backfill script ready for existing users (if any)
- [ ] Index on `sync_status` created

**Monitoring:**
- [ ] Oban dashboard accessible for job monitoring
- [ ] Alert rules for sync failures (>10 in 1 hour)
- [ ] Alert rules for webhook failures
- [ ] Alert rules for low platform balance (<₦100k)

---

### Rollout Strategy

**Phase 1: New Users Only (Week 1)**
- Enable subaccount creation for new registrations only
- Monitor error rates
- Fix any issues before backfill

**Phase 2: Backfill Existing Users (Week 2)**
- Run background job to create subaccounts for existing users
- Process in batches of 100
- Monitor Paystack rate limits
- Allow 24-48 hours for completion

**Phase 3: Enable Split Payments (Week 3)**
- Enable split payment flow for <₦50k auctions
- Monitor commission calculations
- Verify seller balances updating correctly

**Phase 4: Enable Escrow (Week 4)**
- Enable escrow flow for ≥₦50k auctions
- Test manual release process
- Set up auto-release scheduler (7 days)

**Phase 5: Full Production (Week 5+)**
- All payment flows active
- Monitor and optimize
- Tune sync frequency if needed

---

### Rollback Plan

**If critical issues found:**
1. Disable new subaccount creation (feature flag)
2. Fall back to manual payment processing
3. Queue all payments for manual reconciliation
4. Fix issue in staging
5. Re-deploy and gradually re-enable

---

## Files to Modify/Create

### Backend - Core Implementation
1. **lib/angle/payments/user_wallet.ex** - Add new fields and actions
2. **lib/angle/payments/paystack.ex** - Add subaccount and transfer functions
3. **lib/angle/payments/workers/sync_subaccount_balance.ex** - New Oban worker
4. **lib/angle/payments/commission_calculator.ex** - New module for commission logic
5. **priv/repo/migrations/TIMESTAMP_add_paystack_subaccount_fields.exs** - New migration

### Backend - Payment Processing
6. **lib/angle/payments/payment_processor.ex** - New module to orchestrate payment flows
7. **lib/angle_web/controllers/webhook_controller.ex** - Handle Paystack webhooks
8. **lib/angle/payments/escrow_manager.ex** - New module for escrow logic

### Backend - Registration Hook
9. **lib/angle/accounts/user.ex** - Add after_create hook for subaccount creation
10. **lib/angle/accounts/registration_hooks.ex** - New module for post-registration logic

### Configuration
11. **config/config.exs** - Add Oban wallet_sync queue
12. **config/runtime.exs** - Add Paystack webhook secret validation

### Tests
13. **test/angle/payments/paystack_test.exs** - Unit tests
14. **test/angle/payments/user_wallet_test.exs** - Updated tests
15. **test/angle/payments/split_payment_integration_test.exs** - New integration tests
16. **test/angle/payments/escrow_integration_test.exs** - New integration tests
17. **test/angle/payments/workers/sync_subaccount_balance_test.exs** - New worker tests
18. **test/angle_web/controllers/webhook_controller_test.exs** - Webhook tests

---

## Success Criteria

- ✅ Paystack subaccount created for every user after registration
- ✅ Split payment works for items <₦50k with correct commission deduction
- ✅ Escrow flow works for items ≥₦50k with delayed transfer
- ✅ Manual seller withdrawal triggers Paystack transfer to bank
- ✅ Wallet balance syncs from Paystack every 5 minutes
- ✅ All payment flows tested end-to-end
- ✅ Error handling prevents user-facing failures
- ✅ Admin monitoring dashboard shows sync health

---

## Next Steps

1. Create detailed implementation plan (using writing-plans skill)
2. Set up Paystack test environment
3. Implement core Paystack client functions
4. Add database migration
5. Implement payment flows with tests
6. Deploy to staging and test end-to-end
7. Gradual rollout to production
