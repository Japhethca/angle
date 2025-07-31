# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Installation

- `mix setup` - Install dependencies, setup database, build assets, and run seeds
- `mix deps.get` - Install Elixir dependencies
- `npm install` - Install Node.js dependencies (run from assets/ directory)

### Development Server

- `mix phx.server` - Start Phoenix server on localhost:4000
- `iex -S mix phx.server` - Start server with interactive Elixir shell

### Database Operations

- `mix ash.setup` - Setup Ash resources and database
- `mix ecto.create` - Create database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.reset` - Drop and recreate database with seeds

### Testing

- `mix test` - Run test suite (automatically runs ash.setup --quiet first)

### Asset Management

- `mix assets.build` - Build assets (Tailwind CSS and esbuild)
- `mix assets.deploy` - Build and minify assets for production
- `mix assets.setup` - Install Tailwind and esbuild if missing

## Architecture Overview

This is an Elixir Phoenix application using the Ash Framework for domain modeling and APIs. The application appears to be an auction/bidding platform with inventory management.

### Core Technologies

- **Phoenix Framework** - Web framework with LiveView support
- **Ash Framework** - Declarative resource modeling with built-in APIs
- **React + Inertia.js** - Frontend SPA with server-side routing
- **PostgreSQL** - Database with Ash Postgres data layer
- **Oban** - Background job processing
- **esbuild + Tailwind** - Asset building and CSS framework

### Domain Architecture

The application is organized into four main Ash domains in `lib/angle/`:

1. **Accounts** (`Angle.Accounts`)
   - User management with authentication
   - Role-based access control (User, Role, UserRole)
   - Email confirmation and password reset flows

2. **Catalog** (`Angle.Catalog`)
   - Category management for organizing items

3. **Inventory** (`Angle.Inventory`)
   - Item management with auction/publication status
   - Item activity tracking
   - Supports auction-style listings

4. **Bidding** (`Angle.Bidding`)
   - Bid management system
   - Bid validation and business rules
   - Different bid types support

### API Endpoints

- **GraphQL API** - `/gql` with playground at `/gql/playground`
- **JSON:API** - `/api/v1` with OpenAPI docs at `/api/v1/docs`
- **Admin Interface** - `/admin` (development only)
- **Live Dashboard** - `/dev/dashboard` (development only)

### Frontend Structure

- React components in `assets/js/`
- Inertia.js for SPA-style navigation
- JSX support with esbuild compilation
- Tailwind CSS for styling
- Shadcn UI components in `assets/js/components/ui/`
- Custom form components in `assets/js/components/forms`
- feature components in `assets/js/<feature>/components` or `assets/js/components/<feature component>.tsx`
- **Naming Conventions**
  - All react component and pages file names should be in kebab casing

### Key Configuration

- Ash domains configured in `config/config.exs`
- Custom money type support with `AshMoney`
- Authentication handled by `AshAuthentication`
- Background jobs via Oban with PostgreSQL notifier