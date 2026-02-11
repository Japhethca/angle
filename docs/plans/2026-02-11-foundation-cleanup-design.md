# Foundation Cleanup Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prepare the Angle codebase for easy AI-assisted feature development by fixing broken foundations, establishing patterns, and documenting architectural decisions.

**Architecture:** Phoenix + Ash backend, React + Inertia.js frontend, AshTypescript HTTP RPC for mutations. No LiveView. Channel RPC reserved for future real-time features only.

**Tech Stack:** Elixir 1.18 / Phoenix / Ash Framework / React 19 / Inertia.js / AshTypescript / PostgreSQL / shadcn/ui / Lucide React

---

## Architectural Decisions

These decisions were made during brainstorming and apply to all future development:

### UI Layer

| Concern | Approach |
|---------|----------|
| Component library | shadcn/ui (54 components already installed in `assets/js/components/ui/`) |
| Icons | Lucide React (`lucide-react` package) |
| Styling | Tailwind CSS |
| Forms | React Hook Form + Zod validation |
| Async state / data fetching | TanStack Query (React Query) - caching, loading/error states, mutations |

### Communication Patterns

| Concern | Approach |
|---------|----------|
| Page data loading | Inertia props (loaded in Phoenix controllers, passed to React pages) |
| Mutations & queries from frontend | AshTypescript HTTP RPC (`/rpc/run`, `/rpc/validate`) |
| Real-time updates (future) | AshTypescript Channel RPC + Phoenix Channel broadcasts |
| Page navigation | Inertia.js (`router.visit`, `router.post`) |

### Default Pattern for Every Feature

1. **Controller** loads data from Ash resources, passes as Inertia props
2. **React page** renders with those props (SSR-friendly)
3. **User actions** (create, update, delete) call AshTypescript generated functions via HTTP RPC
4. **After mutation** succeeds, redirect via Inertia or refresh props

### When to Use Channel RPC (Future)

Only for features requiring real-time bidirectional communication:
- Active auction/bidding pages where multiple users need instant updates
- The pattern: AshTypescript Channel RPC for mutations + custom `after_action` broadcasts for push updates
- Existing `usePhoenixChannel` and `useBiddingChannel` hooks will handle receiving broadcasts

---

## Task 0: Update Dependencies

**Goal:** Bring all Elixir and npm packages to their latest compatible versions before doing any other work.

**Elixir dependencies:**

Update version pins in `mix.exs` and run `mix deps.get && mix deps.compile`:

| Package | Current | Target | Action |
|---------|---------|--------|--------|
| `ash` | 3.7.2 | 3.16.0 | Update pin |
| `ash_typescript` | 0.5.0 | 0.14.3 | Update pin (critical for RPC plan) |
| `ash_authentication` | 4.9.8 | 4.13.7 | Update pin |
| `ash_graphql` | 1.8.0 | 1.8.5 | Update pin |
| `ash_json_api` | 1.4.38 | 1.5.1 | Update pin |
| `ash_oban` | 0.4.10 | 0.7.1 | Update pin |
| `ash_postgres` | 2.6.11 | 2.6.32 | Update pin |
| `ash_phoenix` | 2.3.17 | 2.3.19 | Update pin |
| `ash_money` | 0.2.3 | 0.2.5 | Update pin |
| `ash_admin` | 0.13.12 | 0.14.0 | Update pin |
| `phoenix` | 1.8.1 | 1.8.3 | Update pin |
| `phoenix_live_view` | 1.1.3 | 1.1.22 | Loosen pin |
| `phoenix_ecto` | 4.6.5 | 4.7.0 | Update pin |
| `postgrex` | 0.20.0 | 0.22.0 | Update pin |
| `oban` | 2.19.4 | 2.20.3 | Update pin |
| `swoosh` | 1.19.3 | 1.21.0 | Update pin |
| `bandit` | 1.8.0 | 1.10.2 | Update pin |
| `inertia` | 2.5.1 | 2.6.0 | Loosen pin |
| `gettext` | 0.26.2 | 1.0.2 | Loosen pin |
| `reactor` | 0.17.0 | 1.0.0 | Loosen pin |
| `usage_rules` | 0.1.23 | 1.1.0 | Loosen pin (dev only) |
| `git_hooks` | 0.7.4 | 0.8.1 | Loosen pin (dev only) |
| Dev tools (`claude`, `credo`, `igniter`, `tidewave`, etc.) | various | latest | Update pins |

