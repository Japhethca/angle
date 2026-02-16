# My Bids Page Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a My Bids page with Active/Won/History tabs, including an Order resource for post-auction lifecycle (payment, dispatch, delivery confirmation).

**Architecture:** New `Angle.Bidding.Order` resource tracks post-auction lifecycle. Oban job auto-ends auctions at `end_time`. Three typed queries power the three tabs. BidsLayout component mirrors the Settings sidebar/tabs pattern. Paystack integration for won item payments.

**Tech Stack:** Ash Framework, Oban, Paystack, React 19, Inertia.js, TanStack Query, shadcn/ui, Tailwind CSS

**Design doc:** `docs/plans/2026-02-16-my-bids-design.md`

**Figma references:**
- Desktop Active: node `352-12450`
- Mobile Active: node `352-12494`
- Outbid Badge: node `711-7318`
- Desktop Won: node `742-8239`
- Mobile Won: node `749-10030`
- Desktop History: node `749-9679`
- Mobile History: node `749-12292`

---

## Task 1: OrderStatus Enum

**Files:**
- Create: `lib/angle/bidding/order/order_status.ex`

**Step 1: Create the enum**

```elixir
defmodule Angle.Bidding.Order.OrderStatus do
  use Ash.Type.Enum, values: ~w(payment_pending paid dispatched completed cancelled)a
end
```

**Step 2: Commit**

```bash
git add lib/angle/bidding/order/order_status.ex
git commit -m "feat: add OrderStatus enum for post-auction lifecycle"
```

---

## Task 2: Order Ash Resource

**Files:**
- Create: `lib/angle/bidding/order.ex`
- Modify: `lib/angle/bidding.ex` (add Order to resources)

**Context:** Follow the exact pattern from `lib/angle/bidding/bid.ex`. The Order resource tracks post-auction lifecycle from payment through delivery.

**Step 1: Create the Order resource**

```elixir
defmodule Angle.Bidding.Order do
  use Ash.Resource,
    domain: Angle.Bidding,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshTypescript.Resource]

  require Ash.Resource.Validation.Builtins

  postgres do
    table "orders"
    repo Angle.Repo
  end

  typescript do
    type_name "Order"
  end

  actions do
    defaults []

    create :create do
      accept [:amount, :item_id, :buyer_id, :seller_id]
      change set_attribute(:status, :payment_pending)
    end

    read :read do
      primary? true
      pagination offset?: true, required?: false
    end

    read :buyer_orders do
      description "List orders for the current buyer"
      filter expr(buyer_id == ^actor(:id))
      pagination offset?: true, required?: false
    end

    update :pay_order do
      accept []
      argument :payment_reference, :string, allow_nil?: false
      validate attribute_equals(:status, :payment_pending), message: "Order must be in payment_pending status to pay"
      change set_attribute(:status, :paid)
      change set_attribute(:payment_reference, arg(:payment_reference))
      change set_attribute(:paid_at, &DateTime.utc_now/0)
    end

    update :mark_dispatched do
      accept []
      validate attribute_equals(:status, :paid), message: "Order must be in paid status to dispatch"
      change set_attribute(:status, :dispatched)
      change set_attribute(:dispatched_at, &DateTime.utc_now/0)
    end

    update :confirm_receipt do
      accept []
      validate attribute_equals(:status, :dispatched), message: "Order must be in dispatched status to confirm receipt"
      change set_attribute(:status, :completed)
      change set_attribute(:completed_at, &DateTime.utc_now/0)
    end
  end

  policies do
    policy action(:create) do
      authorize_if always()
    end

    policy action(:read) do
      authorize_if expr(buyer_id == ^actor(:id))
      authorize_if expr(seller_id == ^actor(:id))
    end

    policy action(:buyer_orders) do
      authorize_if always()
    end

    policy action(:pay_order) do
      authorize_if expr(buyer_id == ^actor(:id))
    end

    policy action(:mark_dispatched) do
      authorize_if expr(seller_id == ^actor(:id))
    end

    policy action(:confirm_receipt) do
      authorize_if expr(buyer_id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :status, Angle.Bidding.Order.OrderStatus do
      allow_nil? false
      public? true
      default :payment_pending
    end

    attribute :amount, :decimal do
      allow_nil? false
      public? true
    end

    attribute :payment_reference, :string do
      public? true
    end

    attribute :paid_at, :utc_datetime_usec do
      public? true
    end

    attribute :dispatched_at, :utc_datetime_usec do
      public? true
    end

    attribute :completed_at, :utc_datetime_usec do
      public? true
    end

    create_timestamp :created_at, public?: true
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :item, Angle.Inventory.Item do
      allow_nil? false
      public? true
    end

    belongs_to :buyer, Angle.Accounts.User do
      allow_nil? false
      public? true
    end

    belongs_to :seller, Angle.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    # Note: prevents same buyer winning relisted item. Remove if items can be relisted.
    identity :unique_item_buyer, [:item_id, :buyer_id]
  end
end
```

**Step 2: Register in domain**

In `lib/angle/bidding.ex`, add Order to the resources block:

```elixir
resources do
  resource Angle.Bidding.Bid
  resource Angle.Bidding.Order
end
```

**Step 3: Generate migration and migrate**

```bash
mix ash.codegen --dev
mix ecto.migrate
```

**Step 4: Add factory function**

In `test/support/factory.ex`, add:

```elixir
def create_order(attrs \\ %{}) do
  buyer = attrs[:buyer] || create_user()
  seller = attrs[:seller] || create_user()
  item = attrs[:item] || create_item(%{created_by_id: seller.id})

  params = %{
    amount: Map.get(attrs, :amount, Decimal.new("100.00")),
    item_id: item.id,
    buyer_id: buyer.id,
    seller_id: seller.id
  }

  Angle.Bidding.Order
  |> Ash.Changeset.for_create(:create, params, authorize?: false)
  |> Ash.create!(authorize?: false)
end
```

**Step 5: Write tests**

Create `test/angle/bidding/order_test.exs`:

