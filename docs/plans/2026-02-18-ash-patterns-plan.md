# Ash Patterns Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace all 43 direct Ash calls in controllers with domain code interfaces, extract duplicated helpers, and standardize code interface conventions.

**Architecture:** Domain-level `define` entries in `resources do` blocks. Shared controller helpers in `AngleWeb.Helpers.QueryHelpers`. New read actions where existing ones don't cover the use case.

**Tech Stack:** Ash Framework code interfaces, Phoenix controllers

**Worktree:** `/Users/chidex/sources/mine/angle/.worktrees/ash-patterns/` (branch `feat/ash-patterns`)

---

### Task 1: Create shared QueryHelpers module

**Files:**
- Create: `lib/angle_web/helpers/query_helpers.ex`

**Step 1: Create the module**

```elixir
defmodule AngleWeb.Helpers.QueryHelpers do
  @moduledoc "Shared helpers for Ash queries in controllers."

  @doc """
  Normalize AshTypescript typed query responses.
  Handles both paginated (%{"results" => [...]}) and plain list responses.
  """
  def extract_results(data) when is_list(data), do: data
  def extract_results(%{"results" => results}) when is_list(results), do: results
  def extract_results(_), do: []
end
```

**Step 2: Verify it compiles**

Run: `mix compile --force 2>&1 | tail -5`

**Step 3: Replace `extract_results/1` in all 7 controllers**

In each of these files, remove the private `defp extract_results` function and add `import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1]` at the top:

1. `lib/angle_web/controllers/page_controller.ex`
2. `lib/angle_web/controllers/items_controller.ex`
3. `lib/angle_web/controllers/store_dashboard_controller.ex`
4. `lib/angle_web/controllers/categories_controller.ex`
5. `lib/angle_web/controllers/bids_controller.ex`
6. `lib/angle_web/controllers/watchlist_controller.ex`
7. `lib/angle_web/controllers/store_controller.ex`

**Step 4: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/angle_web/helpers/query_helpers.ex lib/angle_web/controllers/
git commit -m "refactor: extract shared extract_results helper to QueryHelpers"
```

---

### Task 2: Add code interfaces to Angle.Media domain

**Files:**
- Modify: `lib/angle/media.ex` — add `define` entries in `resources` block
- Modify: `lib/angle/media/image.ex` — add `:cover_images` and `:count_by_owner` read actions

**Step 1: Add new read actions to Image resource**

In `lib/angle/media/image.ex`, inside the `actions do` block (after the `:by_owner` action), add:

```elixir
read :cover_images do
  argument :item_ids, {:array, :uuid} do
    allow_nil? false
  end

  filter expr(owner_type == :item and owner_id in ^arg(:item_ids) and position == 0)
end
```

**Step 2: Add code interfaces to the domain**

In `lib/angle/media.ex`, replace the resources block:

```elixir
resources do
  resource Angle.Media.Image do
    define :get_image, action: :read, get_by: [:id]
    define :list_images_by_owner, action: :by_owner, args: [:owner_type, :owner_id]
    define :list_cover_images, action: :cover_images, args: [:item_ids]
    define :create_image, action: :create
    define :destroy_image, action: :destroy
    define :reorder_image, action: :reorder
  end
end
```

**Step 3: Run codegen + tests**

Run: `mix ash.codegen --dev && mix test`
Expected: 213 tests, 0 failures

**Step 4: Commit**

```bash
git add lib/angle/media.ex lib/angle/media/image.ex
git commit -m "feat: add code interfaces to Angle.Media domain"
```

---

### Task 3: Add code interfaces to Angle.Payments domain

**Files:**
- Modify: `lib/angle/payments.ex` — add `define` entries in `resources` block

**Step 1: Add code interfaces**

In `lib/angle/payments.ex`, replace the resources block:

```elixir
resources do
  resource Angle.Payments.PaymentMethod do
    define :get_payment_method, action: :read, get_by: [:id]
    define :list_payment_methods, action: :list_by_user
    define :create_payment_method, action: :create
    define :destroy_payment_method, action: :destroy
  end

  resource Angle.Payments.PayoutMethod do
    define :get_payout_method, action: :read, get_by: [:id]
    define :list_payout_methods, action: :list_by_user
    define :create_payout_method, action: :create
    define :destroy_payout_method, action: :destroy
  end