**Approach:**
1. Update all version pins in `mix.exs`
2. Run `mix deps.get`
3. Run `mix compile` - fix any deprecation warnings or breaking changes
4. Run `mix test` - fix any test breakage
5. Check for new migrations needed: `mix ash.codegen check_migrations`
6. If Ash generated migration changes, run `mix ecto.migrate`

**npm dependencies:**

Update in `assets/` directory:

| Package | Current | Target | Notes |
|---------|---------|--------|-------|
| `react` / `react-dom` | 19.1.1 | 19.2.4 | |
| `@inertiajs/react` | 2.0.17 | 2.3.14 | |
| `zod` | 4.0.14 | 4.3.6 | |
| `react-hook-form` | 7.61.1 | 7.71.1 | |
| `lucide-react` | 0.535.0 | 0.563.0 | |
| `sonner` | 2.0.6 | 2.0.7 | |
| `tailwind-merge` | 3.3.1 | 3.4.0 | |
| `tw-animate-css` | 1.3.6 | 1.4.0 | |
| `phoenix` (JS) | 1.8.0 | 1.8.3 | |
| All `@radix-ui/*` | various | latest minor | shadcn/ui deps |
| `@types/react` / `@types/react-dom` | 19.1.x | 19.2.x | |
| `prettier` | 3.5.2 | 3.8.1 | |
| `@typescript-eslint/*` | 8.24.0 | 8.55.0 | |
| `eslint` | 9.24.0 | **9.x latest** | Stay on 9.x, skip 10.0 major for now |
| `react-resizable-panels` | 3.0.4 | **3.x latest** | Skip 4.x major for now |

**Approach:**
1. Run `npx npm-check-updates -u --reject eslint,react-resizable-panels,recharts` (skip major version jumps)
2. Manually update `eslint` and `react-resizable-panels` to latest within current major
3. Run `npm install`
4. Run `npm run lint` to verify no new lint errors
5. Build assets: `mix assets.build` to verify compilation

**Skip major version jumps** for `eslint` (9→10) and `react-resizable-panels` (3→4) to avoid breaking changes. These can be updated separately later.

**Verification:**
- `mix compile --warnings-as-errors` passes
- `mix test` passes
- `mix assets.build` succeeds
- Frontend loads without console errors

---

## Task 1: AshTypescript HTTP RPC Setup

**Goal:** Make the generated TypeScript RPC functions usable from React components.

**Current state:**
- `ash_rpc.ts` is generated but never imported anywhere
- RPC controller exists at `lib/angle_web/controllers/ash_typescript_rpc_controller.ex`
- Routes exist: `POST /rpc/run` and `POST /rpc/validate`
- Config in `config/config.exs` lines 10-22

**Work:**
- Regenerate `ash_rpc.ts` to ensure it reflects current resources and actions (`mix ash_typescript.generate`)
- Verify the generated file exports typed functions for key resources (User, Item, Bid, Category)
- Install TanStack Query (`npm install @tanstack/react-query` in assets/)
- Add `QueryClientProvider` to the app layout (wrapping the Inertia app in both `app.tsx` and `ssr.tsx`)
- Create a thin wrapper hook (e.g. `assets/js/hooks/use-ash-query.ts`) that combines TanStack Query with AshTypescript functions as a reference pattern
- Verify a round-trip works: React component uses `useQuery` + AshTypescript function, gets typed data back with loading/error states
- Document the import and query pattern for future use

