# Angle - Modern Auction Platform

> A comprehensive auction platform built with Elixir, Phoenix, Ash Framework, and React

Angle is a full-featured auction platform that provides real-time bidding, role-based access control, and a modern single-page application experience. Built on a robust tech stack combining the power of Elixir/Phoenix with the flexibility of Ash Framework and the rich user experience of React.

## Features

- 🔐 **Authentication & Authorization** - Email/password auth with JWT tokens, role-based access control (RBAC), and granular permissions
- 📦 **Inventory Management** - Create and manage auction items with draft/publish workflow
- 💰 **Bidding System** - Real-time bidding with validation and permission checks
- 🎨 **Modern UI** - React SPA with Inertia.js, Tailwind CSS, and Shadcn UI components
- 🚀 **Real-time Updates** - Phoenix Channels for live bid updates
- 📊 **Multiple APIs** - REST (JSON:API), GraphQL, and traditional server-rendered endpoints
- 🔍 **Admin Interface** - Built-in AshAdmin for resource management
- 📧 **Email Notifications** - User confirmation and password reset emails
- 🎯 **Type Safety** - TypeScript frontend with comprehensive type definitions

## Tech Stack

### Backend
- **Elixir 1.15+** - Functional, concurrent programming language
- **Phoenix Framework** - Web framework with real-time capabilities
- **Ash Framework 3.0** - Declarative domain modeling and API generation
- **AshTypescript** - TypeScript code generation and type-safe RPC
- **PostgreSQL** - Primary database
- **Oban** - Background job processing

### Frontend
- **React 18+** - UI library
- **TypeScript** - Type-safe JavaScript
- **Inertia.js** - SPA framework with server-side routing
- **Tailwind CSS** - Utility-first styling
- **Shadcn UI** - Component library

### API Layer
- **AshTypescript RPC** - Type-safe RPC client generated from Ash resources
- **AshGraphql** - GraphQL API via Absinthe
- **AshJsonApi** - JSON:API with OpenAPI documentation
- **Phoenix Controllers** - Traditional REST endpoints

## Quick Start

### Prerequisites