end
```

**Step 2: Run codegen + tests**

Run: `mix ash.codegen --dev && mix test`
Expected: 213 tests, 0 failures

**Step 3: Commit**

```bash
git add lib/angle/payments.ex
git commit -m "feat: add code interfaces to Angle.Payments domain"
```

---

### Task 4: Add code interfaces to Angle.Bidding domain

**Files:**
- Modify: `lib/angle/bidding.ex` — add `define` entries in `resources` block
- Modify: `lib/angle/bidding/review.ex` — add `:by_order_ids` read action
- Modify: `lib/angle/bidding/order.ex` — add `:buyer_won_item_ids` read action

**Step 1: Add new read action to Review**

In `lib/angle/bidding/review.ex`, inside the `actions do` block, add:

```elixir
read :by_order_ids do
  argument :order_ids, {:array, :uuid}, allow_nil?: false
  filter expr(order_id in ^arg(:order_ids))
end
```

**Step 2: Add new read action to Order**

In `lib/angle/bidding/order.ex`, inside the `actions do` block, add:

```elixir
read :buyer_won_item_ids do
  filter expr(buyer_id == ^actor(:id))
  prepare build(select: [:item_id])
end
```

**Step 3: Add code interfaces to the domain**

In `lib/angle/bidding.ex`, update the resources block:

```elixir
resources do
  resource Angle.Bidding.Bid

  resource Angle.Bidding.Order do
    define :get_order, action: :read, get_by: [:id]
    define :pay_order, action: :pay_order
    define :list_buyer_won_item_ids, action: :buyer_won_item_ids
  end

  resource Angle.Bidding.Review do
    define :list_reviews_by_order_ids, action: :by_order_ids, args: [:order_ids]
  end
end
```

**Step 4: Run codegen + tests**

Run: `mix ash.codegen --dev && mix test`
Expected: 213 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/angle/bidding.ex lib/angle/bidding/order.ex lib/angle/bidding/review.ex
git commit -m "feat: add code interfaces to Angle.Bidding domain"
```

---

### Task 5: Add code interfaces to Angle.Inventory (WatchlistItem) and Angle.Accounts (User + StoreProfile)

**Files:**
- Modify: `lib/angle/inventory.ex` — add WatchlistItem `define`
- Modify: `lib/angle/accounts.ex` — add User and StoreProfile `define` entries

**Step 1: Add WatchlistItem code interface**

In `lib/angle/inventory.ex`, update the `resource Angle.Inventory.WatchlistItem` in the resources block:

```elixir
resource Angle.Inventory.WatchlistItem do
  define :list_watchlist_by_user, action: :by_user
end
```

**Step 2: Add User and StoreProfile code interfaces**

In `lib/angle/accounts.ex`, update the resources block to add to User and StoreProfile:

```elixir
resource Angle.Accounts.User do
  define :get_user, action: :read, get_by: [:id]
  define :confirm_user, action: :confirm
end
```

And add to the existing StoreProfile block:

```elixir
resource Angle.Accounts.StoreProfile do
  define :get_store_profile_by_user, action: :read, get_by: [:user_id]
  define :get_store_profile, action: :read, get_by: [:id]
end
```

**Step 3: Run codegen + tests**

Run: `mix ash.codegen --dev && mix test`
Expected: 213 tests, 0 failures

**Step 4: Commit**

```bash
git add lib/angle/inventory.ex lib/angle/accounts.ex
git commit -m "feat: add code interfaces to Inventory (WatchlistItem) and Accounts (User, StoreProfile)"
```

---

### Task 6: Create shared watchlist + category summary helpers in QueryHelpers

