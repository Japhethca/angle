# AshTypescript Typed Queries — Where to Use in Angle

> **Reference:** https://hexdocs.pm/ash_typescript/typed-queries.html

## What Are Typed Queries?

Typed queries define field selection once in Elixir domain config, then auto-generate:

1. **Plain maps** — JSON-safe, no Ash struct metadata (solves Jason encoding errors)
2. **TypeScript result types** — full autocomplete and type checking
3. **Fields constants** — for client-side re-fetching with the same shape

They're designed for **server-side controller use** — fetching Ash data and passing it as Inertia props, with a matching TypeScript type on the React side.

## Current Problem in Angle

### Manual Map Construction in Auth Plug

`lib/angle_web/plugs/auth.ex:50-58` manually builds a user map for Inertia props:

```elixir
|> assign_prop(:auth, %{
  user: %{
    id: user.id,
    email: user.email,
    confirmed_at: user.confirmed_at,
    roles: user.active_roles || [],
    permissions: user_permissions
  },
  authenticated: true
})
```

This pattern is **duplicated** at line 101-109. Problems:

- No TypeScript type generated — frontend uses a hand-written `User` interface in `assets/js/types/auth.ts`
- Adding `full_name` or `phone_number` requires updating both the plug AND the TypeScript type
- No compile-time guarantee the map shape matches what React expects
- Relationship data (`roles`, `permissions`) is fetched via separate `Ash.load!` calls

### Dashboard Controller Stubs

`lib/angle_web/controllers/dashboard_controller.ex` returns hardcoded stats. When real data is fetched, the same manual-map-to-props problem will appear.

## Where Typed Queries Should Be Used

### 1. Auth User Prop (High Priority)

Replace the manual map in `plugs/auth.ex` with a typed query.

**Domain config** (`lib/angle/accounts.ex`):

```elixir
typescript_rpc do
  resource Angle.Accounts.User do
    rpc_action :list_users, :read

    typed_query :current_user_prop, :read do
      ts_result_type_name "CurrentUserProp"
      ts_fields_const_name "currentUserPropFields"
      fields [
        :id,
        :email,
        :full_name,
        :phone_number,
        :confirmed_at,
        %{roles: [:name], permissions: [:name]}
      ]
    end
  end
end
```

**Controller/plug usage:**

```elixir
case AshTypescript.Rpc.run_typed_query(
       Angle.Accounts,
       :current_user_prop,
       %{input: %{id: user.id}},
       conn
     ) do
  %{"success" => true, "data" => [user_data]} ->
    assign_prop(conn, :auth, %{user: user_data, authenticated: true})

  _ ->
    assign_prop(conn, :auth, %{user: nil, authenticated: false})
end
```

**React side** — replaces hand-written `User` in `assets/js/types/auth.ts`:

```typescript
import type { CurrentUserProp } from '@/ash_rpc';
```

### 2. Dashboard Page Data (Medium Priority)

When the dashboard fetches real data (items, bids, activity), define typed queries:

```elixir
typed_query :dashboard_items, :read do
  ts_result_type_name "DashboardItem"
  ts_fields_const_name "dashboardItemFields"
  fields [:id, :title, :starting_price, :publication_status, :inserted_at]
end

typed_query :dashboard_bids, :read do
  ts_result_type_name "DashboardBid"
  ts_fields_const_name "dashboardBidFields"
  fields [:id, :amount, :bid_type, :inserted_at, %{item: [:id, :title]}]
end
```

### 3. Item Listing/Detail Pages (Medium Priority)

Any page that shows items, categories, or bids from controller props:

```elixir
# In Inventory domain
typed_query :item_card, :read do
  ts_result_type_name "ItemCard"
  ts_fields_const_name "itemCardFields"
  fields [
    :id, :title, :slug, :starting_price, :condition, :sale_type,
    :publication_status, :inserted_at,
    %{category: [:id, :name, :slug], created_by: [:id, :email, :full_name]}
  ]
end
```

### 4. Client-Side Re-fetching After Mutations

The generated `*Fields` constants let you re-fetch with the same shape from React:

```typescript
import { listItems, itemCardFields } from '@/ash_rpc';
import { useAshQuery } from '@/hooks/use-ash-query';

const { data } = useAshQuery(
  ['items'],
  () => listItems({ fields: itemCardFields })
);
```

This keeps server-rendered props and client-refetched data in the same shape.

## What NOT to Use Typed Queries For

- **Auth pages** (login, register, etc.) — these don't load resource data as props
- **Simple scalar props** (like `%{token: token}` in reset-password) — too simple to warrant typed queries
- **RPC-only mutations** — already handled by `rpc_action` + `useAshMutation`

## Integration with Auth Redesign Plan

The auth redesign plan (`docs/plans/2026-02-12-auth-pages-redesign.md`) adds `full_name` and `phone_number` to the User resource. Typed queries would ensure:

1. The auth plug automatically includes new fields in props (single place to update)
2. TypeScript gets the updated type via `mix ash_typescript.codegen` (no manual type edits)
3. The verify-account page can re-fetch user data client-side with `currentUserPropFields`

**Recommended timing:** Introduce the `current_user_prop` typed query in Task 1 of the auth redesign (when adding `full_name` and `phone_number`), since the User resource and types are already being modified.

## Migration Path

1. Define `typed_query` in domain config
2. Run `mix ash_typescript.codegen` to regenerate types
3. Replace manual map construction in controller/plug with `run_typed_query/4`
4. Replace hand-written TypeScript interfaces with generated types
5. Use generated fields constants in `useAshQuery` calls for consistency