```elixir
defmodule Angle.Bidding.OrderTest do
  use Angle.DataCase, async: true
  import Angle.Factory

  alias Angle.Bidding.Order

  describe "order lifecycle" do
    setup do
      buyer = create_user()
      seller = create_user()
      item = create_item(%{created_by_id: seller.id, starting_price: Decimal.new("100.00")})
      order = create_order(%{buyer: buyer, seller: seller, item: item, amount: Decimal.new("150.00")})

      %{buyer: buyer, seller: seller, item: item, order: order}
    end

    test "creates order with payment_pending status", %{order: order} do
      assert order.status == :payment_pending
      assert Decimal.equal?(order.amount, Decimal.new("150.00"))
    end

    test "pay_order transitions to paid", %{order: order, buyer: buyer} do
      assert {:ok, paid_order} =
               order
               |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer, authorize?: false)
               |> Ash.update(authorize?: false)

      assert paid_order.status == :paid
      assert paid_order.payment_reference == "PSK_ref_123"
      assert paid_order.paid_at != nil
    end

    test "mark_dispatched transitions from paid to dispatched", %{order: order, buyer: buyer, seller: seller} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer, authorize?: false)
        |> Ash.update(authorize?: false)

      assert {:ok, dispatched_order} =
               paid_order
               |> Ash.Changeset.for_update(:mark_dispatched, %{}, actor: seller, authorize?: false)
               |> Ash.update(authorize?: false)

      assert dispatched_order.status == :dispatched
      assert dispatched_order.dispatched_at != nil
    end

    test "confirm_receipt transitions from dispatched to completed", %{order: order, buyer: buyer, seller: seller} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer, authorize?: false)
        |> Ash.update(authorize?: false)

      {:ok, dispatched_order} =
        paid_order
        |> Ash.Changeset.for_update(:mark_dispatched, %{}, actor: seller, authorize?: false)
        |> Ash.update(authorize?: false)

      assert {:ok, completed_order} =
               dispatched_order
               |> Ash.Changeset.for_update(:confirm_receipt, %{}, actor: buyer, authorize?: false)
               |> Ash.update(authorize?: false)

      assert completed_order.status == :completed
      assert completed_order.completed_at != nil
    end

    test "cannot pay an already paid order", %{order: order, buyer: buyer} do
      {:ok, paid_order} =
        order
        |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_123"}, actor: buyer, authorize?: false)
        |> Ash.update(authorize?: false)

      assert {:error, _} =
               paid_order
               |> Ash.Changeset.for_update(:pay_order, %{payment_reference: "PSK_ref_456"}, actor: buyer, authorize?: false)
               |> Ash.update(authorize?: false)
    end
  end
end
```

**Step 6: Run tests**

```bash
mix test test/angle/bidding/order_test.exs
```

**Step 7: Commit**

```bash
git add lib/angle/bidding/order.ex lib/angle/bidding/order/ lib/angle/bidding.ex test/angle/bidding/order_test.exs test/support/factory.ex
git add priv/repo/migrations/
git commit -m "feat: add Order resource with lifecycle actions and tests"
```

---

## Task 3: End Auction Oban Worker

**Files:**
- Create: `lib/angle/bidding/workers/end_auction_worker.ex`
- Modify: `lib/angle/inventory/item.ex` (add end_auction action + schedule job on publish)
- Create: `test/angle/bidding/workers/end_auction_worker_test.exs`

**Context:** The worker runs when an item's `end_time` passes. It determines the winner (highest bid), creates an Order, and updates the item's `auction_status`. Check `deps/ash_oban/usage-rules.md` before implementing — Ash has built-in Oban integration.

**Step 1: Check Ash Oban usage rules**

Run: `cat deps/ash_oban/usage-rules.md` to understand the correct pattern for Oban integration with Ash.

**Step 2: Create the EndAuctionWorker**

The worker should:
1. Accept an `item_id` argument
2. Load the item with its bids
3. If item has bids: find highest bid, create Order, set `auction_status` to `:sold`
4. If item has no bids: set `auction_status` to `:ended`
5. Handle edge cases: item already ended, item not found

```elixir
defmodule Angle.Bidding.Workers.EndAuctionWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"item_id" => item_id}}) do
    case Ash.get(Angle.Inventory.Item, item_id, authorize?: false, load: [:bids]) do
      {:ok, item} -> end_auction(item)
      {:error, _} -> {:error, "Item not found: #{item_id}"}
    end
  end

  defp end_auction(%{auction_status: status}) when status in [:ended, :sold, :cancelled] do
    :ok  # Already ended, idempotent
  end

  defp end_auction(item) do
    case find_winning_bid(item.bids) do
      nil -> end_without_winner(item)
      winning_bid -> end_with_winner(item, winning_bid)
    end
  end

  defp find_winning_bid([]), do: nil
  defp find_winning_bid(bids) do
    Enum.max_by(bids, & &1.amount, Decimal)
  end

  defp end_without_winner(item) do
    item
    |> Ash.Changeset.for_update(:end_auction, %{new_status: :ended}, authorize?: false)
    |> Ash.update!(authorize?: false)

    :ok
  end

  defp end_with_winner(item, winning_bid) do
    # Create order
    Angle.Bidding.Order
    |> Ash.Changeset.for_create(
      :create,
      %{
        amount: winning_bid.amount,
        item_id: item.id,
        buyer_id: winning_bid.user_id,
        seller_id: item.created_by_id
      },
      authorize?: false
    )
    |> Ash.create!(authorize?: false)

    # Update item status
    item
    |> Ash.Changeset.for_update(:end_auction, %{new_status: :sold}, authorize?: false)
    |> Ash.update!(authorize?: false)

    :ok
  end
end
```

**Step 3: Add end_auction action to Item resource**

In `lib/angle/inventory/item.ex`, add inside the `actions do` block:

```elixir
update :end_auction do
  argument :new_status, Angle.Inventory.Item.ItemStatus, allow_nil?: false
  validate one_of(:new_status, [:ended, :sold])
  change set_attribute(:auction_status, arg(:new_status))
end
```

**Step 4: Schedule the Oban job when an item is published**

In `lib/angle/inventory/item.ex`, modify the `:publish_item` action to schedule the end auction job. Add a custom change that schedules the job:

Create `lib/angle/inventory/item/schedule_end_auction.ex`:

```elixir
defmodule Angle.Inventory.Item.ScheduleEndAuction do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, item ->
      if item.end_time do
        %{item_id: item.id}
        |> Angle.Bidding.Workers.EndAuctionWorker.new(scheduled_at: item.end_time)
        |> Oban.insert!()
      end

      {:ok, item}
    end)
  end
end
```