**Files:**
- Modify: `lib/angle_web/helpers/query_helpers.ex` — add `load_watchlisted_map/1` and `build_category_summary/1`

**Step 1: Add load_watchlisted_map**

This replaces the duplicate `load_watchlisted_map/1` in 4 controllers. Uses the new `Angle.Inventory.list_watchlist_by_user` code interface:

```elixir
@doc "Build a map of item_id => watchlist_entry_id for the current user."
def load_watchlisted_map(conn) do
  case conn.assigns[:current_user] do
    nil ->
      %{}

    user ->
      user
      |> Angle.Inventory.list_watchlist_by_user(authorize?: false)
      |> case do
        {:ok, entries} -> Map.new(entries, fn entry -> {entry.item_id, entry.id} end)
        _ -> %{}
      end
  end
end
```

Note: `list_watchlist_by_user` returns `{:ok, list}` since the `:by_user` action uses `actor(:id)` in filter, so we need to pass the user as `actor:`. Check if the `:by_user` action filters by `actor(:id)` — yes it does (`filter expr(user_id == ^actor(:id))`), so we pass `actor: user`.

Actually, the current code passes `actor: user` in the query but also `authorize?: false`. The code interface version should be:

```elixir
user
|> Angle.Inventory.list_watchlist_by_user(actor: user, authorize?: false)
```

Wait — `list_watchlist_by_user` is defined without args, so calling it is just `Angle.Inventory.list_watchlist_by_user(actor: user, authorize?: false)`. The `actor:` option is in the keyword opts.

Correction — the code should be:

```elixir
def load_watchlisted_map(conn) do
  case conn.assigns[:current_user] do
    nil ->
      %{}

    user ->
      case Angle.Inventory.list_watchlist_by_user(actor: user, authorize?: false) do
        {:ok, entries} -> Map.new(entries, fn entry -> {entry.item_id, entry.id} end)
        _ -> %{}
      end
  end
end
```

**Step 2: Add build_category_summary**

This encapsulates the complex aggregation query (duplicated in StoreController + StoreDashboardController). Since category summary involves a dynamic inline aggregate that's hard to wrap in a pure code interface, keep the Ash query calls inside this helper (the helper IS domain-adjacent logic, acceptable in a shared module):

```elixir
@doc "Build a list of categories with item counts for a seller."
def build_category_summary(seller_id) do
  require Ash.Query

  item_query =
    Angle.Inventory.Item
    |> Ash.Query.filter(created_by_id == ^seller_id and publication_status == :published)

  case Angle.Catalog.Category
       |> Ash.Query.aggregate(:item_count, :count, :items, query: item_query, default: 0)
       |> Ash.read(authorize?: false) do
    {:ok, categories} ->
      categories
      |> Enum.filter(fn cat -> cat.aggregates[:item_count] > 0 end)
      |> Enum.sort_by(fn cat -> -cat.aggregates[:item_count] end)
      |> Enum.map(fn cat ->
        %{"id" => cat.id, "name" => cat.name, "slug" => cat.slug, "count" => cat.aggregates[:item_count]}
      end)

    _ ->
      []
  end
end
```

**Step 3: Replace in controllers**

Remove private `load_watchlisted_map/1` from:
1. `lib/angle_web/controllers/page_controller.ex`
2. `lib/angle_web/controllers/categories_controller.ex`
3. `lib/angle_web/controllers/store_controller.ex`
4. `lib/angle_web/controllers/watchlist_controller.ex`

Add `import AngleWeb.Helpers.QueryHelpers, only: [extract_results: 1, load_watchlisted_map: 1]` (or expand existing import).

Remove private `build_category_summary/1` from:
1. `lib/angle_web/controllers/store_controller.ex`
2. `lib/angle_web/controllers/store_dashboard_controller.ex`

Add `import AngleWeb.Helpers.QueryHelpers, only: [..., build_category_summary: 1]` to those controllers.

