# Ash Framework Patterns & Guidelines

These rules govern how the Ash Framework is used in this codebase. Follow them when implementing features, refactoring, or making any changes that involve Ash resources, domains, or controllers.

## Core Principle: Domain Interfaces Are the Public API

**Never use direct Ash calls (`Ash.read`, `Ash.get`, `Ash.create`, `Ash.update`, `Ash.destroy`, `Ash.Query`, `Ash.Changeset`) outside of resource or domain code.**

Direct Ash calls are only acceptable inside:
- Resource modules (actions, changes, validations, preparations, calculations)
- Domain modules
- Generic actions

Everywhere else — controllers, helpers, workers, tests — must use **domain code interfaces** or **typed queries**.

```elixir
# WRONG — direct Ash call in a controller
def show(conn, %{"id" => id}) do
  {:ok, item} = Ash.get(Angle.Inventory.Item, id, actor: conn.assigns.current_user)
  render_inertia(conn, "items/show", %{item: item})
end

# RIGHT — code interface
def show(conn, %{"id" => id}) do
  {:ok, item} = Angle.Inventory.Item.get_item(id, actor: conn.assigns.current_user)
  render_inertia(conn, "items/show", %{item: item})
end

# RIGHT — typed query for complex page data with nested relationships
def show(conn, %{"slug" => slug}) do
  case AshTypescript.Rpc.run_typed_query(:angle, :item_detail, %{filter: %{slug: slug}, page: %{limit: 1}}, conn) do
    %{"success" => true, "data" => data} ->
      case extract_results(data) do
        [item | _] -> render_inertia(conn, "items/show", %{item: item})
        _ -> conn |> put_status(404) |> render_inertia("errors/404")
      end

    _ ->
      conn |> put_status(404) |> render_inertia("errors/404")
  end
end
```

---

## 1. Code Interfaces

Every resource action that is called from outside its domain **must** have a code interface. Code interfaces are defined on the **resource** (not the domain) inside a `code_interface do` block:

```elixir
# In the resource file (e.g., lib/angle/inventory/item.ex)
code_interface do
  domain Angle.Inventory
  define :get_item, action: :read, get_by: [:id]
  define :create_draft, action: :create_draft
  define :publish_item, action: :publish_item
  define :list_my_listings, action: :my_listings
end
```

This generates functions like `Angle.Inventory.Item.get_item(id, opts)` that callers use.

**Real example from the codebase** (`lib/angle/accounts/user.ex`):

```elixir
code_interface do
  domain Angle.Accounts
  define :get_by_subject
  define :sign_in_with_password
  define :register_with_password
  define :assign_role
  define :remove_role
end
```

Called as: `Angle.Accounts.User.sign_in_with_password(%{email: email, password: password})`

**When to add a code interface:**
- The action is called from a controller
- The action is called from another domain's resource (change, validation, etc.)
- The action is called from a worker/job
- The action is called from tests

**When a code interface is NOT needed:**
- Internal actions only used within the same resource
- Actions only accessed via typed queries (typed queries bypass code interfaces)

> **Note:** Currently only `Accounts.User` has code interfaces. When adding new features or refactoring existing code, add `code_interface` blocks to other resources as needed.

---

## 2. Business Logic Placement

### Where logic belongs

| Logic Type | Where It Goes | Example |
|-----------|--------------|---------|
| Data transformation on write | `Ash.Resource.Change` module | Setting `seller_id` from order |
| Business rule validation (needs data access) | `Ash.Resource.Change` module | Bid must be higher than current price (loads item) |
| Pure attribute validation (no side effects) | `Ash.Resource.Validation` module | Field is present, value in range |
| Read-time filtering/sorting | `Ash.Resource.Preparation` module | Default sort order, scope to current user |
| Cross-resource side effects | `Ash.Resource.Change` with `after_action` | Scheduling an Oban job after publish |
| Complex multi-step workflows | Generic action or Reactor | Payment flow, auction end process |
| Simple computed values | Calculation on the resource | `has_role?`, `active_roles` |
| Aggregate counts/stats | Aggregate on the resource | `bid_count`, `watcher_count`, `avg_rating` |

### Change vs Validation: when to use which

Use **`Ash.Resource.Validation`** when:
- The check is pure — no loading external data, no side effects
- Examples: `validate present([:amount])`, `validate one_of(:status, [:active, :ended])`