- Elixir 1.15 or later ([Install Elixir](https://elixir-lang.org/install.html))
- PostgreSQL 12+ ([Install PostgreSQL](https://www.postgresql.org/download/))
- Node.js 16+ (for frontend assets)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd angle
   ```

2. **Setup the project**
   ```bash
   mix setup
   ```
   This command will:
   - Install Elixir dependencies
   - Setup the database and run migrations
   - Install and build frontend assets
   - Seed the database with initial roles and permissions

3. **Start the Phoenix server**
   ```bash
   mix phx.server
   ```
   Or start with an interactive Elixir shell:
   ```bash
   iex -S mix phx.server
   ```

4. **Visit the application**
   - Main app: [http://localhost:4000](http://localhost:4000)
   - RPC Endpoints: POST `/rpc/run` and `/rpc/validate`
   - GraphQL Playground: [http://localhost:4000/gql/playground](http://localhost:4000/gql/playground)
   - API Docs: [http://localhost:4000/api/v1/public/docs](http://localhost:4000/api/v1/public/docs)
   - Admin Panel: [http://localhost:4000/admin](http://localhost:4000/admin)
   - LiveDashboard: [http://localhost:4000/dev/dashboard](http://localhost:4000/dev/dashboard)
   - Mailbox: [http://localhost:4000/dev/mailbox](http://localhost:4000/dev/mailbox)

## Project Structure

```
angle/
├── assets/                 # Frontend code (React/TypeScript)
│   ├── js/
│   │   ├── components/    # React components
│   │   ├── pages/         # Inertia.js pages
│   │   ├── hooks/         # Custom React hooks
│   │   └── types/         # TypeScript types
│   └── css/               # Tailwind CSS
├── config/                # Application configuration
├── docs/                  # Documentation
│   ├── ARCHITECTURE.md    # System architecture
│   ├── API.md            # API documentation
│   ├── FRONTEND.md       # Frontend guide
│   └── DEPLOYMENT.md     # Deployment guide
├── lib/
│   ├── angle/            # Core business logic (Ash domains)
│   │   ├── accounts/     # User management & auth
│   │   ├── bidding/      # Bidding system
│   │   ├── catalog/      # Categories & attributes
│   │   └── inventory/    # Auction items
│   └── angle_web/        # Web layer (Phoenix)
│       ├── controllers/  # Phoenix controllers
│       ├── channels/     # WebSocket channels
│       └── router.ex     # Route definitions
├── priv/
│   ├── repo/
│   │   ├── migrations/   # Database migrations
│   │   └── seeds.exs     # Seed data
│   └── static/           # Compiled static assets
└── test/                 # Test files
```

## Domain Architecture

Angle is organized into four main Ash domains:

### 1. Accounts (`Angle.Accounts`)
Manages users, authentication, roles, and permissions.

**Resources:**
- User - User accounts with email/password auth
- Token - JWT authentication tokens
- Role - User roles (admin, seller, user, viewer)
- Permission - Granular resource permissions
- UserRole - User-to-role assignments
- RolePermission - Role-to-permission assignments

### 2. Inventory (`Angle.Inventory`)
Manages auction items and their lifecycle.

**Resources:**
- Item - Auction listings with pricing, timing, and status
- ItemActivity - Activity tracking for items

### 3. Bidding (`Angle.Bidding`)
Handles the bidding system.

**Resources:**
- Bid - Individual bids with validation

### 4. Catalog (`Angle.Catalog`)
Organizes items into categories.

**Resources:**
- Category - Item categorization
- OptionSet - Configurable attributes
- OptionSetValue - Attribute values

## Common Tasks

### Development

```bash
# Start the server
mix phx.server

# Run tests
mix test

# Run specific test file
mix test test/angle/accounts_test.exs

# Interactive Elixir shell
iex -S mix

# Format code
mix format

# Check code quality
mix credo

# Run strict code analysis
mix credo --strict

# Generate TypeScript types from Ash resources
mix ash_typescript.generate
```

### TypeScript Type Generation

Generate type-safe TypeScript client from your Ash resources:

```bash
# Generate types and RPC client
mix ash_typescript.generate

# Output: assets/js/ash_rpc.ts
```

This creates:
- TypeScript interfaces for all Ash resources (User, Item, Bid, etc.)
- Type-safe RPC client functions
- Validation helpers

**Usage in React:**
```tsx
import { Bidding } from '@/ash_rpc';

// Type-safe RPC call with autocomplete
const result = await Bidding.Bid.makeBid({
  amount: '150.00',
  itemId: itemId
});
```

### Git Hooks

The project uses pre-commit and pre-push hooks to ensure code quality:

**Pre-commit hooks (run before every commit):**
- `mix format --check-formatted` - Ensures all code is properly formatted
- `mix credo` - Runs static code analysis

**Pre-push hooks (run before every push):**
- `mix test --color` - Runs the test suite

The hooks are automatically installed when you run `mix deps.get` in development mode. To manually reinstall hooks:

```bash
mix git_hooks.install
```

To bypass hooks (not recommended):
```bash
git commit --no-verify
git push --no-verify
```

### Database

```bash
# Setup database (create, migrate, seed)
mix ash.setup

# Reset database
mix ecto.reset

# Generate migrations from Ash resources
mix ash.codegen

# Run migrations
mix ash_postgres.migrate

# Rollback migration
mix ash_postgres.rollback
```

### Assets

```bash
# Build frontend assets
mix assets.build

# Build for production
mix assets.deploy

# Install missing asset tools
mix assets.setup
```

## User Roles & Permissions

The system comes with four predefined roles:

### Admin
Full system access including:
- User management
- Item management (all items)
- Bid management
- Catalog management
- Role and permission management

### Seller
Can manage their own listings:
- Create, update, delete own items
- Publish items
- View bids

### User
Basic bidding capabilities:
- Place bids
- View bids
- Browse catalog

### Viewer
Read-only access:
- Browse catalog

## API Usage

### REST API (JSON:API)

```bash
# Login
curl -X POST http://localhost:4000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# List items
curl http://localhost:4000/api/v1/items \
  -H "Authorization: Bearer YOUR_TOKEN"

# Place a bid
curl -X POST http://localhost:4000/api/v1/bids/make \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{"data":{"type":"bid","attributes":{"amount":"150.00","item_id":"UUID"}}}'
```

### GraphQL API

```graphql
# Query bids
query {
  bids {
    id
    amount
    bidTime
    item {
      title
      currentPrice
    }
  }
}

# Place a bid
mutation {
  makeBid(input: {amount: "150.00", itemId: "UUID"}) {
    result {
      id
      amount
      bidTime
    }
    errors {
      message
    }
  }
}
```

See [API Documentation](docs/API.md) for complete API reference.

## Environment Variables

For production deployment, configure these environment variables:

```bash
SECRET_KEY_BASE=your_secret_key_base
DATABASE_URL=postgresql://user:pass@host/database
PHX_HOST=your-domain.com
JWT_SECRET=your_jwt_secret
PORT=4000

# Email (SMTP)
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_smtp_password
FROM_EMAIL=noreply@your-domain.com
```

See [Deployment Guide](docs/DEPLOYMENT.md) for detailed deployment instructions.

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[Architecture](docs/ARCHITECTURE.md)** - System design, domain architecture, and data flow
- **[API Reference](docs/API.md)** - Complete API documentation (REST, GraphQL)
- **[Frontend Guide](docs/FRONTEND.md)** - React/TypeScript development guide
- **[Deployment](docs/DEPLOYMENT.md)** - Production deployment instructions

## Development Resources

### Ash Framework
- [Ash Documentation](https://hexdocs.pm/ash)
- [Ash Postgres](https://hexdocs.pm/ash_postgres)
- [Ash Authentication](https://hexdocs.pm/ash_authentication)
- [Ash GraphQL](https://hexdocs.pm/ash_graphql)
- [Ash JSON API](https://hexdocs.pm/ash_json_api)

### Phoenix Framework
- [Phoenix Documentation](https://hexdocs.pm/phoenix)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view)
- [Plug](https://hexdocs.pm/plug)

### Frontend
- [React Documentation](https://react.dev/)
- [Inertia.js](https://inertiajs.com/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Shadcn UI](https://ui.shadcn.com/)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style

- Follow Elixir style guide
- Use `mix format` before committing
- Write tests for new features
- Update documentation as needed

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/angle/bidding/bid_test.exs

# Run tests matching a pattern
mix test --only auction

# Run failed tests
mix test --failed
```

## Troubleshooting

### Database Issues

```bash
# Drop and recreate database
mix ecto.reset

# Check database connection
mix run -e "Angle.Repo.query!(\"SELECT 1\")"
```

### Asset Build Issues

```bash
# Clear compiled assets
rm -rf priv/static/assets/*

# Rebuild assets
mix assets.setup
mix assets.build
```

### Dependency Issues

```bash
# Clean dependencies
mix deps.clean --all

# Reinstall
mix deps.get
```

## Performance Tips

- Use connection pooling (configured by default)
- Enable database indexes (defined in resources)
- Implement caching for frequently accessed data
- Use Oban for background processing
- Monitor with Phoenix LiveDashboard

## Security

- All passwords are hashed with bcrypt
- JWT tokens for API authentication
- CSRF protection enabled
- SQL injection prevention via Ecto
- XSS prevention via React
- HTTPS recommended for production
- Regular dependency updates

## License

[Your License Here]

## Support

For questions and support:
- Create an [issue](https://github.com/yourrepo/angle/issues)
- Check the [documentation](docs/)
- Review [CLAUDE.md](CLAUDE.md) for AI-assisted development guidelines

## Acknowledgments

Built with:
- [Elixir](https://elixir-lang.org/)
- [Phoenix Framework](https://www.phoenixframework.org/)
- [Ash Framework](https://ash-hq.org/)
- [React](https://react.dev/)
- [Inertia.js](https://inertiajs.com/)

---

**Happy Auctioning!** 🎯