**Step 4: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/angle_web/helpers/query_helpers.ex lib/angle_web/controllers/
git commit -m "refactor: extract load_watchlisted_map and build_category_summary to QueryHelpers"
```

---

### Task 7: Refactor ImageHelpers + UploadController to use code interfaces

**Files:**
- Modify: `lib/angle_web/controllers/image_helpers.ex`
- Modify: `lib/angle_web/controllers/upload_controller.ex`

**Step 1: Refactor ImageHelpers**

Replace direct Ash calls with code interfaces:

- `attach_cover_images/1`: Replace `Ash.Query.filter(...) |> Ash.read!` with `Angle.Media.list_cover_images(item_ids, authorize?: false)` — use `{:ok, images}` pattern match.
- `load_item_images/1`: Replace `Ash.Query.for_read(:by_owner, ...) |> Ash.read!` with `Angle.Media.list_images_by_owner(:item, item_id, authorize?: false)`.
- `load_owner_thumbnail_url/2`: Same pattern — use `Angle.Media.list_images_by_owner(owner_type, owner_id, authorize?: false)`.

Remove all `require Ash.Query` if no longer needed.

**Step 2: Refactor UploadController**

Replace all direct Ash calls:

- `get_image/1` (line 324): `Ash.get(Media.Image, id, ...)` → `Angle.Media.get_image(id, authorize?: false)`
- `delete/2` (line 82-83): `Ash.Changeset.for_destroy(:destroy, ...) |> Ash.destroy!()` → `Angle.Media.destroy_image!(image, authorize?: false)`
- `verify_ownership/3` for `:item` (line 147): `Ash.get(Angle.Inventory.Item, owner_id, ...)` → `Angle.Inventory.get_item(owner_id, authorize?: false)`
- `verify_ownership/3` for `:store_logo` (line 161): `Ash.get(Angle.Accounts.StoreProfile, owner_id, ...)` → `Angle.Accounts.get_store_profile(owner_id, authorize?: false)`
- `check_image_limit/2` (lines 180-186): Keep `Ash.count!` — no code interface needed for count. Alternatively, use `Angle.Media.list_images_by_owner` and `length/1` if the counts are small. Better: keep `Ash.count!` here since it's a performance-sensitive path and count is more efficient. This is acceptable inside a helper that's tightly coupled to image management.
- `next_position/2` (lines 190-201): `Ash.Query.for_read(:by_owner, ...) |> Ash.read!` → `Angle.Media.list_images_by_owner(owner_type, owner_id, authorize?: false)` then `{:ok, images}` → calculate position.
- `delete_existing_images/3` (lines 203-218): Use `Angle.Media.list_images_by_owner` to get images, then `Angle.Media.destroy_image!` for each.
- `process_and_store/4` (lines 235-251): `Ash.Changeset.for_create(:create, ...) |> Ash.create()` → `Angle.Media.create_image(params, authorize?: false)`
- `reorder_images_in_transaction/2` (lines 306-318): `Ash.Changeset.for_update(:reorder, ...) |> Ash.update!()` → `Angle.Media.reorder_image!(image, %{position: pos}, authorize?: false)`

**Step 3: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/image_helpers.ex lib/angle_web/controllers/upload_controller.ex
git commit -m "refactor: use Media code interfaces in ImageHelpers and UploadController"
```

---

### Task 8: Refactor SettingsController to use code interfaces

**Files:**
- Modify: `lib/angle_web/controllers/settings_controller.ex`

**Step 1: Replace direct Ash calls**

- `account/2` (lines 18-23): Avatar images — `Ash.Query.for_read(:by_owner, ...) |> Ash.read!` → `Angle.Media.list_images_by_owner(:user_avatar, user.id, authorize?: false)` → `{:ok, images}`.
- `payments/2` (lines 41-43): Payment methods — `Ash.read!(action: :list_by_user, actor: user)` → `Angle.Payments.list_payment_methods!(actor: user)`.
- `payments/2` (lines 45-47): Payout methods — same pattern → `Angle.Payments.list_payout_methods!(actor: user)`.
- `store/2` (lines 83-86): Store profile — `Ash.Query.filter(...) |> Ash.read_one!` → `Angle.Accounts.get_store_profile_by_user(user.id)` (already exists). Handle `{:ok, profile}` / `{:ok, nil}`.
- `store/2` (lines 93-98): Store logo images — `Ash.Query.for_read(:by_owner, ...) |> Ash.read!` → `Angle.Media.list_images_by_owner(:store_logo, profile.id, authorize?: false)`.