Add this change to the `:publish_item` action in `lib/angle/inventory/item.ex`:

```elixir
update :publish_item do
  # ... existing changes ...
  change {Angle.Inventory.Item.ScheduleEndAuction, []}
end
```

**Step 5: Write tests**

```elixir
defmodule Angle.Bidding.Workers.EndAuctionWorkerTest do
  use Angle.DataCase, async: true
  import Angle.Factory

  alias Angle.Bidding.Workers.EndAuctionWorker
  alias Angle.Bidding.Order

  describe "perform/1" do
    test "ends auction with winner and creates order" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id, starting_price: Decimal.new("100.00")})
      bidder1 = create_user()
      bidder2 = create_user()

      _bid1 = create_bid(%{user_id: bidder1.id, item_id: item.id, amount: Decimal.new("100.00")})
      _bid2 = create_bid(%{user_id: bidder2.id, item_id: item.id, amount: Decimal.new("150.00")})

      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})

      # Item should be sold
      updated_item = Ash.get!(Angle.Inventory.Item, item.id, authorize?: false)
      assert updated_item.auction_status == :sold

      # Order should exist for highest bidder
      [order] = Ash.read!(Order, authorize?: false)
      assert order.buyer_id == bidder2.id
      assert order.seller_id == seller.id
      assert Decimal.equal?(order.amount, Decimal.new("150.00"))
      assert order.status == :payment_pending
    end

    test "ends auction without bids" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})

      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})

      updated_item = Ash.get!(Angle.Inventory.Item, item.id, authorize?: false)
      assert updated_item.auction_status == :ended
    end

    test "is idempotent for already ended auctions" do
      seller = create_user()
      item = create_item(%{created_by_id: seller.id})

      # End it once
      EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})
      # End it again — should not error
      assert :ok = EndAuctionWorker.perform(%Oban.Job{args: %{"item_id" => item.id}})
    end
  end
end
```

**Step 6: Run tests**

```bash
mix test test/angle/bidding/workers/end_auction_worker_test.exs
```

**Step 7: Commit**

```bash
git add lib/angle/bidding/workers/ lib/angle/inventory/item.ex lib/angle/inventory/item/schedule_end_auction.ex test/angle/bidding/workers/
git commit -m "feat: add EndAuctionWorker to auto-end auctions and create orders"
```

---

## Task 4: Typed Queries and RPC Registration