Use **`Ash.Resource.Change`** when:
- You need to load related records (e.g., `Ash.get` to fetch an item)
- You need `before_action` or `after_action` hooks
- You need to set attributes based on external data
- The "validation" has side effects (scheduling jobs, sending notifications)

Real example — this is a Change, not a Validation, because it loads an item from another domain:

```elixir
# lib/angle/bidding/bid/validate_bid_is_higher_than_current_price.ex
defmodule Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice do
  use Ash.Resource.Change  # Change, not Validation!

  @impl true
  def change(changeset, _opts, _context) do
    item_id = Ash.Changeset.get_attribute(changeset, :item_id)
    amount = Ash.Changeset.get_attribute(changeset, :amount)

    if is_nil(item_id) or is_nil(amount) do
      changeset
    else
      # Loading external data — this is why it's a Change
      case Ash.get(Angle.Inventory.Item, item_id, authorize?: false) do
        {:ok, item} -> compare_against_price(changeset, item, amount)
        {:error, _} -> Ash.Changeset.add_error(changeset, field: :item_id, message: "item not found")
      end
    end
  end
end
```

### Where logic does NOT belong

| Anti-Pattern | Why It's Wrong | Fix |
|-------------|---------------|-----|
| Business validation in controller | Bypasses Ash authorization/lifecycle | Move to Change or Validation on resource |
| Data transformation in controller | Serialization logic duplicated | Use typed query field selection or code interface |
| Cross-domain queries in controller | Controller manually assembles data | Create typed query with nested relationships |
| Side effects in controller | Skips Ash action lifecycle hooks | Move to Change with `after_action` |

---

## 3. Controllers

Controllers are **thin**. Their only job is:
1. Load data (via typed queries or code interfaces)
2. Render an Inertia page with props

### Reading data for Inertia pages

**Use typed queries** for Inertia page props — they define the shape of data sent to React and handle field selection.

```elixir
# Typed query with extract_results helper
def index(conn, _params) do
  items =
    case AshTypescript.Rpc.run_typed_query(:angle, :seller_dashboard_card, %{}, conn) do
      %{"success" => true, "data" => data} -> extract_results(data)
      _ -> []
    end

  render_inertia(conn, "store/listings", %{items: items})
end
```

**Use code interfaces** for simple single-record lookups.

```elixir
# Code interface for simple lookup
def show(conn, %{"id" => id}) do
  user = conn.assigns.current_user
  {:ok, profile} = Angle.Accounts.StoreProfile.get_profile(user_id: user.id)
  render_inertia(conn, "settings/store", %{profile: profile})
end
```

### The `extract_results` helper

`AshTypescript.Rpc.run_typed_query/4` returns:
- **Success:** `%{"success" => true, "data" => data}` where `data` is either a plain list or `%{"results" => [...], "hasMore" => bool, "count" => int}` (paginated)
- **Error:** `%{"success" => false, "errors" => [...]}`

Every controller needs this helper to normalize the response:

```elixir
defp extract_results(data) when is_list(data), do: data
defp extract_results(%{"results" => results}) when is_list(results), do: results
defp extract_results(_), do: []
```

> **Tech debt:** This helper is duplicated across 7 controllers. Extract to a shared module (e.g., `AngleWeb.Helpers.QueryHelpers`) when refactoring.

> **Tech debt:** Several controllers also use direct `Ash.Query` calls for watchlist lookups (e.g., `load_watchlisted_map`, `load_watchlist_entry_id`). These should be refactored to code interfaces or typed queries when the watchlist feature is next modified.

### Mutations from controllers

Always use code interfaces for create/update/destroy operations.

```elixir
# RIGHT — code interface (target pattern)
def create(conn, params) do
  case Angle.Bidding.Bid.make_bid(params, actor: conn.assigns.current_user) do
    {:ok, bid} -> ...
    {:error, error} -> ...
  end
end

# WRONG — raw Ash changeset in controller
def create(conn, params) do
  Angle.Bidding.Bid
  |> Ash.Changeset.for_create(:make_bid, params, actor: conn.assigns.current_user)
  |> Ash.create()
end
```

---

## 4. Cross-Domain Communication

### Relationships