Remove `require Ash.Query` if no longer needed.

**Step 2: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 3: Commit**

```bash
git add lib/angle_web/controllers/settings_controller.ex
git commit -m "refactor: use code interfaces in SettingsController"
```

---

### Task 9: Refactor PaymentsController to use code interfaces

**Files:**
- Modify: `lib/angle_web/controllers/payments_controller.ex`

**Step 1: Replace direct Ash calls**

- `delete_payment_method/2` (lines 56-57):
  - `Ash.get(PaymentMethod, id, ...)` → `Angle.Payments.get_payment_method(id, actor: user)`
  - `Ash.destroy(method, ...)` → `Angle.Payments.destroy_payment_method(method, actor: user)`

- `delete_payout_method/2` (lines 109-110):
  - `Ash.get(PayoutMethod, id, ...)` → `Angle.Payments.get_payout_method(id, actor: user)`
  - `Ash.destroy(method, ...)` → `Angle.Payments.destroy_payout_method(method, actor: user)`

- `pay_order/2` (line 131):
  - `Ash.get(Angle.Bidding.Order, order_id, ...)` → `Angle.Bidding.get_order(order_id, actor: user)`

- `verify_order_payment/2` (lines 163-169):
  - `Ash.get(Angle.Bidding.Order, order_id, ...)` → `Angle.Bidding.get_order(order_id, actor: user)`
  - `Ash.Changeset.for_update(:pay_order, ...) |> Ash.update()` → `Angle.Bidding.pay_order(order, %{payment_reference: ref}, actor: user)`

- `create_payment_method/2` (lines 199-214):
  - `Ash.Changeset.for_create(:create, ...) |> Ash.create()` → `Angle.Payments.create_payment_method(params, actor: user)`

- `create_payout_method/6` (lines 226-238):
  - `Ash.Changeset.for_create(:create, ...) |> Ash.create()` → `Angle.Payments.create_payout_method(params, actor: user)`

Note: The `create_payment_method` and `create_payout_method` code interface calls pass arguments (`:user_id`, `:authorization_code`, etc.) that are defined as `argument` on the action (not `accept`). These go in the params map.

**Step 2: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 3: Commit**

```bash
git add lib/angle_web/controllers/payments_controller.ex
git commit -m "refactor: use code interfaces in PaymentsController"
```

---

### Task 10: Refactor AuthController to use code interfaces

**Files:**
- Modify: `lib/angle_web/controllers/auth_controller.ex`

**Step 1: Replace direct Ash calls**

- `do_reset_password/2` (line 130-133): `Ash.get(Angle.Accounts.User, user_id, ...)` → `Angle.Accounts.get_user(user_id, authorize?: false)`

- `confirm_user_with_token/2` (line 182): `Ash.get(Angle.Accounts.User, user_id, ...)` → `Angle.Accounts.get_user(user_id)`

- `confirm_user_account/2` (lines 246-249): `Ash.update(user, %{confirm: token}, action: :confirm, ...)` → `Angle.Accounts.confirm_user(user, %{confirm: token}, authorize?: false)`

- `do_verify_account/2` (line 320): `Ash.get(...)` → `Angle.Accounts.get_user(user_id, authorize?: false)`

- `do_verify_account/2` (lines 322-326): `Ash.update(user, ...)` → `Angle.Accounts.confirm_user(user, %{confirm: otp.confirmation_token}, authorize?: false)`

- `send_confirmation_otp/1` (line 379): `Ash.get(...)` → `Angle.Accounts.get_user(user_id, authorize?: false)`