**Files:**
- Modify: `lib/angle/bidding.ex` (add typed queries + RPC actions for Order)
- Modify: `lib/angle/bidding/bid.ex` (add relationship to check user's latest bid per item)

**Context:** We need three typed queries for the three tabs, plus RPC actions for order mutations. Typed queries are defined in the domain file. Check existing patterns in `lib/angle/inventory.ex` for the `typescript_rpc` block.

**Step 1: Add Order RPC actions and typed queries to the Bidding domain**

In `lib/angle/bidding.ex`, update the `typescript_rpc` block:

```elixir
typescript_rpc do
  resource Angle.Bidding.Bid do
    rpc_action :list_bids, :read
    rpc_action :make_bid, :make_bid

    # Active tab: user's bids on active items
    typed_query :active_bid_card, :read do
      ts_result_type_name "ActiveBidCard"
      ts_fields_const_name "activeBidCardFields"

      fields [
        :id,
        :amount,
        :bid_type,
        :bid_time,
        :item_id,
        :user_id,
        %{item: [
          :id,
          :title,
          :slug,
          :current_price,
          :starting_price,
          :end_time,
          :auction_status,
          :bid_count,
          :view_count
        ]}
      ]
    end

    # History tab: user's past bids
    typed_query :history_bid_card, :read do
      ts_result_type_name "HistoryBidCard"
      ts_fields_const_name "historyBidCardFields"

      fields [
        :id,
        :amount,
        :bid_time,
        :item_id,
        :user_id,
        %{item: [
          :id,
          :title,
          :slug,
          :auction_status,
          :created_by_id
        ]}
      ]
    end
  end

  resource Angle.Bidding.Order do
    rpc_action :list_orders, :buyer_orders
    rpc_action :pay_order, :pay_order
    rpc_action :mark_dispatched, :mark_dispatched
    rpc_action :confirm_receipt, :confirm_receipt

    # Won tab: user's orders
    typed_query :won_order_card, :buyer_orders do
      ts_result_type_name "WonOrderCard"
      ts_fields_const_name "wonOrderCardFields"

      fields [
        :id,
        :status,
        :amount,
        :payment_reference,
        :paid_at,
        :dispatched_at,
        :completed_at,
        :created_at,
        %{item: [
          :id,
          :title,
          :slug
        ]},
        %{seller: [
          :id,
          :username,
          :full_name,
          :whatsapp_number
        ]}
      ]
    end
  end
end
```

Also add Order to the resources block if not done in Task 2.

**Step 2: Run codegen**

```bash
mix ash_typescript.codegen
```

This generates TypeScript types and functions in `assets/js/ash_rpc.ts`.

**Step 3: Commit**

```bash
git add lib/angle/bidding.ex lib/angle/bidding/bid.ex assets/js/ash_rpc.ts
git commit -m "feat: add typed queries and RPC actions for My Bids tabs"
```

---

## Task 5: BidsController Data Loading

**Files:**
- Modify: `lib/angle_web/controllers/bids_controller.ex`

**Context:** The controller loads data for the default tab (Active) via `run_typed_query` and passes it as Inertia props. Follow the pattern from `lib/angle_web/controllers/items_controller.ex`. Always use `run_typed_query`, never manual Ash queries + serialization. See `inertia-controllers.md` in memory.

**Step 1: Update BidsController**

```elixir
defmodule AngleWeb.BidsController do
  use AngleWeb, :controller

  def index(conn, params) do
    tab = Map.get(params, "tab", "active")
    user = conn.assigns.current_user

    case tab do
      "won" -> load_won_tab(conn, user)
      "history" -> load_history_tab(conn, user)
      _ -> load_active_tab(conn, user)
    end
  end

  defp load_active_tab(conn, user) do
    params = %{
      filter: %{
        user_id: %{eq: user.id},
        item: %{auction_status: %{in: ["active", "scheduled"]}}
      },
      sort: "--bid_time"
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :active_bid_card, params, conn) do
      %{"success" => true, "data" => data} ->
        conn
        |> assign_prop(:bids, extract_results(data))
        |> assign_prop(:tab, "active")
        |> render_inertia("bids")

      _ ->
        conn
        |> assign_prop(:bids, [])
        |> assign_prop(:tab, "active")
        |> render_inertia("bids")
    end
  end

  defp load_won_tab(conn, _user) do
    params = %{sort: "--created_at"}

    case AshTypescript.Rpc.run_typed_query(:angle, :won_order_card, params, conn) do
      %{"success" => true, "data" => data} ->
        conn
        |> assign_prop(:orders, extract_results(data))
        |> assign_prop(:tab, "won")
        |> render_inertia("bids")

      _ ->
        conn
        |> assign_prop(:orders, [])
        |> assign_prop(:tab, "won")
        |> render_inertia("bids")
    end
  end

  defp load_history_tab(conn, user) do
    params = %{
      filter: %{
        user_id: %{eq: user.id},
        item: %{auction_status: %{in: ["ended", "sold", "cancelled"]}}
      },
      sort: "--bid_time"
    }

    case AshTypescript.Rpc.run_typed_query(:angle, :history_bid_card, params, conn) do
      %{"success" => true, "data" => data} ->
        conn
        |> assign_prop(:bids, extract_results(data))
        |> assign_prop(:tab, "history")
        |> render_inertia("bids")

      _ ->
        conn
        |> assign_prop(:bids, [])
        |> assign_prop(:tab, "history")
        |> render_inertia("bids")
    end
  end

  defp extract_results(data) when is_list(data), do: data
  defp extract_results(%{"results" => results}) when is_list(results), do: results
  defp extract_results(_), do: []
end
```

**Step 2: Commit**

```bash
git add lib/angle_web/controllers/bids_controller.ex
git commit -m "feat: update BidsController with tab-based data loading"
```

---

## Task 6: BidsLayout Component

**Files:**
- Create: `assets/js/features/bidding/components/bids-layout.tsx`
- Modify: `assets/js/features/bidding/index.ts` (add export)

**Context:** Mirror the pattern from `assets/js/features/settings/components/settings-layout.tsx`. Desktop shows a left sidebar with Active/Won/History links. Mobile shows top horizontal tabs. Use Inertia `Link` for navigation. Compare with Figma nodes `352-12450` (desktop) and `352-12494` (mobile) for the layout.

**Step 1: Create BidsLayout**

Icons from the Figma designs:
- Active: `Gavel` (auction hammer)
- Won: `CircleCheck` (checkmark)
- History: `History` (clock with arrow)

```tsx
import { Link, usePage } from "@inertiajs/react";
import { Gavel, CircleCheck, History } from "lucide-react";
import { cn } from "@/lib/utils";

interface BidsLayoutProps {
  tab: string;
  children: React.ReactNode;
}

const tabs = [
  { label: "Active", value: "active", icon: Gavel },
  { label: "Won", value: "won", icon: CircleCheck },
  { label: "History", value: "history", icon: History },
];

export function BidsLayout({ tab, children }: BidsLayoutProps) {
  return (
    <>
      {/* Mobile: horizontal tabs */}
      <div className="border-b border-default lg:hidden">
        <div className="flex">
          {tabs.map((t) => (
            <Link
              key={t.value}
              href={`/bids?tab=${t.value}`}
              className={cn(
                "flex-1 py-3 text-center text-sm font-medium transition-colors",
                tab === t.value
                  ? "border-b-2 border-content text-content"
                  : "text-content-tertiary"
              )}
            >
              {t.label}
            </Link>
          ))}
        </div>
      </div>

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        <aside className="w-[160px] shrink-0">
          <nav className="space-y-1">
            {tabs.map((t) => {
              const isActive = tab === t.value;
              return (
                <Link
                  key={t.value}
                  href={`/bids?tab=${t.value}`}
                  className={cn(
                    "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                    isActive
                      ? "bg-primary-600/10 text-primary-600"
                      : "text-content-tertiary hover:text-content"
                  )}
                >
                  <t.icon className="size-5" />
                  {t.label}
                </Link>
              );
            })}
          </nav>
        </aside>

        <div className="min-w-0 flex-1">
          <div className="mb-6 flex items-center gap-2">
            <h1 className="text-xl font-bold text-content">
              {tabs.find((t) => t.value === tab)?.label}
            </h1>
          </div>
          {children}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 pt-4 lg:hidden">{children}</div>
    </>
  );
}
```

**Step 2: Export from barrel**

In `assets/js/features/bidding/index.ts`, add:

```typescript
export { BidsLayout } from "./components/bids-layout";
```

If the barrel file doesn't exist, create it.

**Step 3: Commit**

```bash
git add assets/js/features/bidding/components/bids-layout.tsx assets/js/features/bidding/index.ts
git commit -m "feat: add BidsLayout component with sidebar and tab navigation"
```

---

## Task 7: Active Bids Tab

**Files:**
- Create: `assets/js/features/bidding/components/active-bid-card.tsx`
- Create: `assets/js/features/bidding/components/active-bids-list.tsx`
- Create: `assets/js/features/bidding/components/outbid-badge.tsx`
- Modify: `assets/js/features/bidding/index.ts` (add exports)

**Context:** Compare with Figma nodes `352-12450` (desktop) and `352-12494` (mobile). Desktop shows large horizontal cards with item image on left, details on right. Mobile shows a 2-column grid of compact cards. Each card shows: item title, your bid, time left, bid count, watching count, highest bid, outbid badge, "Increase Bid" button.

**Step 1: Create OutbidBadge component** (Figma node `711-7318`)

```tsx
import { CircleAlert, X } from "lucide-react";
import { useState } from "react";

export function OutbidBadge() {
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-feedback-error/20 bg-feedback-error-muted px-3 py-1.5 text-sm text-feedback-error">
      <CircleAlert className="size-4" />
      <span>You've been outbid</span>
      <button onClick={() => setDismissed(true)} className="ml-1">
        <X className="size-3.5" />
      </button>
    </div>
  );
}
```

**Step 2: Create ActiveBidCard**

```tsx
import { Link } from "@inertiajs/react";
import type { ActiveBidCard as ActiveBidCardType } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { OutbidBadge } from "./outbid-badge";

type BidItem = ActiveBidCardType[number];

interface ActiveBidCardProps {
  bid: BidItem;
}

export function ActiveBidCard({ bid }: ActiveBidCardProps) {
  const item = bid.item;
  const isOutbid = item.currentPrice
    ? parseFloat(bid.amount) < parseFloat(item.currentPrice)
    : false;
  const itemUrl = `/items/${item.slug || item.id}`;

  return (
    <>
      {/* Desktop: horizontal card */}
      <div className="hidden border-b border-default pb-6 lg:flex lg:gap-6">
        <Link href={itemUrl} className="block w-[280px] shrink-0">
          <div className="aspect-square overflow-hidden rounded-xl bg-surface-muted" />
        </Link>
        <div className="flex flex-1 flex-col gap-2">
          <Link href={itemUrl}>
            <h3 className="text-base font-semibold text-content">{item.title}</h3>
          </Link>
          <p className="text-sm text-content-tertiary">
            Your bid{" "}
            <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
          </p>
          <div className="flex items-center gap-4 text-sm text-content-tertiary">
            {item.endTime && <CountdownTimer endTime={item.endTime} />}
            <span>{item.bidCount || 0} bids</span>
            <span>{item.viewCount || 0} watching</span>
          </div>
          <p className="text-sm text-content-tertiary">
            Highest bid:{" "}
            <span className="font-medium text-content">
              {formatNaira(item.currentPrice || item.startingPrice)}
            </span>
          </p>
          {isOutbid && <OutbidBadge />}
          <div className="mt-2">
            <Link
              href={itemUrl}
              className="inline-flex items-center rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700"
            >
              Increase Bid
            </Link>
          </div>
        </div>
      </div>

      {/* Mobile: compact card */}
      <Link href={itemUrl} className="block lg:hidden">
        <div className="aspect-square overflow-hidden rounded-xl bg-surface-muted" />
        <div className="mt-2 space-y-1">
          <h3 className="line-clamp-2 text-sm font-medium text-content">{item.title}</h3>
          <p className="text-sm text-content-tertiary">
            Your bid:{" "}
            <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
          </p>
          <div className="flex items-center gap-1 text-xs text-content-tertiary">
            {isOutbid ? (
              <span className="flex items-center gap-1 text-feedback-error">
                <CountdownTimer endTime={item.endTime} />
              </span>
            ) : (
              {item.endTime && <>Time left: <CountdownTimer endTime={item.endTime} /></>}
            )}
          </div>
        </div>
      </Link>
    </>
  );
}
```

**Step 3: Create ActiveBidsList**

```tsx
import type { ActiveBidCard as ActiveBidCardType } from "@/ash_rpc";
import { ActiveBidCard } from "./active-bid-card";

interface ActiveBidsListProps {
  bids: ActiveBidCardType;
}

export function ActiveBidsList({ bids }: ActiveBidsListProps) {
  if (bids.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">
          You haven't placed any bids on active auctions yet.
        </p>
      </div>
    );
  }

  return (
    <>
      {/* Desktop: vertical list */}
      <div className="hidden space-y-6 lg:block">
        {bids.map((bid) => (
          <ActiveBidCard key={bid.id} bid={bid} />
        ))}
      </div>

      {/* Mobile: 2-column grid */}
      <div className="grid grid-cols-2 gap-4 lg:hidden">
        {bids.map((bid) => (
          <ActiveBidCard key={bid.id} bid={bid} />
        ))}
      </div>
    </>
  );
}
```

**Step 4: Update barrel exports**

```typescript
export { BidsLayout } from "./components/bids-layout";
export { ActiveBidsList } from "./components/active-bids-list";
export { ActiveBidCard } from "./components/active-bid-card";
export { OutbidBadge } from "./components/outbid-badge";
```

**Step 5: Commit**

```bash
git add assets/js/features/bidding/
git commit -m "feat: add Active bids tab components with outbid detection"
```

---

## Task 8: Won Bids Tab

**Files:**
- Create: `assets/js/features/bidding/components/won-bid-card.tsx`
- Create: `assets/js/features/bidding/components/won-bids-list.tsx`
- Modify: `assets/js/features/bidding/index.ts` (add exports)

**Context:** Compare with Figma nodes `742-8239` (desktop) and `749-10030` (mobile). Desktop shows compact list rows with thumbnail, title, status badge, price, seller info, and action buttons. Mobile shows cards with full-width action buttons.

Status badges per the Figma:
- `payment_pending` → "Payment pending" (orange)
- `paid` / `dispatched` → "Awaiting delivery" (green)
- `completed` → "Completed" (green)

Action buttons:
- `payment_pending` → "Pay" button
- `dispatched` → WhatsApp icon + "Confirm Receipt" button
- `paid` → No action (waiting for seller dispatch)

**Step 1: Create WonBidCard**

```tsx
import { Link } from "@inertiajs/react";
import { MessageCircle } from "lucide-react";
import type { WonOrderCard as WonOrderCardType } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type OrderItem = WonOrderCardType[number];

interface WonBidCardProps {
  order: OrderItem;
  onPay?: (orderId: string) => void;
  onConfirmReceipt?: (orderId: string) => void;
  payPending?: boolean;
  confirmPending?: boolean;
}

const statusConfig: Record<string, { label: string; className: string }> = {
  payment_pending: {
    label: "Payment pending",
    className: "bg-amber-50 text-amber-700 border-amber-200",
  },
  paid: {
    label: "Awaiting delivery",
    className: "bg-green-50 text-green-700 border-green-200",
  },
  dispatched: {
    label: "Awaiting delivery",
    className: "bg-green-50 text-green-700 border-green-200",
  },
  completed: {
    label: "Completed",
    className: "bg-green-50 text-green-700 border-green-200",
  },
};

function getWhatsAppUrl(phone: string | null, itemTitle: string): string | null {
  if (!phone) return null;
  const cleanPhone = phone.replace(/[^0-9+]/g, "");
  const message = encodeURIComponent(
    `Hi, I won the auction for "${itemTitle}" on Angle. I'd like to arrange delivery.`
  );
  return `https://wa.me/${cleanPhone}?text=${message}`;
}