**Verification:**
- A React component can import a function from `ash_rpc.ts` via `useQuery`, and receive typed data with loading/error states
- `QueryClientProvider` wraps the app in both client and SSR entry points
- No TypeScript compilation errors in the generated file

---

## Task 2: Clean Up Debug Artifacts and Dead Code

**Goal:** Remove noise that confuses developers and AI when reading the codebase.

**Backend cleanup:**
- Remove 9 `Logger.error("DEBUG AUTH: ...")` calls from `lib/angle_web/plugs/auth.ex`
- Remove `dbg()` calls from `lib/angle/bidding/bid/validate_bid_is_higher_than_current_price.ex`
- Remove unused `ValidateAmount` module at `lib/angle/bidding/bid/validate_amount.ex`
- Remove sample `say_hello` query from `lib/angle_web/graphql_schema.ex`
- Remove `IO.puts("Validating bid amount...")` stub from `lib/angle/bidding/bid.ex`

**Frontend cleanup:**
- Remove `console.log` debug statements from:
  - `assets/js/app.tsx` (line 13 - "Resolving page:")
  - `assets/js/app.tsx` (line 25 - "hyrdating root:")
  - `assets/js/ssr.tsx` (line 12 - "SSR rendering page:")
  - `assets/js/components/navigation/main-nav.tsx` (lines 8-15 - debug auth state)
  - `assets/js/hooks/use-bidding-channel.tsx` (lines 34, 37 - channel connection logs)
- Remove unused npm packages: `next-themes`, `recharts`, `cmdk`
- Keep `lucide-react` - this is the chosen icon library

**Verification:**
- `mix compile --warnings-as-errors` passes
- `grep -r "Logger.error.*DEBUG" lib/` returns nothing
- `grep -r "console.log" assets/js/ --include="*.tsx" --include="*.ts"` returns nothing (excluding node_modules)

---

## Task 3: Test Infrastructure

**Goal:** Establish a green test baseline with reusable test helpers.

**Fix failing test:**
- Update `test/angle_web/controllers/page_controller_test.exs` to test for Inertia response instead of static text "Peace of mind from prototype to production"

**Create test factory:**
- Create `test/support/factory.ex` with helper functions to create test data:
  - `create_user/1` - creates a user with defaults, accepts overrides
  - `create_role/1` - creates a role
  - `create_item/1` - creates an item (requires a user as creator)
  - `create_bid/1` - creates a bid (requires user and item)
  - `create_category/1` - creates a category
- All factory functions use `authorize?: false` to bypass policies
- Import factory in `DataCase` and `ConnCase` so it's available in all tests

**Smoke test:**
- Add one resource smoke test (e.g. `test/angle/accounts/user_test.exs`) that creates a user and reads it back
- Proves the test infrastructure and factory work together

**Verification:**
- `mix test` passes with 0 failures
- Factory module compiles and is importable in test files

---

## Task 4: Implement Bid Validation

**Goal:** Replace the stubbed bid validation with working business logic.

**Current state:**
- `ValidateBidIsHigherThanCurrentPrice.change/3` just returns the changeset unchanged
- `before_action` in `bid.ex` just prints to console
- No validation that bid amount > item's current price

**Work:**
- Implement `ValidateBidIsHigherThanCurrentPrice`:
  - Load the item associated with the bid
  - Compare bid amount against item's `current_price` (or `starting_price` if no bids yet)
  - Add error to changeset if bid is too low
- Remove the `before_action` IO.puts stub from `bid.ex` (already removed in Task 2)
- Write tests:
  - Bid with amount above current price succeeds
  - Bid with amount equal to or below current price fails with descriptive error

**Verification:**
- `mix test` passes including new bid validation tests
- Invalid bids are rejected with a clear error message

---

## Task 5: Complete API Surface

**Goal:** Ensure all Ash resources are accessible through configured API layers.

