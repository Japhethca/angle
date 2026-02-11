# Angle - Architecture Documentation

## Overview

Angle is a modern auction platform built with Elixir, Phoenix, and the Ash Framework. It provides a comprehensive bidding system with role-based access control, real-time updates, and a React-based SPA frontend.

## Technology Stack

### Backend

- **Elixir** - Functional programming language built on the Erlang VM
- **Phoenix Framework 1.0+** - Web framework providing routing, controllers, and real-time features
- **Ash Framework 3.0** - Declarative resource modeling and API generation
- **AshTypescript** - TypeScript code generation and type-safe RPC client
- **PostgreSQL** - Primary database with AshPostgres data layer
- **Oban** - Background job processing and scheduled tasks
- **Bandit** - HTTP server adapter

### Frontend

- **React 18+** - Component-based UI library
- **TypeScript** - Type-safe JavaScript
- **Inertia.js 2.5.1** - Modern SPA framework with server-side routing
- **Tailwind CSS 4.1.7** - Utility-first CSS framework
- **Shadcn UI** - Re-usable component library
- **esbuild 0.21.5** - JavaScript bundler

### API Layer

- **TypeScript RPC** - Type-safe client generated from Ash resources via AshTypescript
- **GraphQL** - Via AshGraphql with Absinthe
- **JSON:API** - Via AshJsonApi with OpenAPI/Swagger documentation
- **REST** - Phoenix controllers for traditional endpoints

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Frontend (React)                      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Pages      │  │  Components  │  │    Hooks     │      │
│  │              │  │              │  │              │      │
│  │ - Home       │  │ - Forms      │  │ - Auth       │      │
│  │ - Auth       │  │ - UI         │  │ - Channels   │      │
│  │ - Dashboard  │  │ - Layouts    │  │ - Permissions│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│                    Inertia.js (SPA Bridge)                   │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Phoenix Web Layer                         │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Router     │  │ Controllers  │  │   Plugs      │      │
│  │              │  │              │  │              │      │
│  │ - Browser    │  │ - Page       │  │ - Auth       │      │
│  │ - API        │  │ - Auth       │  │ - CORS       │      │
│  │ - GraphQL    │  │ - Dashboard  │  │ - Security   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│            ┌────────────────────────────────┐               │
│            │   Phoenix Channels (WebSocket) │               │
│            │   - Real-time bidding updates  │               │
│            └────────────────────────────────┘               │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Ash Framework Layer                       │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Domains    │  │  Resources   │  │   Actions    │      │
│  │              │  │              │  │              │      │
│  │ - Accounts   │  │ - User       │  │ - CRUD       │      │
│  │ - Inventory  │  │ - Item       │  │ - Custom     │      │
│  │ - Bidding    │  │ - Bid        │  │ - Validations│      │
│  │ - Catalog    │  │ - Category   │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Policies   │  │ Calculations │  │ Relationships│      │
│  │              │  │              │  │              │      │
│  │ - RBAC       │  │ - has_role?  │  │ - belongs_to │      │
│  │ - Permissions│  │ - active_roles│ │ - has_many   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                      Data Layer                              │
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  PostgreSQL  │  │  AshPostgres │  │    Oban      │      │
│  │              │  │              │  │              │      │
│  │ - Tables     │  │ - Queries    │  │ - Jobs       │      │
│  │ - Indexes    │  │ - Migrations │  │ - Scheduling │      │
│  │ - Constraints│  │ - Snapshots  │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Domain Architecture

Angle is organized into four main Ash domains:

### 1. Accounts Domain (`Angle.Accounts`)

Handles user management, authentication, and authorization.

**Resources:**
- `User` - User accounts with email/password authentication
- `Token` - JWT tokens for authentication
- `Role` - User roles (admin, seller, user, viewer)
- `Permission` - Granular permissions for resources
- `UserRole` - Many-to-many mapping between users and roles
- `RolePermission` - Many-to-many mapping between roles and permissions

**Key Features:**
- Email/password authentication via AshAuthentication
- Password reset with email tokens
- User confirmation via email
- JWT token management
- Role-based access control (RBAC)
- Permission system with calculations (`has_role?`, `has_permission?`, `active_roles`)