Resources reference other domains via relationships. Ash resolves the correct domain automatically.

```elixir
# In Inventory.Item — references Accounts.User
relationships do
  belongs_to :user, Angle.Accounts.User do
    source_attribute :created_by_id
  end
end
```

### Calling across domains

When resource code (changes, validations) needs data from **another domain**, prefer code interfaces. When code interfaces don't exist yet, direct `Ash.get` is acceptable inside domain code — but add a code interface when you get the chance.

```elixir
# BEST — code interface (add one if it doesn't exist)
{:ok, item} = Angle.Inventory.Item.get_item(item_id, authorize?: false)

# ACCEPTABLE inside domain code — direct Ash call when no code interface exists yet
{:ok, item} = Ash.get(Angle.Inventory.Item, item_id, authorize?: false)

# NEVER acceptable outside domain code (controllers, helpers, workers)
# Always go through code interface or typed query
```

Inside resource code (changes, validations, preparations) within the **same domain**, direct Ash calls are always fine — you're already inside the domain boundary.

---

## 5. Changes, Validations & Preparations

### When to extract to a separate file vs keep inline

**Extract to a dedicated module** (`lib/angle/<domain>/<resource>/<name>.ex`) when ANY of these are true:
- The logic loads external data (`Ash.get`, queries another resource)
- The logic has branching (`if`/`case`/`cond` with multiple paths)
- The logic is reused across multiple actions
- The logic exceeds ~10 lines of non-trivial code

**Keep inline** when:
- It's a built-in change/validation (e.g., `change set_attribute(...)`, `validate present(...)`)
- It's a simple `after_action`/`before_action` hook under ~10 lines with no branching
- The logic is straightforward and readable at a glance

```elixir
# FINE INLINE — simple, no branching, under 10 lines
change after_action(fn _changeset, user, _context ->
  case Angle.Accounts.User.assign_role(user, %{role_name: "bidder"}, authorize?: false) do
    {:ok, _} -> {:ok, user}
    {:error, _} -> {:ok, user}
  end
end)

# EXTRACT TO FILE — loads external data, has branching, 20+ lines
change {ValidateBidIsHigherThanCurrentPrice, []}
```

### How to reference in actions

```elixir
# Module name directly
change Angle.Bidding.Review.ValidateOrderEligibility

# Module with options (tuple form)
change {Angle.Bidding.Bid.ValidateBidIsHigherThanCurrentPrice, []}

# Built-in changes (inline)
change set_attribute(:user_id, actor(:id))
change set_attribute(:publication_status, :published)

# Built-in validations (inline)
validate present([:amount]), message: "Bid amount is required"
validate attribute_equals(:status, :payment_pending)

# Inline after_action hook
change after_action(fn _changeset, record, _context ->
  # side effect logic
  {:ok, record}
end)
```

### Naming conventions

File names communicate the module type — no subdirectories needed:

```
lib/angle/<domain>/<resource>/
  validate_<rule_name>.ex      # Changes that validate (use Ash.Resource.Change)
  set_<attribute_name>.ex      # Changes that set values
  schedule_<job_name>.ex       # Changes that schedule background work
  check_<condition>.ex         # Policy checks (use Ash.Policy.SimpleCheck)
  filter_<criteria>.ex         # Preparations
  <type_name>.ex               # Custom Ash types / enums
```

---

## 6. Typed Queries

Typed queries define the **data contract** between the Elixir backend and React frontend. They are defined on the **domain module** inside the `typescript_rpc` block.

### DSL syntax

```elixir
# In the domain module (e.g., lib/angle/inventory.ex)
typescript_rpc do
  resource Angle.Inventory.Item do
    # RPC actions (frontend can call these directly)
    rpc_action :list_items, :read
    rpc_action :create_draft_item, :create_draft

    # Typed query with field selection
    typed_query :homepage_item_card, :read do
      ts_result_type_name "HomepageItemCard"
      ts_fields_const_name "homepageItemCardFields"

      fields [
        :id,
        :title,
        :slug,
        :starting_price,
        :current_price,
        :end_time,
        :auction_status,
        :condition,
        :sale_type,
        :view_count,
        %{category: [:id, :name, :slug]}  # Nested relationship
      ]
    end
  end
end
```

### When to create a typed query