- `send_confirmation_otp/1` (line 382): This uses `Ash.Changeset.for_update(user, :confirm, %{}, domain: ...)` only to trigger the confirmation token generation callback without actually updating. This is an AshAuthentication-specific pattern — keep it as direct Ash call since it's not a standard update (it builds a changeset without executing it, to extract the token). Add a comment explaining why.

**Step 2: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 3: Commit**

```bash
git add lib/angle_web/controllers/auth_controller.ex
git commit -m "refactor: use code interfaces in AuthController"
```

---

### Task 11: Refactor BidsController to use code interfaces

**Files:**
- Modify: `lib/angle_web/controllers/bids_controller.ex`

**Step 1: Replace direct Ash calls**

- `load_won_tab/2` (lines 52-66): Replace raw Review query with code interface:
  ```elixir
  # Before:
  Angle.Bidding.Review
  |> Ash.Query.filter(order_id in ^order_ids)
  |> Ash.Query.select([:id, :order_id, :rating, :comment, :inserted_at])
  |> Ash.read!(authorize?: false)

  # After:
  {:ok, reviews} = Angle.Bidding.list_reviews_by_order_ids(order_ids, authorize?: false)
  ```
  Then build `reviews_by_order` map from `reviews`. Note: the `select` is not needed since we're just building a map — loading all fields is fine.

- `load_history_tab/2` (lines 93-98): Replace raw Order query with code interface:
  ```elixir
  # Before:
  Angle.Bidding.Order
  |> Ash.Query.filter(buyer_id == ^user.id)
  |> Ash.Query.select([:item_id])
  |> Ash.read!(authorize?: false)
  |> Enum.map(& &1.item_id)

  # After:
  {:ok, orders} = Angle.Bidding.list_buyer_won_item_ids(actor: user, authorize?: false)
  won_item_ids = Enum.map(orders, & &1.item_id)
  ```

**Step 2: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 3: Commit**

```bash
git add lib/angle_web/controllers/bids_controller.ex
git commit -m "refactor: use code interfaces in BidsController"
```

---

### Task 12: Refactor StoreController + StoreDashboardController + remaining controllers

**Files:**
- Modify: `lib/angle_web/controllers/store_controller.ex`
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex`
- Modify: `lib/angle_web/controllers/items_controller.ex`

**Step 1: Refactor StoreController**

- `load_seller_logo_url/1` (lines 112-120): Replace raw StoreProfile query with existing code interface:
  ```elixir
  case Angle.Accounts.get_store_profile_by_user(seller_id) do
    {:ok, nil} -> nil
    {:ok, profile} -> ImageHelpers.load_owner_thumbnail_url(:store_logo, profile.id)
    _ -> nil
  end
  ```

- `load_watchlisted_map/1` and `build_category_summary/1` — already removed in Task 6, replaced with `import AngleWeb.Helpers.QueryHelpers`.

**Step 2: Refactor StoreDashboardController**

- `load_store_profile_with_logo/1` (lines 207-221): Replace raw StoreProfile query:
  ```elixir
  case Angle.Accounts.get_store_profile_by_user(user.id) do
    {:ok, nil} -> {nil, nil}
    {:ok, profile} ->
      logo_url = load_logo_url_for_profile(profile.id)
      {serialize_store_profile(profile), logo_url}
    _ -> {nil, nil}
  end
  ```

- `serialize_user/1` (line 290): `Ash.load!(user, [:avg_rating, :review_count], authorize?: false)` — keep as-is. Loading aggregates on an already-fetched record is fine and there's no code interface pattern for this.

- `build_category_summary/1` — already removed in Task 6.

**Step 3: Refactor ItemsController**

- `load_watchlist_entry_id/2` (lines 110-112): Replace raw WatchlistItem query:
  ```elixir
  case Angle.Inventory.list_watchlist_by_user(actor: user, authorize?: false) do
    {:ok, entries} ->
      case Enum.find(entries, fn e -> e.item_id == item_id end) do
        nil -> nil
        entry -> entry.id
      end
    _ -> nil
  end
  ```

**Step 4: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/angle_web/controllers/store_controller.ex lib/angle_web/controllers/store_dashboard_controller.ex lib/angle_web/controllers/items_controller.ex
git commit -m "refactor: use code interfaces in StoreController, StoreDashboardController, ItemsController"
```