export function WonBidCard({
  order,
  onPay,
  onConfirmReceipt,
  payPending,
  confirmPending,
}: WonBidCardProps) {
  const status = statusConfig[order.status] || statusConfig.payment_pending;
  const whatsAppUrl = getWhatsAppUrl(
    order.seller?.whatsappNumber || null,
    order.item?.title || ""
  );

  return (
    <>
      {/* Desktop */}
      <div className="hidden items-center gap-4 border-b border-default py-4 lg:flex">
        <Link href={`/items/${order.item?.slug || order.item?.id}`} className="block size-16 shrink-0">
          <div className="size-full rounded-lg bg-surface-muted" />
        </Link>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-3">
            <Link href={`/items/${order.item?.slug || order.item?.id}`}>
              <h3 className="text-sm font-medium text-content">{order.item?.title}</h3>
            </Link>
            <span className={cn("rounded-full border px-2.5 py-0.5 text-xs font-medium", status.className)}>
              {status.label}
            </span>
          </div>
          <div className="mt-1 flex items-center gap-2 text-sm">
            <span className="font-bold text-content">{formatNaira(order.amount)}</span>
            <span className="text-content-tertiary">·</span>
            <span className="text-content-tertiary">{order.seller?.username || order.seller?.fullName}</span>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {whatsAppUrl && order.status !== "payment_pending" && (
            <a
              href={whatsAppUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex size-10 items-center justify-center rounded-full border border-default hover:bg-surface-muted"
            >
              <MessageCircle className="size-5 text-content-tertiary" />
            </a>
          )}
          {order.status === "payment_pending" && onPay && (
            <button
              onClick={() => onPay(order.id)}
              disabled={payPending}
              className="rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {payPending ? "Processing..." : "Pay"}
            </button>
          )}
          {order.status === "dispatched" && onConfirmReceipt && (
            <button
              onClick={() => onConfirmReceipt(order.id)}
              disabled={confirmPending}
              className="rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {confirmPending ? "Confirming..." : "Confirm Receipt"}
            </button>
          )}
        </div>
      </div>

      {/* Mobile */}
      <div className="space-y-3 rounded-xl border border-default p-4 lg:hidden">
        <div className="flex items-start gap-3">
          <Link href={`/items/${order.item?.slug || order.item?.id}`} className="block size-14 shrink-0">
            <div className="size-full rounded-lg bg-surface-muted" />
          </Link>
          <div className="min-w-0 flex-1">
            <span className={cn("mb-1 inline-block rounded-full border px-2 py-0.5 text-xs font-medium", status.className)}>
              {status.label}
            </span>
            <Link href={`/items/${order.item?.slug || order.item?.id}`}>
              <h3 className="line-clamp-2 text-sm font-medium text-content">{order.item?.title}</h3>
            </Link>
            <div className="mt-1 flex items-center gap-2 text-sm">
              <span className="font-bold text-content">{formatNaira(order.amount)}</span>
              <span className="text-content-tertiary">·</span>
              <span className="text-content-tertiary">{order.seller?.username || order.seller?.fullName}</span>
            </div>
          </div>
        </div>

        {order.status === "payment_pending" && onPay && (
          <button
            onClick={() => onPay(order.id)}
            disabled={payPending}
            className="w-full rounded-full bg-primary-600 py-3 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
          >
            {payPending ? "Processing..." : "Pay"}
          </button>
        )}
        {order.status === "dispatched" && onConfirmReceipt && (
          <div className="flex items-center gap-3">
            {whatsAppUrl && (
              <a
                href={whatsAppUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex size-12 items-center justify-center rounded-full border border-default"
              >
                <MessageCircle className="size-5 text-content-tertiary" />
              </a>
            )}
            <button
              onClick={() => onConfirmReceipt(order.id)}
              disabled={confirmPending}
              className="flex-1 rounded-full bg-primary-600 py-3 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {confirmPending ? "Confirming..." : "Confirm Receipt"}
            </button>
          </div>
        )}
      </div>
    </>
  );
}
```

**Step 2: Create WonBidsList**

```tsx
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import type { WonOrderCard as WonOrderCardType } from "@/ash_rpc";
import { useAshMutation } from "@/hooks/use-ash-query";
import { payOrder, confirmReceipt, buildCSRFHeaders } from "@/ash_rpc";
import { WonBidCard } from "./won-bid-card";

interface WonBidsListProps {
  orders: WonOrderCardType;
}

export function WonBidsList({ orders }: WonBidsListProps) {
  const { mutate: handlePay, isPending: payPending } = useAshMutation(
    (orderId: string) =>
      payOrder({
        identity: orderId,
        input: { paymentReference: `PSK_${Date.now()}` }, // TODO: integrate real Paystack flow
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Payment processed!");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Payment failed");
      },
    }
  );

  const { mutate: handleConfirmReceipt, isPending: confirmPending } = useAshMutation(
    (orderId: string) =>
      confirmReceipt({
        identity: orderId,
        input: {},
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Receipt confirmed!");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to confirm receipt");
      },
    }
  );

  if (orders.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">
          You haven't won any auctions yet.
        </p>
      </div>
    );
  }

  return (
    <div>
      <p className="mb-4 text-sm text-content-tertiary">
        Congrats, you've won these bids 🎉
      </p>
      <div className="space-y-4 lg:space-y-0">
        {orders.map((order) => (
          <WonBidCard
            key={order.id}
            order={order}
            onPay={handlePay}
            onConfirmReceipt={handleConfirmReceipt}
            payPending={payPending}
            confirmPending={confirmPending}
          />
        ))}
      </div>
    </div>
  );
}
```

**NOTE:** The `payOrder` RPC call above uses a placeholder payment reference. The real Paystack integration should initialize a transaction, redirect to Paystack checkout, then verify on callback. This can be refined in Task 10 (Paystack integration). For now, the UI and status transitions work.

**Step 3: Update barrel exports and commit**

```bash
git add assets/js/features/bidding/
git commit -m "feat: add Won bids tab with order status cards and actions"
```

---

## Task 9: History Bids Tab

**Files:**
- Create: `assets/js/features/bidding/components/history-bid-card.tsx`
- Create: `assets/js/features/bidding/components/history-bids-list.tsx`
- Modify: `assets/js/features/bidding/index.ts` (add exports)

**Context:** Compare with Figma nodes `749-9679` (desktop) and `749-12292` (mobile). Desktop shows compact list rows with thumbnail, title, status badge (Didn't win / Completed), bid amount, seller, and date. Mobile shows cards.

Outcome determination: If the item has an Order where buyer_id matches the current user, the bid was "Completed" (won). Otherwise it "Didn't win". This logic happens on the frontend since we load bids and can cross-reference.

Actually, simpler: the controller for history tab loads bids on ended items. We pass the user's order IDs (from won tab) or determine from `item.auction_status`:
- Item `sold` + user has order → "Completed"
- Item `sold` + user has no order → "Didn't win"
- Item `ended` → "Didn't win" (no bids won)
- Item `cancelled` → "Cancelled"

For simplicity, the controller can pass an additional prop `won_item_ids` (items where user won) so the frontend can determine the outcome.

**Step 1: Update BidsController for history tab**

In the `load_history_tab` function, also load won item IDs:

```elixir
defp load_history_tab(conn, user) do
  # Load history bids
  bid_params = %{
    filter: %{
      user_id: %{eq: user.id},
      item: %{auction_status: %{in: ["ended", "sold", "cancelled"]}}
    },
    sort: "--bid_time"
  }

  bids =
    case AshTypescript.Rpc.run_typed_query(:angle, :history_bid_card, bid_params, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end

  # Load won item IDs for this user
  order_params = %{}
  won_item_ids =
    case AshTypescript.Rpc.run_typed_query(:angle, :won_order_card, order_params, conn) do
      %{"success" => true, "data" => data} ->
        extract_results(data) |> Enum.map(& &1["item"]["id"])
      _ -> []
    end

  conn
  |> assign_prop(:bids, bids)
  |> assign_prop(:won_item_ids, won_item_ids)
  |> assign_prop(:tab, "history")
  |> render_inertia("bids")
end
```

**Step 2: Create HistoryBidCard**

```tsx
import { Link } from "@inertiajs/react";
import type { HistoryBidCard as HistoryBidCardType } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type BidItem = HistoryBidCardType[number];

interface HistoryBidCardProps {
  bid: BidItem;
  didWin: boolean;
}

export function HistoryBidCard({ bid, didWin }: HistoryBidCardProps) {
  const item = bid.item;
  const itemUrl = `/items/${item.slug || item.id}`;
  const status = didWin
    ? { label: "Completed", className: "bg-green-50 text-green-700 border-green-200" }
    : { label: "Didn't win", className: "bg-gray-50 text-gray-500 border-gray-200" };

  const bidDate = bid.bidTime
    ? new Date(bid.bidTime).toLocaleDateString("en-GB", {
        day: "2-digit",
        month: "2-digit",
        year: "2-digit",
      })
    : "";

  return (
    <>
      {/* Desktop */}
      <div className="hidden items-center gap-4 border-b border-default py-4 lg:flex">
        <Link href={itemUrl} className="block size-16 shrink-0">
          <div className="size-full rounded-lg bg-surface-muted" />
        </Link>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-3">
            <Link href={itemUrl}>
              <h3 className="text-sm font-medium text-content">{item.title}</h3>
            </Link>
            <span className={cn("rounded-full border px-2.5 py-0.5 text-xs font-medium", status.className)}>
              {status.label}
            </span>
          </div>
          <div className="mt-1 flex items-center gap-2 text-sm">
            <span className="text-content-tertiary">Your bid:</span>
            <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
          </div>
        </div>
        <span className="shrink-0 text-sm text-content-tertiary">{bidDate}</span>
      </div>

      {/* Mobile */}
      <div className="space-y-2 rounded-xl border border-default p-4 lg:hidden">
        <div className="flex items-start gap-3">
          <Link href={itemUrl} className="block size-14 shrink-0">
            <div className="size-full rounded-lg bg-surface-muted" />
          </Link>
          <div className="min-w-0 flex-1">
            <span className={cn("mb-1 inline-block rounded-full border px-2 py-0.5 text-xs font-medium", status.className)}>
              {status.label}
            </span>
            <Link href={itemUrl}>
              <h3 className="line-clamp-2 text-sm font-medium text-content">{item.title}</h3>
            </Link>
            <div className="mt-1 flex items-center gap-2 text-sm">
              <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
            </div>
            <span className="text-xs text-content-tertiary">{bidDate}</span>
          </div>
        </div>
      </div>
    </>
  );
}
```

**Step 3: Create HistoryBidsList**

```tsx
import type { HistoryBidCard as HistoryBidCardType } from "@/ash_rpc";
import { HistoryBidCard } from "./history-bid-card";

interface HistoryBidsListProps {
  bids: HistoryBidCardType;
  wonItemIds: string[];
}

export function HistoryBidsList({ bids, wonItemIds }: HistoryBidsListProps) {
  if (bids.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">
          No bid history yet.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4 lg:space-y-0">
      {bids.map((bid) => (
        <HistoryBidCard
          key={bid.id}
          bid={bid}
          didWin={wonItemIds.includes(bid.itemId)}
        />
      ))}
    </div>
  );
}
```

**Step 4: Update barrel exports and commit**

```bash
git add assets/js/features/bidding/ lib/angle_web/controllers/bids_controller.ex
git commit -m "feat: add History bids tab with outcome badges"
```

---

## Task 10: Main Bids Page Assembly

**Files:**
- Modify: `assets/js/pages/bids.tsx` (replace placeholder with full page)

**Context:** The page receives props from the controller based on the active tab. It renders the BidsLayout wrapper and the appropriate tab content.

**Step 1: Update the bids page**

```tsx
import { Head } from "@inertiajs/react";
import type { ActiveBidCard, WonOrderCard, HistoryBidCard } from "@/ash_rpc";
import {
  BidsLayout,
  ActiveBidsList,
  WonBidsList,
  HistoryBidsList,
} from "@/features/bidding";

interface BidsPageProps {
  tab: string;
  bids?: ActiveBidCard | HistoryBidCard;
  orders?: WonOrderCard;
  won_item_ids?: string[];
}

export default function Bids({
  tab = "active",
  bids = [],
  orders = [],
  won_item_ids = [],
}: BidsPageProps) {
  return (
    <>
      <Head title="My Bids" />
      <BidsLayout tab={tab}>
        {tab === "active" && (
          <ActiveBidsList bids={bids as ActiveBidCard} />
        )}
        {tab === "won" && (
          <WonBidsList orders={orders as WonOrderCard} />
        )}
        {tab === "history" && (
          <HistoryBidsList
            bids={bids as HistoryBidCard}
            wonItemIds={won_item_ids}
          />
        )}
      </BidsLayout>
    </>
  );
}
```

**Step 2: Commit**

```bash
git add assets/js/pages/bids.tsx
git commit -m "feat: assemble My Bids page with all three tabs"
```

---

## Task 11: Paystack Payment Integration for Orders

**Files:**
- Modify: `lib/angle_web/controllers/payments_controller.ex` (add order payment endpoints)
- Modify: `lib/angle_web/router.ex` (add payment routes)
- Modify: `assets/js/features/bidding/components/won-bids-list.tsx` (integrate real Paystack flow)

**Context:** The existing Paystack integration in `PaymentsController` handles card verification. For order payments, we need:
1. POST `/api/payments/pay-order` - Initialize Paystack transaction for an order
2. POST `/api/payments/verify-order-payment` - Verify payment after Paystack redirect
Follow the existing pattern in `payments_controller.ex`.

**Step 1: Add order payment endpoints to PaymentsController**

```elixir
# POST /api/payments/pay-order
def pay_order(conn, %{"order_id" => order_id}) do
  user = conn.assigns.current_user

  with {:ok, order} <- Ash.get(Angle.Bidding.Order, order_id, authorize?: false),
       :ok <- validate_buyer(order, user),
       :ok <- validate_status(order, :payment_pending),
       {:ok, data} <- @paystack.initialize_transaction(to_string(user.email), order_amount_in_kobo(order)) do
    json(conn, %{
      authorization_url: data.authorization_url,
      access_code: data.access_code,
      reference: data.reference
    })
  else
    {:error, reason} when is_binary(reason) ->
      conn |> put_status(422) |> json(%{error: reason})
    {:error, _} ->
      conn |> put_status(422) |> json(%{error: "Failed to initialize payment"})
    :unauthorized ->
      conn |> put_status(403) |> json(%{error: "Not authorized"})
    :invalid_status ->
      conn |> put_status(422) |> json(%{error: "Order is not in payment pending status"})
  end
end

# POST /api/payments/verify-order-payment
def verify_order_payment(conn, %{"reference" => reference, "order_id" => order_id}) do
  user = conn.assigns.current_user

  with {:ok, order} <- Ash.get(Angle.Bidding.Order, order_id, authorize?: false),
       :ok <- validate_buyer(order, user),
       {:ok, transaction} <- @paystack.verify_transaction(reference),
       :ok <- validate_payment_success(transaction) do
    # Update order status
    {:ok, _updated_order} =
      order
      |> Ash.Changeset.for_update(:pay_order, %{payment_reference: reference}, actor: user, authorize?: false)
      |> Ash.update(authorize?: false)

    json(conn, %{success: true})
  else
    {:error, reason} when is_binary(reason) ->
      conn |> put_status(422) |> json(%{error: reason})
    {:error, _} ->
      conn |> put_status(422) |> json(%{error: "Payment verification failed"})
  end
end

defp validate_buyer(order, user) do
  if order.buyer_id == user.id, do: :ok, else: :unauthorized
end

defp validate_status(order, expected) do
  if order.status == expected, do: :ok, else: :invalid_status
end

defp validate_payment_success(transaction) do
  if transaction.status == "success", do: :ok, else: {:error, "Payment was not successful"}
end

defp order_amount_in_kobo(order) do
  order.amount |> Decimal.mult(100) |> Decimal.to_integer()
end
```

**Step 2: Add routes**

In `lib/angle_web/router.ex`, inside the authenticated API scope (or create one):

```elixir
scope "/api/payments", AngleWeb do
  pipe_through [:browser, :require_auth]

  post "/pay-order", PaymentsController, :pay_order
  post "/verify-order-payment", PaymentsController, :verify_order_payment
end
```

**Step 3: Update WonBidsList to use real Paystack flow**

The Pay button should:
1. Call `/api/payments/pay-order` to get Paystack URL
2. Redirect to Paystack checkout
3. On return, call `/api/payments/verify-order-payment`
4. Reload page

This requires using `fetch` directly (not ash_rpc) since these are custom controller endpoints.

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/payments_controller.ex lib/angle_web/router.ex assets/js/features/bidding/
git commit -m "feat: add Paystack payment integration for won order payments"
```

---

## Task 12: Figma Comparison and Polish

**Files:** Various — fix any discrepancies found

**Step 1:** Start the Phoenix server

```bash
mix phx.server
```

**Step 2:** Take browser screenshots of all 3 tabs (desktop and mobile) and compare against the 7 Figma designs:
- Desktop Active (352-12450)
- Mobile Active (352-12494)
- Outbid Badge (711-7318)
- Desktop Won (742-8239)
- Mobile Won (749-10030)
- Desktop History (749-9679)
- Mobile History (749-12292)

**Step 3:** Fix any styling discrepancies (spacing, font sizes, colors, layout differences)

**Step 4:** Commit fixes

```bash
git commit -m "fix: polish My Bids page to match Figma designs"
```

---

## Task Summary

| # | Task | Type | Depends On |
|---|------|------|------------|
| 1 | OrderStatus enum | Backend | - |
| 2 | Order resource + tests | Backend | 1 |
| 3 | EndAuctionWorker + tests | Backend | 2 |
| 4 | Typed queries + RPC registration | Backend | 2 |
| 5 | BidsController data loading | Backend | 4 |
| 6 | BidsLayout component | Frontend | - |
| 7 | Active bids tab | Frontend | 4, 6 |
| 8 | Won bids tab | Frontend | 4, 6 |
| 9 | History bids tab | Frontend | 4, 5, 6 |
| 10 | Main bids page assembly | Frontend | 7, 8, 9 |
| 11 | Paystack payment integration | Full-stack | 2, 8 |
| 12 | Figma comparison and polish | Frontend | 10 |