- Loading list data for an Inertia page (especially with nested relationships)
- Data shape needs to match a specific React component's props
- The same query shape is used across multiple pages

### When NOT to use a typed query

- Simple single-record lookups (use code interface instead)
- Internal operations that don't send data to the frontend
- One-off checks or existence queries

### Calling typed queries from controllers

```elixir
case AshTypescript.Rpc.run_typed_query(:angle, :homepage_item_card, params, conn) do
  %{"success" => true, "data" => data} -> extract_results(data)
  _ -> []
end
```

### Rules

- Name typed queries after the UI component they serve (e.g., `:seller_dashboard_card`, `:item_detail`)
- Include nested relationship data in the field list — don't make separate queries
- After adding/modifying typed queries, run `mix ash_typescript.codegen` to regenerate `ash_rpc.ts`

---

## 7. Aggregates & Calculations

### Prefer aggregates over in-memory computation

```elixir
# RIGHT — Ash aggregate (computed at DB level)
aggregates do
  count :bid_count, :bids, public?: true
  count :watcher_count, :watchlist_items, public?: true
  avg :avg_rating, :received_reviews, :rating, public?: true
end

# WRONG — loading all records and counting in controller
items = Angle.Inventory.Item.list_items!(seller_id: user.id)
bid_count = Enum.reduce(items, 0, fn item, acc -> acc + length(item.bids) end)
```

### When to use calculations vs aggregates

- **Aggregates:** Count, sum, average, min, max over relationships → use `aggregates` block
- **Calculations:** Derived values from the resource's own attributes or complex logic → use `calculations` block

Aggregates must have `public? true` to be used in typed queries.

---

## 8. The `authorize?: false` Convention

Use `authorize?: false` only in these contexts:

| Context | Why | Example |
|---------|-----|---------|
| Inside changes/validations | Loading related data for business logic | Fetching item to validate bid amount |
| Workers/background jobs | System-initiated operations, no user actor | Ending auctions via Oban |
| Auth flows | User not yet authenticated | Password reset, email confirmation |
| Tests/factories | Test data creation | `Ash.create!(Resource, params, authorize?: false)` |
| Seeds | Database initialization | Initial roles, categories |
| After-action hooks | Auto-assigning roles on registration | `User.assign_role(user, %{...}, authorize?: false)` |

**Never** use `authorize?: false` in controller actions where a user is performing an operation — always pass `actor: conn.assigns.current_user` instead.

---

## 9. File Organization

Keep resource modules **flat** — no subdirectories for changes vs validations vs types. File names communicate the category via naming convention.

```
lib/angle/<domain>/
  <domain>.ex                          # Domain module (typescript_rpc, extensions)
  <resource>.ex                        # Resource definition (code_interface, actions)
  <resource>/
    validate_<rule>.ex                 # Ash.Resource.Change that validates (loads data)
    set_<attribute>.ex                 # Ash.Resource.Change that sets values
    schedule_<job>.ex                  # Ash.Resource.Change that schedules work
    check_<condition>.ex               # Ash.Policy.SimpleCheck modules
    filter_<criteria>.ex               # Ash.Resource.Preparation modules
    <type_name>.ex                     # Custom Ash types / enums
  checks/
    <shared_check>.ex                  # Policy checks shared across resources in domain
  workers/
    <worker_name>.ex                   # Oban/AshOban workers
```

Do **not** create subdirectories like `<resource>/changes/` or `<resource>/types/` — the flat structure works well at typical resource scale (1-4 files).

---

## Quick Reference: Decision Tree

```
Need to read data for a React page?
  → List with nested data? → Typed query via run_typed_query
  → Simple single record? → Code interface on resource

Need to create/update/delete from a controller?
  → Code interface on resource (always)

Need business validation that loads external data?
  → Ash.Resource.Change module (not Validation)

Need pure attribute validation (no data loading)?
  → Ash.Resource.Validation (inline or module)

Need to transform data on write?
  → Ash.Resource.Change module on the resource

Need to trigger side effects after an action?
  → Ash.Resource.Change with after_action callback

Need computed data from relationships?
  → Aggregate (count/sum/avg) or Calculation

Need complex multi-step workflow?
  → Generic action or Reactor

Working inside a resource's own domain code?
  → Direct Ash calls are fine
```