### 2. Inventory Domain (`Angle.Inventory`)

Manages auction items and their lifecycle.

**Resources:**
- `Item` - Auction items/listings
- `ItemActivity` - Activity tracking for items

**Item Attributes:**
- Basic: title, description, slug, lot_number
- Pricing: starting_price, reserve_price, current_price, bid_increment, buy_now_price
- Timing: start_time, end_time
- Status: publication_status (draft/published), auction_status (pending/scheduled/active/ended/sold/cancelled)
- Metadata: condition, location, attributes (JSON), view_count
- Categories: category_id relationship
- Types: sale_type (auction/buy_now/hybrid), auction_format (standard/reserve/live/timed)

**Key Features:**
- Draft workflow for item creation
- Publication status management
- Auction status tracking
- Owner-based access control
- Category organization

### 3. Bidding Domain (`Angle.Bidding`)

Handles the bidding system and bid validation.

**Resources:**
- `Bid` - Individual bids on items

**Bid Attributes:**
- amount (decimal)
- bid_type (from BidType enum)
- item_id (foreign key)
- user_id (foreign key)
- bid_time (timestamp)

**Key Features:**
- Bid validation against current price
- Automatic bidder assignment
- Real-time bid updates via Phoenix Channels
- Permission-based bid placement

### 4. Catalog Domain (`Angle.Catalog`)

Organizes items into categories and manages product attributes.

**Resources:**
- `Category` - Item categorization
- `OptionSet` - Configurable attribute sets
- `OptionSetValue` - Individual values for option sets

**Key Features:**
- Hierarchical category structure
- Flexible attribute system via option sets
- JSON:API exposure for public browsing

## Authentication & Authorization

### Authentication Flow

1. **Registration:**
   ```
   User submits email/password → User.register_with_password action
   → Hash password → Create user → Send confirmation email → Return JWT
   ```

2. **Login:**
   ```
   User submits credentials → User.sign_in_with_password action
   → Validate password → Generate JWT → Return token
   ```

3. **Token Refresh:**
   ```
   Client sends JWT → User.get_by_subject action
   → Validate token → Return user data
   ```

### Authorization (RBAC)

The system uses a comprehensive role-based access control system:

**Roles:**
- **Admin** - Full system access
- **Seller** - Can create and manage listings
- **User** - Can place bids
- **Viewer** - Read-only access

**Permission Scopes:**
- `system` - Global permissions
- `own` - Restricted to owned resources

**Key Permissions:**
- `manage_users` - User management
- `create_items`, `update_own_items`, `delete_own_items` - Item management
- `publish_items` - Make items public
- `place_bids`, `view_bids`, `manage_bids` - Bidding
- `manage_catalog` - Category/attribute management

### Policy Checks

Policies are defined at the resource level using Ash's policy system:

```elixir
policy action(:make_bid) do
  authorize_if expr(
    user_id == ^actor(:id) and
    exists(
      actor.user_roles,
      exists(role.role_permissions, permission.name == "place_bids")
    )
  )
end
```

## API Endpoints

### TypeScript RPC Endpoints

```
POST /rpc/run                   # Execute Ash actions (requires auth)
POST /rpc/validate              # Validate action inputs
```

**Generated TypeScript client:**
```typescript
import { Bidding, Inventory } from '@/ash_rpc';

// Type-safe RPC calls
await Bidding.Bid.makeBid({ amount: '150.00', itemId: 'uuid' });
await Inventory.Item.read();
```

### REST Endpoints (Browser)

```
GET  /                          # Home page
GET  /dashboard                 # User dashboard (auth required)

# Authentication
GET  /auth/login                # Login page
POST /auth/login                # Submit login
GET  /auth/register             # Registration page
POST /auth/register             # Submit registration
GET  /auth/forgot-password      # Password reset request
POST /auth/forgot-password      # Submit reset request
GET  /auth/reset-password/:token # Reset password page
POST /auth/reset-password       # Submit new password
GET  /auth/confirm-new-user/:token # Email confirmation
POST /auth/logout               # Logout
```

