# Core Bidding System - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a robust, end-to-end bidding system for the Angle auction platform with wallet commitments, tiered verification, payment escrow, and real-time updates.

**Architecture:** Three-phase MVP approach over 16 weeks. Phase 1 focuses on core auction engine (bidding, lifecycle, winner determination), Phase 2 adds payment/trust (Paystack, wallets, verification), Phase 3 adds advanced features (Buy Now, private auctions, Q&A, real-time).

**Tech Stack:** Elixir/Phoenix, Ash Framework, React/Inertia.js, AshTypescript, Oban, Paystack, PostgreSQL

---

## Overview

This plan implements the core bidding system in 3 phases:

- **Phase 1 (Tasks 1-15):** Core auction engine - bidding, lifecycle, winner determination
- **Phase 2 (Tasks 16-25):** Payment & trust - wallets, Paystack, verification, escrow
- **Phase 3 (Tasks 26-32):** Advanced features - Buy Now, private auctions, Q&A, real-time

**Total Estimated Time:** 16 weeks (Phase 1: 6 weeks, Phase 2: 5 weeks, Phase 3: 5 weeks)

**Working Directory:** `.worktrees/core-bidding`

---

## Phase 1: Core Auction Engine (Weeks 1-6)

### Task 1: Add Item Lifecycle Attributes

**Goal:** Add fields needed for soft close extensions and state tracking.

**Files:**
- Modify: `lib/angle/inventory/item.ex`
- Test: `test/angle/inventory/item_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/inventory/item_test.exs
defmodule Angle.Inventory.ItemTest do
  use Angle.DataCase

  describe "lifecycle attributes" do
    test "item has extension_count and original_end_time fields" do
      user = create_user()

      item = create_item(%{
        title: "Test Item",
        starting_price: 100,
        created_by_id: user.id
      })

      assert item.extension_count == 0
      assert is_nil(item.original_end_time)
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `cd .worktrees/core-bidding && mix test test/angle/inventory/item_test.exs`
Expected: FAIL with "undefined field :extension_count"

**Step 3: Add attributes to Item resource**

```elixir
# lib/angle/inventory/item.ex (after line 483)
attribute :extension_count, :integer do
  default 0
  generated? true
  public? true
end

attribute :original_end_time, :utc_datetime_usec do
  public? true