---

### Task 13: Move User code_interface to domain-level and update patterns doc

**Files:**
- Modify: `lib/angle/accounts/user.ex` — remove `code_interface do` block
- Modify: `lib/angle/accounts.ex` — add all User `define` entries to domain resources block
- Modify: `docs/rules/ash_patterns.md` — update to reflect completed state
- Modify: `CLAUDE.md` — ensure patterns doc reference points to correct path

**Step 1: Move User code interfaces to domain**

Remove the `code_interface do ... end` block from `lib/angle/accounts/user.ex` (lines 65-79).

In `lib/angle/accounts.ex`, update the User resource entry in the `resources do` block:

```elixir
resource Angle.Accounts.User do
  define :get_user, action: :read, get_by: [:id]
  define :confirm_user, action: :confirm
  define :get_by_subject
  define :change_password
  define :sign_in_with_password
  define :sign_in_with_token
  define :register_with_password
  define :request_password_reset_token
  define :request_password_reset_with_password
  define :password_reset_with_password
  define :get_by_email
  define :assign_role
  define :remove_role
end
```

Note: The `get_user` and `confirm_user` were added in Task 5. Make sure all entries are consolidated here.

**Step 2: Verify calling conventions still work**

The existing code calls `Angle.Accounts.User.sign_in_with_password(...)`. With domain-level defines, the call becomes `Angle.Accounts.sign_in_with_password(...)`. Check all call sites and update them.

Search for `Angle.Accounts.User.` calls:
- `lib/angle_web/controllers/auth_controller.ex` — uses `Angle.Accounts.User.sign_in_with_password`, `Angle.Accounts.User.register_with_password`, etc.
- `lib/angle/accounts/user.ex` — internal action references (these don't use code_interface)
- `test/` files — may use `Angle.Accounts.User.` calls

Update all call sites from `Angle.Accounts.User.<function>` to `Angle.Accounts.<function>`.

**Step 3: Update patterns doc**

In `docs/rules/ash_patterns.md`:
- Update the note at line 88: Remove "Currently only `Accounts.User` has code interfaces." Replace with note that all domains now use code interfaces defined at the domain level.
- Update code examples to show domain-level `define` pattern (not resource-level `code_interface do` block).
- Update the "Real example" at lines 63-76 to show domain-level pattern.

**Step 4: Run tests**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 5: Commit**

```bash
git add lib/angle/accounts.ex lib/angle/accounts/user.ex lib/angle_web/controllers/ test/ docs/rules/ash_patterns.md CLAUDE.md
git commit -m "refactor: move User code interfaces to domain-level, update patterns doc"
```

---

### Task 14: Final verification and cleanup

**Step 1: Verify no direct Ash calls remain in controllers**

Search for remaining direct Ash calls:

```bash
grep -rn "Ash\.Query\.\|Ash\.read\|Ash\.get\|Ash\.create\|Ash\.update\|Ash\.destroy\|Ash\.Changeset\.\|Ash\.count\|Ash\.load!" lib/angle_web/controllers/ --include="*.ex"
```

Expected: Only `Ash.load!` in `serialize_user` (acceptable) and the `Ash.Changeset.for_update` in `send_confirmation_otp` (documented exception). Also `build_category_summary` in QueryHelpers uses Ash.Query (acceptable — it's a shared domain helper).

**Step 2: Run full test suite**

Run: `mix test`
Expected: 213 tests, 0 failures

**Step 3: Run codegen**

Run: `mix ash.codegen --dev`
Expected: No changes needed

**Step 4: Commit any remaining changes**

If any formatting or cleanup is needed.