### JSON:API Endpoints

```
# Items
GET    /api/v1/items            # List items
POST   /api/v1/items            # Create item
POST   /api/v1/items/draft      # Create draft item
PATCH  /api/v1/items/draft/:id  # Update draft
PATCH  /api/v1/items/publish    # Publish item

# Bids
GET    /api/v1/bids             # List bids
POST   /api/v1/bids/make        # Place bid

# Documentation
GET    /api/v1/public/docs      # Swagger UI
```

### GraphQL Endpoints

```
POST /gql                       # GraphQL API
GET  /gql/playground            # GraphiQL playground
```

**Available Queries:**
- `bid(id: ID!)` - Get single bid
- `bids` - List bids

**Available Mutations:**
- `makeBid(input: MakeBidInput!)` - Place a bid

### Admin Endpoints (Development Only)

```
GET  /admin                     # AshAdmin interface
GET  /dev/dashboard             # Phoenix LiveDashboard
GET  /dev/mailbox               # Email preview
```

## Data Flow

### Making a Bid

1. User clicks "Place Bid" in React UI
2. React form validates input locally
3. Form submits via Inertia.js or API call
4. Phoenix router routes to appropriate handler
5. Ash action `Bid.make_bid` is invoked
6. Validations run:
   - User has `place_bids` permission
   - Bid amount > current price
   - Item is active
7. Bid record created in database
8. Phoenix Channel broadcasts update to all watchers
9. Response returned to client
10. UI updates with new bid

### Creating an Item

1. Seller navigates to "Create Listing" page
2. Fills out item form (React component)
3. Submits form → POST to `/api/v1/items/draft`
4. `Item.create_draft` action validates and creates item
5. Item created with `publication_status: :draft`
6. Seller can preview and edit
7. When ready, calls `publish_item` action
8. Item becomes visible to public

## Database Schema

### Key Tables

**users**
- id (uuid, PK)
- email (citext, unique)
- hashed_password (string)
- confirmed_at (timestamp)
- inserted_at, updated_at

**roles**
- id (uuid, PK)
- name (string, unique)
- description (text)
- scope (string)
- active (boolean)

**permissions**
- id (uuid, PK)
- name (string, unique)
- resource (string)
- action (string)
- scope (string)
- description (text)

**user_roles** (join table)
- id (uuid, PK)
- user_id (uuid, FK)
- role_id (uuid, FK)
- expires_at (timestamp, nullable)
- granted_by_id (uuid, FK, nullable)

**role_permissions** (join table)
- id (uuid, PK)
- role_id (uuid, FK)
- permission_id (uuid, FK)

**items**
- id (uuid, PK)
- title (string)
- description (text)
- starting_price (decimal)
- current_price (decimal)
- reserve_price (decimal)
- bid_increment (decimal)
- buy_now_price (decimal)
- slug (string)
- start_time, end_time (timestamp)
- publication_status (enum: draft/published)
- auction_status (enum: pending/scheduled/active/ended/sold/cancelled)
- condition (enum: new/used/refurbished)
- sale_type (enum: auction/buy_now/hybrid)
- auction_format (enum: standard/reserve/live/timed)
- category_id (uuid, FK)
- created_by_id (uuid, FK)
- attributes (jsonb)
- view_count (integer)

**bids**
- id (uuid, PK)
- amount (decimal)
- bid_type (enum)
- item_id (uuid, FK)
- user_id (uuid, FK)
- bid_time (timestamp)

**categories**
- id (uuid, PK)
- name (string)
- description (text)

## Frontend Architecture

### React Structure