**GraphQL:**
- Add `Angle.Accounts` and `Angle.Inventory` to domains list in `lib/angle_web/graphql_schema.ex`
- Add `AshGraphql.Resource` extension to `Angle.Inventory.Item` resource
- Verify the GraphQL playground at `/gql/playground` shows queries for all domains

**Email senders:**
- Replace `"noreply@example.com"` placeholder in:
  - `lib/angle/accounts/user/senders/send_new_user_confirmation_email.ex`
  - `lib/angle/accounts/user/senders/send_password_reset_email.ex`
- Use application config: `Application.get_env(:angle, :sender_email, {"Angle", "noreply@angle.app"})`

**Verification:**
- GraphQL playground shows User, Item, Bid, Category queries
- Email senders reference a configurable address, not a hardcoded TODO

---

## Task 6: Update CLAUDE.md

**Goal:** Document architectural decisions so every AI session starts with correct context.

**Add sections:**

### Communication Architecture
- Inertia props for page data loading
- AshTypescript HTTP RPC for frontend mutations/queries
- Pattern: controller loads data → Inertia props → React page → AshTypescript RPC for user actions
- Channel RPC reserved for real-time features only (future)

### UI Stack
- Component library: shadcn/ui (components in `assets/js/components/ui/`)
- Icons: Lucide React (`import { IconName } from "lucide-react"`)
- Styling: Tailwind CSS
- Forms: React Hook Form + Zod for validation
- Data fetching: TanStack Query wrapping AshTypescript RPC functions
- Never use inline SVGs for icons - always use Lucide
- Always use `useQuery`/`useMutation` from TanStack Query for RPC calls - never raw `useState` + `useEffect`

### Adding a New Feature (Checklist)
1. Define or update Ash resource with actions
2. Regenerate `ash_rpc.ts` (`mix ash_typescript.generate`)
3. Create Phoenix controller that loads data and renders Inertia page
4. Add route in `router.ex`
5. Create React page in `assets/js/pages/`
6. Use generated AshTypescript functions for mutations
7. Write tests using factory module

### File Conventions
- React pages: `assets/js/pages/<page-name>.tsx` (kebab-case)
- React components: `assets/js/components/<feature>/<component-name>.tsx`
- Ash resources: `lib/angle/<domain>/<resource>.ex`
- Tests: mirror `lib/` structure under `test/`
- Test factories: `test/support/factory.ex`

### Testing
- Run: `mix test`
- Use factory functions from `test/support/factory.ex` to create test data
- All factory functions bypass authorization with `authorize?: false`
- Test pattern: create data with factory, exercise action, assert result

**Update existing sections:**
- Remove any references to LiveView patterns
- Ensure API endpoints section is current

**Verification:**
- CLAUDE.md accurately reflects the codebase state after Tasks 1-5

---

## Future: Channel RPC + Real-Time Broadcasts (Not Now)

This section is captured for when the bidding feature is built. Do not implement until then.

### Enable Channel RPC
```elixir
# config/config.exs
config :ash_typescript,
  generate_phx_channel_rpc_actions: true
```

### Backend Setup
- Create `AngleWeb.AshTypescriptRpcChannel` module
- Handle `"run"` and `"validate"` messages, delegating to `AshTypescript.Rpc`
- Set `socket.assigns.ash_actor` from authenticated user during socket connection
- Add channel route in `UserSocket`: `channel "ash_typescript_rpc:*", AngleWeb.AshTypescriptRpcChannel`

### Broadcast Pattern
- Add `after_action` callback on `Bid.make_bid` that broadcasts to item-specific channel
- Broadcast includes new bid data (amount, bidder, timestamp)
- Frontend `useBiddingChannel` hook receives broadcast and updates UI

### Frontend Pattern
- Use generated `*Channel` functions (e.g. `makeBidChannel(...)`) for mutations on active auction pages
- Use `useBiddingChannel` hook for receiving server-pushed updates
- Fall back to HTTP RPC functions on non-real-time pages