end
```

**Step 4: Generate migration**

Run: `mix ash.codegen --dev`
Expected: Migration file created for new attributes

**Step 5: Run migration**

Run: `mix ecto.migrate`
Expected: Migration successful

**Step 6: Run test to verify it passes**

Run: `mix test test/angle/inventory/item_test.exs`
Expected: PASS

**Step 7: Commit**

```bash
git add lib/angle/inventory/item.ex test/angle/inventory/item_test.exs priv/repo/migrations/*
git commit -m "feat: add extension_count and original_end_time to items

- extension_count tracks soft close extensions (max 2)
- original_end_time stores initial end_time for reference
- Both fields needed for anti-sniping logic

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 2: ValidateBidIncrement Change

**Goal:** Enforce tiered bid increments based on price ranges.

**Files:**
- Create: `lib/angle/bidding/bid/validate_bid_increment.ex`
- Test: `test/angle/bidding/bid/validate_bid_increment_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/bidding/bid/validate_bid_increment_test.exs
defmodule Angle.Bidding.Bid.ValidateBidIncrementTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  describe "validate_bid_increment/2" do
    test "validates ₦100 increment for items <₦10k" do
      user = create_user()
      item = create_item(%{
        title: "Low value item",
        starting_price: 5000,
        current_price: 5000,
        created_by_id: user.id
      })

      # Valid: 5000 + 100 = 5100
      assert {:ok, bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 5100
      }, actor: user)

      # Invalid: 5000 + 50 = 5050
      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 5050
      }, actor: user)

      assert "must be at least ₦100 higher than current price" in errors_on(changeset).amount
    end

    test "validates ₦500 increment for items ₦10k-₦50k" do
      user = create_user()
      item = create_item(%{
        title: "Mid value item",
        starting_price: 20000,
        current_price: 20000,
        created_by_id: user.id
      })

      # Valid: 20000 + 500 = 20500
      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 20500
      }, actor: user)

      # Invalid: 20000 + 200 = 20200
      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 20200
      }, actor: user)

      assert "must be at least ₦500 higher than current price" in errors_on(changeset).amount
    end

    test "validates ₦1,000 increment for items ₦50k-₦200k" do
      user = create_user()
      item = create_item(%{
        title: "High value item",
        starting_price: 100000,
        current_price: 100000,
        created_by_id: user.id
      })

      # Valid: 100000 + 1000 = 101000
      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 101000
      }, actor: user)

      # Invalid: 100000 + 500 = 100500
      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 100500
      }, actor: user)

      assert "must be at least ₦1,000 higher than current price" in errors_on(changeset).amount
    end

    test "validates ₦5,000 increment for items ≥₦200k" do
      user = create_user()
      item = create_item(%{
        title: "Premium item",
        starting_price: 250000,
        current_price: 250000,
        created_by_id: user.id
      })

      # Valid: 250000 + 5000 = 255000
      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 255000
      }, actor: user)

      # Invalid: 250000 + 1000 = 251000
      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: user.id,
        amount: 251000
      }, actor: user)

      assert "must be at least ₦5,000 higher than current price" in errors_on(changeset).amount
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/bidding/bid/validate_bid_increment_test.exs`
Expected: FAIL with "module not defined"

**Step 3: Create the validation change**

```elixir
# lib/angle/bidding/bid/validate_bid_increment.ex
defmodule Angle.Bidding.Bid.ValidateBidIncrement do
  @moduledoc """
  Validates that a bid meets the minimum increment requirement based on price tier.

  Increment rules:
  - ₦0-₦10k → ₦100 minimum
  - ₦10k-₦50k → ₦500 minimum
  - ₦50k-₦200k → ₦1,000 minimum
  - ₦200k+ → ₦5,000 minimum
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    bid_amount = Ash.Changeset.get_attribute(changeset, :amount)
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item with current_price
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:current_price, :starting_price])
      |> Ash.read_one!()

    current_price = item.current_price || item.starting_price
    required_increment = calculate_increment(current_price)
    minimum_bid = Decimal.add(current_price, required_increment)

    if Decimal.compare(bid_amount, minimum_bid) == :lt do
      Ash.Changeset.add_error(
        changeset,
        field: :amount,
        message: "must be at least ₦#{format_money(required_increment)} higher than current price"
      )
    else
      changeset
    end
  end

  defp calculate_increment(price) do
    cond do
      Decimal.compare(price, Decimal.new(10_000)) == :lt -> Decimal.new(100)
      Decimal.compare(price, Decimal.new(50_000)) == :lt -> Decimal.new(500)
      Decimal.compare(price, Decimal.new(200_000)) == :lt -> Decimal.new(1_000)
      true -> Decimal.new(5_000)
    end
  end

  defp format_money(decimal) do
    decimal
    |> Decimal.to_integer()
    |> Number.Delimit.number_to_delimited(precision: 0)
  end
end
```

**Step 4: Wire up the change in Bid resource**

```elixir
# lib/angle/bidding/bid.ex (in make_bid action)
# Replace the existing ValidateBidIsHigherThanCurrentPrice with:

change {Angle.Bidding.Bid.ValidateBidIncrement, []}
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/bidding/bid/validate_bid_increment_test.exs`
Expected: PASS (all 4 tests)

**Step 6: Run full test suite**

Run: `mix test`
Expected: All tests pass (may need to update existing bid tests if they assumed different increments)

**Step 7: Commit**

```bash
git add lib/angle/bidding/bid/validate_bid_increment.ex lib/angle/bidding/bid.ex test/angle/bidding/bid/validate_bid_increment_test.exs
git commit -m "feat: enforce tiered bid increments

- ₦100 for items <₦10k
- ₦500 for ₦10k-₦50k
- ₦1,000 for ₦50k-₦200k
- ₦5,000 for ₦200k+

Replaces simple 'higher than current' validation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 3: PreventSelfBidding Change

**Goal:** Prevent users from bidding on their own items.

**Files:**
- Create: `lib/angle/bidding/bid/prevent_self_bidding.ex`
- Test: `test/angle/bidding/bid/prevent_self_bidding_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/bidding/bid/prevent_self_bidding_test.exs
defmodule Angle.Bidding.Bid.PreventSelfBiddingTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  describe "prevent_self_bidding/2" do
    test "allows bidding on others' items" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Test Item",
        starting_price: 1000,
        created_by_id: seller.id
      })

      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)
    end

    test "prevents bidding on own items" do
      seller = create_user()

      item = create_item(%{
        title: "My Item",
        starting_price: 1000,
        created_by_id: seller.id
      })

      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: seller.id,
        amount: 1100
      }, actor: seller)

      assert "cannot bid on your own item" in errors_on(changeset).user_id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/bidding/bid/prevent_self_bidding_test.exs`
Expected: FAIL - self-bidding test passes (should fail)

**Step 3: Create the validation change**

```elixir
# lib/angle/bidding/bid/prevent_self_bidding.ex
defmodule Angle.Bidding.Bid.PreventSelfBidding do
  @moduledoc """
  Prevents users from bidding on their own items.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    user_id = Ash.Changeset.get_attribute(changeset, :user_id)
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item owner
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:created_by_id])
      |> Ash.read_one!()

    if item.created_by_id == user_id do
      Ash.Changeset.add_error(
        changeset,
        field: :user_id,
        message: "cannot bid on your own item"
      )
    else
      changeset
    end
  end
end
```

**Step 4: Wire up the change in Bid resource**

```elixir
# lib/angle/bidding/bid.ex (in make_bid action, after ValidateBidIncrement)

change {Angle.Bidding.Bid.PreventSelfBidding, []}
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/bidding/bid/prevent_self_bidding_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/bidding/bid/prevent_self_bidding.ex lib/angle/bidding/bid.ex test/angle/bidding/bid/prevent_self_bidding_test.exs
git commit -m "feat: prevent self-bidding

Users cannot bid on their own items

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 4: AuctionMustBeActive Change

**Goal:** Only allow bids on active or scheduled auctions.

**Files:**
- Create: `lib/angle/bidding/bid/auction_must_be_active.ex`
- Test: `test/angle/bidding/bid/auction_must_be_active_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/bidding/bid/auction_must_be_active_test.exs
defmodule Angle.Bidding.Bid.AuctionMustBeActiveTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  describe "auction_must_be_active/2" do
    test "allows bids on active auctions" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Active Auction",
        starting_price: 1000,
        auction_status: :active,
        created_by_id: seller.id
      })
      |> publish_item()

      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)
    end

    test "allows bids on scheduled auctions" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Scheduled Auction",
        starting_price: 1000,
        auction_status: :scheduled,
        created_by_id: seller.id
      })
      |> publish_item()

      assert {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)
    end

    test "prevents bids on ended auctions" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Ended Auction",
        starting_price: 1000,
        auction_status: :ended,
        created_by_id: seller.id
      })

      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      assert "auction has ended" in errors_on(changeset).item_id
    end

    test "prevents bids on sold auctions" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Sold Auction",
        starting_price: 1000,
        auction_status: :sold,
        created_by_id: seller.id
      })

      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      assert "auction has ended" in errors_on(changeset).item_id
    end

    test "prevents bids on draft items" do
      seller = create_user()
      buyer = create_user()

      item = create_item(%{
        title: "Draft Item",
        starting_price: 1000,
        publication_status: :draft,
        created_by_id: seller.id
      })

      assert {:error, changeset} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      assert "auction is not active" in errors_on(changeset).item_id
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/bidding/bid/auction_must_be_active_test.exs`
Expected: FAIL - ended/sold/draft bids succeed (should fail)

**Step 3: Create the validation change**

```elixir
# lib/angle/bidding/bid/auction_must_be_active.ex
defmodule Angle.Bidding.Bid.AuctionMustBeActive do
  @moduledoc """
  Validates that the auction is in active or scheduled status.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)

    # Get item status
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:auction_status, :publication_status])
      |> Ash.read_one!()

    cond do
      item.publication_status != :published ->
        Ash.Changeset.add_error(
          changeset,
          field: :item_id,
          message: "auction is not active"
        )

      item.auction_status not in [:active, :scheduled] ->
        Ash.Changeset.add_error(
          changeset,
          field: :item_id,
          message: "auction has ended"
        )

      true ->
        changeset
    end
  end
end
```

**Step 4: Wire up the change in Bid resource**

```elixir
# lib/angle/bidding/bid.ex (in make_bid action, after PreventSelfBidding)

change {Angle.Bidding.Bid.AuctionMustBeActive, []}
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/bidding/bid/auction_must_be_active_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/bidding/bid/auction_must_be_active.ex lib/angle/bidding/bid.ex test/angle/bidding/bid/auction_must_be_active_test.exs
git commit -m "feat: validate auction is active before bidding

Only allow bids on active or scheduled auctions

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 5: Item Start Auction Action

**Goal:** Add action to transition item from scheduled → active.

**Files:**
- Modify: `lib/angle/inventory/item.ex`
- Test: `test/angle/inventory/item_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/inventory/item_test.exs (add to existing file)

describe "start_auction/1" do
  test "transitions scheduled auction to active" do
    user = create_user()

    item = create_item(%{
      title: "Scheduled Item",
      starting_price: 1000,
      auction_status: :scheduled,
      start_time: ~U[2026-02-20 10:00:00Z],
      end_time: ~U[2026-02-21 10:00:00Z],
      created_by_id: user.id
    })
    |> publish_item()

    assert item.auction_status == :scheduled

    {:ok, started_item} = Angle.Inventory.Item.start_auction(item)

    assert started_item.auction_status == :active
  end

  test "prevents starting already active auction" do
    user = create_user()

    item = create_item(%{
      title: "Active Item",
      starting_price: 1000,
      auction_status: :active,
      created_by_id: user.id
    })

    assert {:error, _} = Angle.Inventory.Item.start_auction(item)
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/inventory/item_test.exs:103`
Expected: FAIL with "undefined function start_auction/1"

**Step 3: Add start_auction action**

```elixir
# lib/angle/inventory/item.ex (in actions block, after publish_item)

update :start_auction do
  description "Start a scheduled auction (transition to active)"
  require_atomic? false

  validate attribute_equals(:auction_status, :scheduled),
    message: "can only start scheduled auctions"

  change set_attribute(:auction_status, :active)
end
```

**Step 4: Update policies to allow system to start auctions**

```elixir
# lib/angle/inventory/item.ex (in policies block)

# Start auction - system action called by worker, always authorized
policy action(:start_auction) do
  authorize_if always()
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/inventory/item_test.exs:103`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/inventory/item.ex test/angle/inventory/item_test.exs
git commit -m "feat: add start_auction action to Item

Transitions scheduled → active
System-authorized (called by Oban worker)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 6: Item Extend Auction Action

**Goal:** Add action to extend auction end_time for soft close.

**Files:**
- Modify: `lib/angle/inventory/item.ex`
- Test: `test/angle/inventory/item_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/inventory/item_test.exs (add to existing file)

describe "extend_auction/2" do
  test "extends end_time by 10 minutes and increments counter" do
    user = create_user()
    original_end = ~U[2026-02-20 10:00:00Z]

    item = create_item(%{
      title: "Active Item",
      starting_price: 1000,
      auction_status: :active,
      end_time: original_end,
      original_end_time: original_end,
      extension_count: 0,
      created_by_id: user.id
    })

    {:ok, extended_item} = Angle.Inventory.Item.extend_auction(
      item,
      %{minutes: 10}
    )

    expected_end = DateTime.add(original_end, 10 * 60, :second)
    assert extended_item.end_time == expected_end
    assert extended_item.extension_count == 1
  end

  test "prevents more than 2 extensions" do
    user = create_user()

    item = create_item(%{
      title: "Extended Item",
      starting_price: 1000,
      auction_status: :active,
      end_time: ~U[2026-02-20 10:00:00Z],
      extension_count: 2,
      created_by_id: user.id
    })

    assert {:error, changeset} = Angle.Inventory.Item.extend_auction(
      item,
      %{minutes: 10}
    )

    assert "maximum extensions reached" in errors_on(changeset).extension_count
  end

  test "only extends active auctions" do
    user = create_user()

    item = create_item(%{
      title: "Ended Item",
      starting_price: 1000,
      auction_status: :ended,
      end_time: ~U[2026-02-20 10:00:00Z],
      created_by_id: user.id
    })

    assert {:error, _} = Angle.Inventory.Item.extend_auction(
      item,
      %{minutes: 10}
    )
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/inventory/item_test.exs:125`
Expected: FAIL with "undefined function extend_auction/2"

**Step 3: Add extend_auction action**

```elixir
# lib/angle/inventory/item.ex (in actions block, after start_auction)

update :extend_auction do
  description "Extend auction end time (soft close anti-sniping)"
  require_atomic? false

  argument :minutes, :integer, allow_nil?: false

  validate attribute_equals(:auction_status, :active),
    message: "can only extend active auctions"

  validate compare(:extension_count, less_than: 2),
    message: "maximum extensions reached"

  change fn changeset, _context ->
    minutes = Ash.Changeset.get_argument(changeset, :minutes)
    current_end = Ash.Changeset.get_attribute(changeset, :end_time)
    new_end = DateTime.add(current_end, minutes * 60, :second)

    changeset
    |> Ash.Changeset.force_change_attribute(:end_time, new_end)
    |> Ash.Changeset.atomic_update(:extension_count, {:expr, expr(extension_count + 1)})
  end
end
```

**Step 4: Add policy for extend_auction**

```elixir
# lib/angle/inventory/item.ex (in policies block)

# Extend auction - system action called by bid validation, always authorized
policy action(:extend_auction) do
  authorize_if always()
end
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/inventory/item_test.exs:125`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/inventory/item.ex test/angle/inventory/item_test.exs
git commit -m "feat: add extend_auction action for soft close

- Extends end_time by specified minutes
- Increments extension_count
- Max 2 extensions (20 minutes total)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 7: CheckSoftCloseExtension Change

**Goal:** Automatically extend auction if bid placed in last 10 minutes.

**Files:**
- Create: `lib/angle/bidding/bid/check_soft_close_extension.ex`
- Test: `test/angle/bidding/bid/check_soft_close_extension_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/bidding/bid/check_soft_close_extension_test.exs
defmodule Angle.Bidding.Bid.CheckSoftCloseExtensionTest do
  use Angle.DataCase

  alias Angle.Bidding.Bid

  describe "soft close extension" do
    test "extends auction when bid placed in last 10 minutes" do
      seller = create_user()
      buyer = create_user()
      end_time = DateTime.add(DateTime.utc_now(), 5 * 60, :second) # 5 min from now

      item = create_item(%{
        title: "Ending Soon",
        starting_price: 1000,
        auction_status: :active,
        end_time: end_time,
        original_end_time: end_time,
        extension_count: 0,
        created_by_id: seller.id
      })

      {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      # Reload item
      updated_item = Angle.Inventory.Item.by_id!(item.id)

      # Should be extended by 10 minutes
      expected_end = DateTime.add(end_time, 10 * 60, :second)
      assert DateTime.compare(updated_item.end_time, expected_end) == :eq
      assert updated_item.extension_count == 1
    end

    test "does not extend if more than 10 minutes remain" do
      seller = create_user()
      buyer = create_user()
      end_time = DateTime.add(DateTime.utc_now(), 15 * 60, :second) # 15 min from now

      item = create_item(%{
        title: "Time Remaining",
        starting_price: 1000,
        auction_status: :active,
        end_time: end_time,
        extension_count: 0,
        created_by_id: seller.id
      })

      {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      # Reload item
      updated_item = Angle.Inventory.Item.by_id!(item.id)

      # Should NOT be extended
      assert DateTime.compare(updated_item.end_time, end_time) == :eq
      assert updated_item.extension_count == 0
    end

    test "does not extend beyond 2 extensions" do
      seller = create_user()
      buyer = create_user()
      end_time = DateTime.add(DateTime.utc_now(), 5 * 60, :second)

      item = create_item(%{
        title: "Max Extensions",
        starting_price: 1000,
        auction_status: :active,
        end_time: end_time,
        extension_count: 2, # Already at max
        created_by_id: seller.id
      })

      {:ok, _bid} = Bid.make_bid(%{
        item_id: item.id,
        user_id: buyer.id,
        amount: 1100
      }, actor: buyer)

      # Reload item
      updated_item = Angle.Inventory.Item.by_id!(item.id)

      # Should NOT be extended (already at max)
      assert DateTime.compare(updated_item.end_time, end_time) == :eq
      assert updated_item.extension_count == 2
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/bidding/bid/check_soft_close_extension_test.exs`
Expected: FAIL - auction not extended

**Step 3: Create the after_action change**

```elixir
# lib/angle/bidding/bid/check_soft_close_extension.ex
defmodule Angle.Bidding.Bid.CheckSoftCloseExtension do
  @moduledoc """
  Checks if bid was placed in last 10 minutes of auction and extends if needed.

  Max 2 extensions (20 minutes total added).
  """
  use Ash.Resource.Change

  @extension_threshold_seconds 10 * 60  # 10 minutes
  @extension_duration_minutes 10

  @impl true
  def after_action(changeset, bid, _context) do
    item_id = bid.item_id

    # Get item with end_time and extension_count
    item = Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id)
      |> Ash.Query.select([:end_time, :extension_count, :auction_status])
      |> Ash.read_one!()

    # Check if extension needed
    if should_extend?(item) do
      Angle.Inventory.Item.extend_auction(item, %{minutes: @extension_duration_minutes})
    end

    {:ok, bid}
  end

  defp should_extend?(item) do
    # Only extend active auctions
    item.auction_status == :active &&
      # Only if less than 10 minutes remain
      seconds_until_end(item.end_time) <= @extension_threshold_seconds &&
      # Only if under extension limit
      item.extension_count < 2
  end

  defp seconds_until_end(end_time) do
    DateTime.diff(end_time, DateTime.utc_now(), :second)
  end
end
```

**Step 4: Wire up the change in Bid resource**

```elixir
# lib/angle/bidding/bid.ex (in make_bid action, after AuctionMustBeActive)

change {Angle.Bidding.Bid.CheckSoftCloseExtension, []}
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/bidding/bid/check_soft_close_extension_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/bidding/bid/check_soft_close_extension.ex lib/angle/bidding/bid.ex test/angle/bidding/bid/check_soft_close_extension_test.exs
git commit -m "feat: implement soft close extensions

- Auto-extend by 10min if bid in last 10min
- Max 2 extensions (20min total)
- Prevents auction sniping

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 8: StartAuctionWorker

**Goal:** Create Oban worker to start scheduled auctions.

**Files:**
- Create: `lib/angle/workers/start_auction_worker.ex`
- Test: `test/angle/workers/start_auction_worker_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/workers/start_auction_worker_test.exs
defmodule Angle.Workers.StartAuctionWorkerTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  alias Angle.Workers.StartAuctionWorker

  describe "perform/1" do
    test "starts scheduled auction" do
      user = create_user()

      item = create_item(%{
        title: "Scheduled Item",
        starting_price: 1000,
        auction_status: :scheduled,
        start_time: ~U[2026-02-20 10:00:00Z],
        end_time: ~U[2026-02-21 10:00:00Z],
        created_by_id: user.id
      })
      |> publish_item()

      assert item.auction_status == :scheduled

      # Perform job
      assert :ok = perform_job(StartAuctionWorker, %{item_id: item.id})

      # Verify auction started
      updated_item = Angle.Inventory.Item.by_id!(item.id)
      assert updated_item.auction_status == :active
    end

    test "handles already started auction idempotently" do
      user = create_user()

      item = create_item(%{
        title: "Active Item",
        starting_price: 1000,
        auction_status: :active,
        created_by_id: user.id
      })

      # Should not error, just return ok
      assert :ok = perform_job(StartAuctionWorker, %{item_id: item.id})
    end

    test "handles missing item gracefully" do
      assert {:error, _} = perform_job(StartAuctionWorker, %{item_id: Ecto.UUID.generate()})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/workers/start_auction_worker_test.exs`
Expected: FAIL with "module not defined"

**Step 3: Create the worker**

```elixir
# lib/angle/workers/start_auction_worker.ex
defmodule Angle.Workers.StartAuctionWorker do
  @moduledoc """
  Oban worker to start scheduled auctions at their start_time.

  Scheduled by publish_item action when start_time is in the future.
  """
  use Oban.Worker,
    queue: :auctions,
    max_attempts: 3

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    case Angle.Inventory.Item.by_id(item_id) do
      {:ok, item} ->
        start_auction(item)

      {:error, _} ->
        # Item not found or deleted, job can be discarded
        {:error, :item_not_found}
    end
  end

  defp start_auction(item) do
    # Idempotent: only transition if scheduled
    if item.auction_status == :scheduled do
      case Ash.update(item, :start_auction) do
        {:ok, _updated_item} ->
          # TODO: Broadcast auction started event (Phase 3)
          :ok

        {:error, error} ->
          {:error, error}
      end
    else
      # Already started or ended, nothing to do
      :ok
    end
  end
end
```

**Step 4: Add Oban queue configuration**

```elixir
# config/config.exs (find Oban config, add auctions queue)
config :angle, Oban,
  repo: Angle.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [
    default: 10,
    auctions: 20  # High priority for time-sensitive auction operations
  ]
```

**Step 5: Run test to verify it passes**

Run: `mix test test/angle/workers/start_auction_worker_test.exs`
Expected: PASS

**Step 6: Commit**

```bash
git add lib/angle/workers/start_auction_worker.ex test/angle/workers/start_auction_worker_test.exs config/config.exs
git commit -m "feat: add StartAuctionWorker

Starts scheduled auctions at their start_time
Idempotent, handles missing items gracefully

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 9: EndAuctionWorker Skeleton

**Goal:** Create worker to end auctions (winner determination in next task).

**Files:**
- Create: `lib/angle/workers/end_auction_worker.ex`
- Test: `test/angle/workers/end_auction_worker_test.exs`

**Step 1: Write the failing test**

```elixir
# test/angle/workers/end_auction_worker_test.exs
defmodule Angle.Workers.EndAuctionWorkerTest do
  use Angle.DataCase
  use Oban.Testing, repo: Angle.Repo

  alias Angle.Workers.EndAuctionWorker

  describe "perform/1" do
    test "ends active auction" do
      user = create_user()

      item = create_item(%{
        title: "Active Item",
        starting_price: 1000,
        auction_status: :active,
        end_time: DateTime.add(DateTime.utc_now(), -1, :second), # Past
        created_by_id: user.id
      })

      assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})

      # Verify auction ended
      updated_item = Angle.Inventory.Item.by_id!(item.id)
      assert updated_item.auction_status in [:ended, :sold, :cancelled]
    end

    test "handles already ended auction idempotently" do
      user = create_user()

      item = create_item(%{
        title: "Ended Item",
        starting_price: 1000,
        auction_status: :ended,
        created_by_id: user.id
      })

      assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})
    end

    test "handles missing item gracefully" do
      assert {:error, _} = perform_job(EndAuctionWorker, %{item_id: Ecto.UUID.generate()})
    end
  end
end
```

**Step 2: Run test to verify it fails**

Run: `mix test test/angle/workers/end_auction_worker_test.exs`
Expected: FAIL with "module not defined"

**Step 3: Create worker skeleton (basic end logic)**

```elixir
# lib/angle/workers/end_auction_worker.ex
defmodule Angle.Workers.EndAuctionWorker do
  @moduledoc """
  Oban worker to end auctions at their end_time.

  Determines winner, creates order, or marks cancelled.
  """
  use Oban.Worker,
    queue: :auctions,
    max_attempts: 5  # Important: must succeed for winner determination

  require Ash.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    case Angle.Inventory.Item.by_id(item_id) do
      {:ok, item} ->
        end_auction(item)

      {:error, _} ->
        {:error, :item_not_found}
    end
  end

  defp end_auction(item) do
    # Idempotent: only process if active
    if item.auction_status == :active do
      # TODO: Winner determination logic (next task)
      # For now, just mark as ended
      case Ash.update(item, :end_auction, %{new_status: :ended}) do
        {:ok, _updated_item} ->
          :ok

        {:error, error} ->
          {:error, error}
      end
    else
      # Already ended
      :ok
    end
  end
end
```

**Step 4: Run test to verify it passes**

Run: `mix test test/angle/workers/end_auction_worker_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/angle/workers/end_auction_worker.ex test/angle/workers/end_auction_worker_test.exs
git commit -m "feat: add EndAuctionWorker skeleton

Basic auction ending logic
Winner determination in next task

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

### Task 10: Winner Determination Logic

**Goal:** Implement winner selection, reserve price check, and order creation.

**Files:**
- Modify: `lib/angle/workers/end_auction_worker.ex`
- Test: `test/angle/workers/end_auction_worker_test.exs`

**Step 1: Write comprehensive tests**

```elixir
# test/angle/workers/end_auction_worker_test.exs (add to existing file)

describe "winner determination" do
  test "creates order when reserve price met" do
    seller = create_user()
    buyer = create_user()

    item = create_item(%{
      title: "Reserve Met",
      starting_price: 1000,
      reserve_price: 1500,
      current_price: 2000,
      auction_status: :active,
      created_by_id: seller.id
    })

    # Create winning bid
    create_bid(%{
      item_id: item.id,
      user_id: buyer.id,
      amount: 2000,
      bid_type: :standard
    })

    assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})

    # Verify item sold
    updated_item = Angle.Inventory.Item.by_id!(item.id)
    assert updated_item.auction_status == :sold

    # Verify order created
    order = Angle.Bidding.Order
      |> Ash.Query.filter(item_id == ^item.id)
      |> Ash.read_one!()

    assert order.buyer_id == buyer.id
    assert order.seller_id == seller.id
    assert order.amount == Decimal.new(2000)
    assert order.status == :payment_pending
  end

  test "cancels auction when reserve not met" do
    seller = create_user()
    buyer = create_user()

    item = create_item(%{
      title: "Reserve Not Met",
      starting_price: 1000,
      reserve_price: 5000,
      current_price: 2000,
      auction_status: :active,
      created_by_id: seller.id
    })

    create_bid(%{
      item_id: item.id,
      user_id: buyer.id,
      amount: 2000,
      bid_type: :standard
    })

    assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})

    # Verify cancelled
    updated_item = Angle.Inventory.Item.by_id!(item.id)
    assert updated_item.auction_status == :cancelled

    # Verify no order created
    order = Angle.Bidding.Order
      |> Ash.Query.filter(item_id == ^item.id)
      |> Ash.read_one()

    assert order == {:ok, nil}
  end

  test "cancels auction with no bids" do
    seller = create_user()

    item = create_item(%{
      title: "No Bids",
      starting_price: 1000,
      auction_status: :active,
      created_by_id: seller.id
    })

    assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})

    updated_item = Angle.Inventory.Item.by_id!(item.id)
    assert updated_item.auction_status == :cancelled
  end

  test "handles no reserve price (all bids valid)" do
    seller = create_user()
    buyer = create_user()

    item = create_item(%{
      title: "No Reserve",
      starting_price: 1000,
      reserve_price: nil,
      current_price: 1100,
      auction_status: :active,
      created_by_id: seller.id
    })

    create_bid(%{
      item_id: item.id,
      user_id: buyer.id,
      amount: 1100,
      bid_type: :standard
    })

    assert :ok = perform_job(EndAuctionWorker, %{item_id: item.id})

    updated_item = Angle.Inventory.Item.by_id!(item.id)
    assert updated_item.auction_status == :sold
  end
end
```

**Step 2: Run tests to verify they fail**

Run: `mix test test/angle/workers/end_auction_worker_test.exs:30`
Expected: FAIL - order not created, status not correct

**Step 3: Implement winner determination logic**

```elixir
# lib/angle/workers/end_auction_worker.ex (replace end_auction/1)

defp end_auction(item) do
  if item.auction_status == :active do
    # Get highest bid
    highest_bid = Angle.Bidding.Bid
      |> Ash.Query.filter(item_id == ^item.id)
      |> Ash.Query.sort(amount: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read_one()

    case highest_bid do
      {:ok, nil} ->
        # No bids, cancel auction
        cancel_auction(item, :no_bids)

      {:ok, bid} ->
        # Check reserve price
        if reserve_met?(item, bid) do
          create_order_and_mark_sold(item, bid)
        else
          cancel_auction(item, :reserve_not_met)
        end

      {:error, error} ->
        {:error, error}
    end
  else
    :ok
  end
end

defp reserve_met?(item, bid) do
  case item.reserve_price do
    nil -> true  # No reserve, any bid wins
    reserve -> Decimal.compare(bid.amount, reserve) in [:eq, :gt]
  end
end

defp create_order_and_mark_sold(item, winning_bid) do
  # Create order
  order_result = Angle.Bidding.Order.create(%{
    item_id: item.id,
    buyer_id: winning_bid.user_id,
    seller_id: item.created_by_id,
    amount: winning_bid.amount
  })

  case order_result do
    {:ok, _order} ->
      # Mark item as sold
      Ash.update(item, :end_auction, %{new_status: :sold})
      # TODO: Send notifications (next task)
      :ok

    {:error, error} ->
      {:error, error}
  end
end

defp cancel_auction(item, _reason) do
  Ash.update(item, :end_auction, %{new_status: :cancelled})
  # TODO: Send notification to seller with reason
  :ok
end
```

**Step 4: Run tests to verify they pass**

Run: `mix test test/angle/workers/end_auction_worker_test.exs`
Expected: PASS

**Step 5: Commit**

```bash
git add lib/angle/workers/end_auction_worker.ex test/angle/workers/end_auction_worker_test.exs
git commit -m "feat: implement winner determination logic

- Creates order for highest bidder if reserve met
- Cancels if no bids or reserve not met
- Handles nil reserve price (any bid wins)

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Summary and Next Steps

This implementation plan covers Phase 1 (Tasks 1-10) in detail with TDD approach. The remaining tasks would continue with:

### Remaining Phase 1 Tasks (11-15):
- Task 11: Schedule StartAuctionWorker in publish_item action
- Task 12: Schedule EndAuctionWorker in publish_item and extend_auction
- Task 13: Email notification system (Swoosh)
- Task 14: Frontend bid form enhancements (show increment, countdown)
- Task 15: Integration tests for complete bidding flow

### Phase 2 Tasks (16-25):
- UserWallet resource and actions
- WalletTransaction resource for audit trail
- ValidateWalletCommitment change for bids
- Paystack integration (split payments, escrow)
- UserVerification resource (phone, ID)
- Phone verification (SMS OTP)
- ID verification (manual review)
- Seller override window (reject winner)
- SellerBlacklist resource
- Non-payment tracking and handling

### Phase 3 Tasks (26-32):
- Buy Now functionality
- Private auctions (access tokens)
- ItemQuestion resource (Q&A)
- Real-time updates (Phoenix Channels)
- Frontend real-time hooks
- Performance optimization
- Final integration testing

---

## Testing Commands

**Run specific test:**
```bash
mix test test/angle/bidding/bid/validate_bid_increment_test.exs
```

**Run all tests:**
```bash
mix test
```

**Run with coverage:**
```bash
mix test --cover
```

**Run failed tests:**
```bash
mix test --failed
```

---

## Dev Server Commands

**Start worktree server:**
```bash
cd .worktrees/core-bidding
PORT=4113 mix phx.server
```

**Regenerate types after Ash changes:**
```bash
mix ash.codegen --dev
mix ash_typescript.codegen
```

---

**End of Implementation Plan - Phase 1 Detail**

This plan follows TDD principles with bite-sized tasks (2-5 minutes each). Each task includes test-first development, minimal implementation, and frequent commits. The plan assumes the engineer needs explicit guidance on file paths, test commands, and expected outputs.