```
assets/js/
├── components/
│   ├── ui/              # Shadcn UI components
│   ├── auth/            # Auth-related components
│   │   ├── protected-route.tsx
│   │   ├── permission-guard.tsx
│   │   └── logout-button.tsx
│   ├── forms/           # Form components
│   │   ├── login-form.tsx
│   │   ├── register-form.tsx
│   │   ├── item-form.tsx
│   │   └── bid-form.tsx
│   ├── bidding/         # Bidding components
│   ├── layouts/         # Layout components
│   └── navigation/      # Navigation components
├── pages/               # Inertia.js pages
│   ├── auth/
│   ├── admin/
│   ├── home.tsx
│   └── dashboard.tsx
├── hooks/               # React hooks
│   ├── use-phoenix-channel.tsx
│   ├── use-bidding-channel.tsx
│   └── use-permissions.ts
├── contexts/            # React contexts
│   └── auth-context.tsx
├── types/               # TypeScript types
│   └── auth.ts
├── lib/                 # Utilities
│   └── utils.ts
├── app.tsx              # Client-side entry
└── ssr.tsx              # Server-side rendering entry
```

### Inertia.js Integration

Inertia.js provides SPA-like navigation without building an API:

- **Server-side routing** - Routes defined in Phoenix router
- **Props passing** - Data passed from Phoenix controllers to React
- **Shared data** - Flash messages, CSRF tokens, auth data
- **SSR support** - Server-side rendering enabled for SEO

### State Management

- **Auth Context** - Global auth state via React Context
- **Inertia Props** - Server-provided data
- **Phoenix Channels** - Real-time updates
- **Local State** - Component-level with `useState`

## Real-time Features

### Phoenix Channels

Channels provide WebSocket-based real-time communication:

**Bidding Channel:**
- Topic: `bidding:item_#{item_id}`
- Events: `new_bid`, `bid_update`, `auction_ended`
- Used for live bid updates

**Implementation:**
```typescript
// Frontend hook
const { state, subscribe } = usePhoenixChannel('bidding:item_123');

// Backend channel (to be implemented)
defmodule AngleWeb.BiddingChannel do
  def handle_in("new_bid", payload, socket) do
    # Broadcast to all subscribers
    broadcast(socket, "new_bid", payload)
  end
end
```

## Background Jobs

Oban handles background processing:

- Email sending (confirmation, password reset)
- Auction status updates
- Scheduled task execution

Configuration in `config/config.exs`:
```elixir
config :angle, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10],
  repo: Angle.Repo
```

## Security Considerations

### Authentication
- Passwords hashed with bcrypt
- JWT tokens with signing secrets
- Token revocation via database storage
- Email confirmation required

### Authorization
- Policy-based access control
- All Ash actions protected by policies
- Row-level security via Ash filters
- Actor-based authorization

### Web Security
- CSRF protection via Phoenix
- Secure headers via Phoenix
- SQL injection prevention via Ecto/Ash
- XSS prevention via React

## Performance Optimization

### Database
- Indexes on frequently queried fields
- Composite indexes for complex queries
- Check constraints for data integrity
- Connection pooling via Postgrex

### Frontend
- Code splitting via esbuild
- Asset minification in production
- SSR for initial page load
- Lazy loading of components

### Caching
- Database query caching (future)
- Static asset caching
- CDN for asset delivery (production)

## Testing Strategy

### Backend Testing
```bash
mix test                    # Run all tests
mix test path/to/test.exs   # Run specific test
mix test --failed           # Run previously failed tests
```

### Frontend Testing
- Component tests (to be added)
- Integration tests (to be added)
- E2E tests (to be added)

## Development Workflow

### Setting Up
```bash
git clone <repository>
cd angle
mix setup                   # Install deps, setup DB, build assets
mix phx.server              # Start server
```

### Common Tasks
```bash
mix ash.setup               # Setup Ash resources and DB
mix ecto.reset              # Reset database
mix assets.build            # Build frontend assets
mix test                    # Run tests
```

### Database Migrations

Ash generates and manages migrations:
```bash
mix ash.codegen             # Generate migrations from resources
mix ash_postgres.migrate    # Run migrations
```

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

## Additional Resources

- [API Documentation](API.md)
- [Frontend Guide](FRONTEND.md)
- [Deployment Guide](DEPLOYMENT.md)
- [Ash Framework Docs](https://hexdocs.pm/ash)
- [Phoenix Framework Docs](https://hexdocs.pm/phoenix)
- [Inertia.js Docs](https://inertiajs.com)
