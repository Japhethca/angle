# Angle - Frontend Development Guide

## Overview

The Angle frontend is a modern React single-page application (SPA) built with TypeScript, Inertia.js, and Tailwind CSS. It provides a seamless user experience with server-side rendering (SSR) support and real-time updates via Phoenix Channels.

## Technology Stack

- **React 18+** - UI library
- **TypeScript** - Type safety
- **Inertia.js 2.5.1** - SPA framework with server-side routing
- **AshTypescript RPC** - Type-safe API client generated from Ash resources
- **Tailwind CSS 4.1.7** - Utility-first CSS
- **Shadcn UI** - Component library
- **esbuild 0.21.5** - Fast bundler
- **Phoenix Channels** - WebSocket communication

## Project Structure

```
assets/
├── css/
│   └── app.css                 # Tailwind CSS entry point
├── js/
│   ├── app.tsx                 # Client-side entry point
│   ├── ssr.tsx                 # Server-side rendering entry
│   ├── components/
│   │   ├── ui/                 # Shadcn UI components
│   │   │   ├── button.tsx
│   │   │   ├── card.tsx
│   │   │   ├── form.tsx
│   │   │   └── ...
│   │   ├── auth/               # Authentication components
│   │   │   ├── protected-route.tsx
│   │   │   ├── permission-guard.tsx
│   │   │   ├── guest-route.tsx
│   │   │   └── logout-button.tsx
│   │   ├── forms/              # Form components
│   │   │   ├── login-form.tsx
│   │   │   ├── register-form.tsx
│   │   │   ├── item-form.tsx
│   │   │   └── bid-form.tsx
│   │   ├── bidding/            # Bidding-specific components
│   │   │   └── bid-form.tsx
│   │   ├── layouts/            # Layout components
│   │   │   └── layout.tsx
│   │   └── navigation/         # Navigation components
│   │       └── main-nav.tsx
│   ├── pages/                  # Inertia.js page components
│   │   ├── home.tsx
│   │   ├── dashboard.tsx
│   │   ├── auth/
│   │   │   ├── login.tsx
│   │   │   ├── register.tsx
│   │   │   ├── forgot-password.tsx
│   │   │   ├── reset-password.tsx
│   │   │   └── confirm-new-user.tsx
│   │   └── admin/
│   │       └── users.tsx
│   ├── hooks/                  # Custom React hooks
│   │   ├── use-mobile.ts
│   │   ├── use-permissions.ts
│   │   ├── use-phoenix-channel.tsx
│   │   └── use-bidding-channel.tsx
│   ├── contexts/               # React contexts
│   │   └── auth-context.tsx
│   ├── types/                  # TypeScript type definitions
│   │   └── auth.ts
│   └── lib/                    # Utility functions
│       └── utils.ts
└── static/                     # Static assets (images, fonts)
```

## Getting Started

### Prerequisites

- Node.js 16+ (for local development)
- Understanding of React and TypeScript
- Basic knowledge of Tailwind CSS

### Development Setup

The frontend is automatically built when you run:

```bash
mix setup          # First time setup
mix assets.build   # Build assets
mix phx.server     # Start with auto-rebuild
```

### Build Commands

```bash
# Development build
mix assets.build

# Production build with minification
mix assets.deploy

# Manual builds (from assets/ directory)
cd assets
npm install        # Install dependencies
npx esbuild js/app.tsx --bundle --outdir=../priv/static/assets
npx tailwind -i css/app.css -o ../priv/static/assets/css/app.css
```

## Inertia.js Integration

### How Inertia Works

Inertia.js bridges the gap between server-side routing (Phoenix) and client-side rendering (React):

1. User navigates to a route (e.g., `/dashboard`)
2. Phoenix router handles the request
3. Controller renders via Inertia with props
4. Inertia sends JSON response to client
5. React renders the page component
6. Subsequent navigation happens via AJAX

**Benefits:**
- No need to build a separate REST/GraphQL API for UI
- Server-side routing and authorization
- Client-side SPA navigation
- Automatic CSRF protection

### Creating Pages

Pages are React components in `assets/js/pages/`:

```tsx
// assets/js/pages/dashboard.tsx
import React from 'react';
import { Head } from '@inertiajs/react';
import Layout from '@/components/layouts/layout';

interface DashboardProps {
  user: {
    email: string;
    roles: string[];
  };
  stats: {
    totalBids: number;
    activeItems: number;
  };
}

export default function Dashboard({ user, stats }: DashboardProps) {
  return (
    <Layout>
      <Head title="Dashboard" />

      <div className="container mx-auto py-8">
        <h1 className="text-3xl font-bold">Welcome, {user.email}</h1>

        <div className="grid grid-cols-2 gap-4 mt-6">
          <div className="p-4 bg-white rounded shadow">
            <h2 className="text-xl">Total Bids</h2>
            <p className="text-3xl font-bold">{stats.totalBids}</p>
          </div>
          <div className="p-4 bg-white rounded shadow">
            <h2 className="text-xl">Active Items</h2>
            <p className="text-3xl font-bold">{stats.activeItems}</p>
          </div>
        </div>
      </div>
    </Layout>
  );
}
```

### Phoenix Controller

```elixir
# lib/angle_web/controllers/dashboard_controller.ex
defmodule AngleWeb.DashboardController do
  use AngleWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Fetch data
    stats = %{
      total_bids: get_user_bid_count(user),
      active_items: get_user_active_items(user)
    }

    # Render via Inertia
    render_inertia(conn, "Dashboard", %{
      user: %{
        email: user.email,
        roles: user.active_roles
      },
      stats: stats
    })
  end
end
```

### Navigation

Use Inertia's `Link` component for navigation:

```tsx
import { Link } from '@inertiajs/react';

<Link href="/dashboard" className="text-blue-600">
  Dashboard
</Link>

// With HTTP method
<Link href="/auth/logout" method="post" as="button">
  Logout
</Link>
```

### Form Submission

```tsx
import { useForm } from '@inertiajs/react';

function LoginForm() {
  const { data, setData, post, processing, errors } = useForm({
    email: '',
    password: ''
  });

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    post('/auth/login');
  };

  return (
    <form onSubmit={submit}>
      <input
        type="email"
        value={data.email}
        onChange={e => setData('email', e.target.value)}
      />
      {errors.email && <span>{errors.email}</span>}

      <input
        type="password"
        value={data.password}
        onChange={e => setData('password', e.target.value)}
      />
      {errors.password && <span>{errors.password}</span>}

      <button type="submit" disabled={processing}>
        Login
      </button>
    </form>
  );
}
```

## Authentication

### Auth Context

Global authentication state is managed via React Context:

```tsx
// assets/js/contexts/auth-context.tsx
import { createContext, useContext } from 'react';

interface AuthUser {
  id: string;
  email: string;
  roles: string[];
  permissions: string[];
}

interface AuthContextType {
  user: AuthUser | null;
  authenticated: boolean;
}

const AuthContext = createContext<AuthContextType>({
  user: null,
  authenticated: false
});

export const useAuth = () => useContext(AuthContext);
```

### Protected Routes

Wrap components that require authentication:

```tsx
// assets/js/components/auth/protected-route.tsx
import { useAuth } from '@/contexts/auth-context';
import { Navigate } from '@inertiajs/react';

export default function ProtectedRoute({ children }) {
  const { authenticated } = useAuth();

  if (!authenticated) {
    return <Navigate href="/auth/login" />;
  }

  return children;
}
```

### Permission Guard

Check permissions before rendering:

```tsx
// assets/js/components/auth/permission-guard.tsx
import { usePermissions } from '@/hooks/use-permissions';

interface PermissionGuardProps {
  permission: string;
  children: React.ReactNode;
  fallback?: React.ReactNode;
}

export default function PermissionGuard({
  permission,
  children,
  fallback = null
}: PermissionGuardProps) {
  const { hasPermission } = usePermissions();

  if (!hasPermission(permission)) {
    return <>{fallback}</>;
  }

  return <>{children}</>;
}

// Usage
<PermissionGuard permission="create_items">
  <button>Create Item</button>
</PermissionGuard>
```

### usePermissions Hook

```tsx
// assets/js/hooks/use-permissions.ts
import { useAuth } from '@/contexts/auth-context';

export function usePermissions() {
  const { user } = useAuth();

  const hasPermission = (permission: string): boolean => {
    return user?.permissions?.includes(permission) ?? false;
  };

  const hasRole = (role: string): boolean => {
    return user?.roles?.includes(role) ?? false;
  };

  const hasAnyPermission = (permissions: string[]): boolean => {
    return permissions.some(p => hasPermission(p));
  };

  return { hasPermission, hasRole, hasAnyPermission };
}
```

## Real-time Features

### Phoenix Channels Hook

```tsx
// assets/js/hooks/use-phoenix-channel.tsx
import { useEffect, useState } from 'react';
import { Socket, Channel } from 'phoenix';

export function usePhoenixChannel(topic: string) {
  const [channel, setChannel] = useState<Channel | null>(null);
  const [state, setState] = useState({});

  useEffect(() => {
    const socket = new Socket('/socket', {
      params: { token: window.userToken }
    });

    socket.connect();

    const ch = socket.channel(topic, {});

    ch.join()
      .receive('ok', resp => console.log('Joined', resp))
      .receive('error', resp => console.log('Failed', resp));

    setChannel(ch);

    return () => {
      ch.leave();
      socket.disconnect();
    };
  }, [topic]);

  const subscribe = (event: string, callback: (payload: any) => void) => {
    if (channel) {
      channel.on(event, callback);
    }
  };

  const push = (event: string, payload: any) => {
    if (channel) {
      channel.push(event, payload);
    }
  };

  return { state, subscribe, push };
}
```

### Bidding Channel

```tsx
// assets/js/hooks/use-bidding-channel.tsx
import { useEffect, useState } from 'react';
import { usePhoenixChannel } from './use-phoenix-channel';

interface Bid {
  id: string;
  amount: string;
  bidTime: string;
  user: { email: string };
}

export function useBiddingChannel(itemId: string) {
  const [bids, setBids] = useState<Bid[]>([]);
  const { subscribe } = usePhoenixChannel(`bidding:item_${itemId}`);

  useEffect(() => {
    subscribe('new_bid', (payload) => {
      setBids(prev => [...prev, payload.bid]);
    });
  }, [subscribe]);

  return { bids };
}

// Usage in component
function ItemBids({ itemId }: { itemId: string }) {
  const { bids } = useBiddingChannel(itemId);

  return (
    <div>
      <h2>Recent Bids</h2>
      {bids.map(bid => (
        <div key={bid.id}>
          {bid.amount} by {bid.user.email}
        </div>
      ))}
    </div>
  );
}
```

## Styling with Tailwind CSS

### Configuration

Tailwind is configured in `tailwind.config.js`:

```javascript
module.exports = {
  content: [
    './js/**/*.{js,jsx,ts,tsx}',
    '../lib/angle_web/**/*.{ex,heex}'
  ],
  theme: {
    extend: {
      colors: {
        primary: {...},
        secondary: {...}
      }
    }
  },
  plugins: [require('tailwindcss-animate')]
}
```

### Using Tailwind

```tsx
// Utility classes
<div className="flex items-center justify-between p-4 bg-white rounded-lg shadow">
  <h2 className="text-xl font-bold text-gray-800">Title</h2>
  <button className="px-4 py-2 text-white bg-blue-600 rounded hover:bg-blue-700">
    Click Me
  </button>
</div>

// Responsive design
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
  {/* Cards */}
</div>

// Dark mode (if enabled)
<div className="bg-white dark:bg-gray-800">
  <p className="text-gray-900 dark:text-gray-100">Text</p>
</div>
```

## Shadcn UI Components

### Available Components

The project includes these Shadcn UI components:

- `Button` - Buttons with variants
- `Card` - Content cards
- `Form` - Form wrapper with validation
- `Input` - Text inputs
- `Select` - Dropdown selects
- `Dialog` - Modal dialogs
- `Alert` - Alert messages
- `Table` - Data tables
- `Tabs` - Tab navigation
- And many more in `components/ui/`

### Using Shadcn Components

```tsx
import { Button } from '@/components/ui/button';
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';

function MyComponent() {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Form Title</CardTitle>
      </CardHeader>
      <CardContent>
        <Input type="text" placeholder="Enter text" />
        <Button variant="default">Submit</Button>
      </CardContent>
    </Card>
  );
}
```

### Form Components

```tsx
import { useForm } from 'react-hook-form';
import { Form, FormField, FormItem, FormLabel, FormControl, FormMessage } from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';

function LoginForm() {
  const form = useForm({
    defaultValues: {
      email: '',
      password: ''
    }
  });

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <FormField
          control={form.control}
          name="email"
          render={({ field }) => (
            <FormItem>
              <FormLabel>Email</FormLabel>
              <FormControl>
                <Input type="email" {...field} />
              </FormControl>
              <FormMessage />
            </FormItem>
          )}
        />

        <Button type="submit">Login</Button>
      </form>
    </Form>
  );
}
```

## TypeScript Types

### Defining Types

```tsx
// assets/js/types/auth.ts
export interface User {
  id: string;
  email: string;
  confirmedAt: string | null;
  roles: string[];
  permissions: string[];
}

export interface AuthState {
  user: User | null;
  authenticated: boolean;
}

// assets/js/types/item.ts
export interface Item {
  id: string;
  title: string;
  description: string;
  startingPrice: string;
  currentPrice: string;
  publicationStatus: 'draft' | 'published';
  auctionStatus: 'pending' | 'active' | 'ended';
}

// assets/js/types/bid.ts
export interface Bid {
  id: string;
  amount: string;
  bidType: string;
  bidTime: string;
  itemId: string;
  userId: string;
}
```

### Using Types

```tsx
import { Item } from '@/types/item';

interface ItemCardProps {
  item: Item;
  onBid?: (itemId: string) => void;
}

export default function ItemCard({ item, onBid }: ItemCardProps) {
  return (
    <div>
      <h2>{item.title}</h2>
      <p>Current Price: ${item.currentPrice}</p>
      {onBid && (
        <button onClick={() => onBid(item.id)}>
          Place Bid
        </button>
      )}
    </div>
  );
}
```

## Type-Safe API Calls with AshTypescript

### Overview

Instead of manually calling REST or GraphQL APIs, use the auto-generated TypeScript RPC client for type-safe API interactions.

### Generating the Client

Generate TypeScript types from your Ash resources:

```bash
mix ash_typescript.generate
```

This creates `assets/js/ash_rpc.ts` with:
- TypeScript interfaces for all resources
- Type-safe RPC functions
- Validation helpers

### Basic Usage

```tsx
import { Bidding, Inventory } from '@/ash_rpc';

// Type-safe bid placement
const placeBid = async (itemId: string, amount: string) => {
  try {
    const result = await Bidding.Bid.makeBid({
      amount: amount,
      itemId: itemId
    });

    // result is fully typed!
    console.log('Bid placed:', result.id, result.bidTime);
  } catch (error) {
    // Error is typed too
    if (error.status === 422) {
      console.error('Validation errors:', error.errors);
    }
  }
};

// List items with type safety
const fetchItems = async () => {
  const items = await Inventory.Item.read();
  // items is Item[]
  return items;
};
```

### Authentication

RPC calls automatically use your session authentication (no special setup needed):

```tsx
// Session cookies are automatically sent
await Bidding.Bid.makeBid({ amount: '100', itemId: 'xyz' });
```

If the user is not authenticated:
- Returns 401 status
- Error can be caught and handled

### Error Handling

```tsx
try {
  await Bidding.Bid.makeBid({ amount: '50', itemId: 'abc' });
} catch (error) {
  switch (error.status) {
    case 401:
      // Redirect to login
      window.location.href = '/auth/login';
      break;
    case 403:
      // No permission
      alert('You do not have permission to place bids');
      break;
    case 422:
      // Validation errors
      error.errors.forEach(err => {
        console.error(`${err.field}: ${err.message}`);
      });
      break;
    default:
      alert('An error occurred');
  }
}
```

### Form Integration

```tsx
import { Bidding } from '@/ash_rpc';
import { useForm } from 'react-hook-form';

interface BidFormData {
  amount: string;
}

function BidForm({ itemId }: { itemId: string }) {
  const { register, handleSubmit, setError } = useForm<BidFormData>();

  const onSubmit = async (data: BidFormData) => {
    try {
      await Bidding.Bid.makeBid({
        amount: data.amount,
        itemId: itemId
      });

      alert('Bid placed successfully!');
    } catch (error) {
      if (error.status === 422) {
        // Set form errors
        error.errors.forEach(err => {
          setError(err.field as keyof BidFormData, {
            message: err.message
          });
        });
      }
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input
        type="number"
        {...register('amount', { required: true })}
        placeholder="Bid amount"
      />
      <button type="submit">Place Bid</button>
    </form>
  );
}
```

### Client-side Validation

The generated client includes validation functions:

```tsx
import { validateMakeBid } from '@/ash_rpc';

const validateBid = async (amount: string, itemId: string) => {
  const validation = await validateMakeBid({
    amount,
    itemId
  });

  if (validation.valid) {
    // Proceed with submission
  } else {
    // Show validation errors
    validation.errors.forEach(err => {
      console.error(err.message);
    });
  }
};
```

### TypeScript Autocomplete

The generated types provide full IDE support:

```tsx
import { Bidding } from '@/ash_rpc';

// Your IDE will autocomplete:
// - Bidding.Bid.makeBid
// - Bidding.Bid.read
// - All available actions

// And autocomplete parameters:
await Bidding.Bid.makeBid({
  amount: '', // <- IDE suggests 'amount'
  itemId: '', // <- IDE suggests 'itemId'
  // <- IDE shows all available fields
});
```

### Comparison: Before and After

**Before (manual API calls):**
```tsx
const placeBid = async (itemId: string, amount: string) => {
  const response = await fetch('/api/v1/bids/make', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/vnd.api+json'
    },
    body: JSON.stringify({
      data: {
        type: 'bid',
        attributes: { amount, item_id: itemId }
      }
    })
  });

  if (!response.ok) {
    throw new Error('Failed to place bid');
  }

  const data = await response.json();
  return data.data;
};
```

**After (type-safe RPC):**
```tsx
import { Bidding } from '@/ash_rpc';

const placeBid = async (itemId: string, amount: string) => {
  return await Bidding.Bid.makeBid({ amount, itemId });
};
```

## Common Patterns

### Loading States

```tsx
function ItemList() {
  const [loading, setLoading] = useState(true);
  const [items, setItems] = useState<Item[]>([]);

  useEffect(() => {
    fetchItems().then(data => {
      setItems(data);
      setLoading(false);
    });
  }, []);

  if (loading) {
    return <div>Loading...</div>;
  }

  return (
    <div>
      {items.map(item => (
        <ItemCard key={item.id} item={item} />
      ))}
    </div>
  );
}
```

### Error Handling

```tsx
function ItemForm() {
  const { data, setData, post, errors } = useForm({
    title: '',
    price: ''
  });

  return (
    <form onSubmit={e => { e.preventDefault(); post('/items'); }}>
      <Input
        value={data.title}
        onChange={e => setData('title', e.target.value)}
      />
      {errors.title && <span className="text-red-500">{errors.title}</span>}

      <button type="submit">Submit</button>
    </form>
  );
}
```

### Conditional Rendering

```tsx
function DashboardNav() {
  const { hasPermission } = usePermissions();

  return (
    <nav>
      <Link href="/dashboard">Dashboard</Link>

      {hasPermission('create_items') && (
        <Link href="/items/new">Create Item</Link>
      )}

      {hasPermission('manage_users') && (
        <Link href="/admin/users">Manage Users</Link>
      )}
    </nav>
  );
}
```

## Testing

### Component Testing

(To be implemented)

```tsx
import { render, screen } from '@testing-library/react';
import ItemCard from '@/components/item-card';

test('renders item card', () => {
  const item = {
    id: '1',
    title: 'Test Item',
    currentPrice: '100.00'
  };

  render(<ItemCard item={item} />);

  expect(screen.getByText('Test Item')).toBeInTheDocument();
  expect(screen.getByText('$100.00')).toBeInTheDocument();
});
```

## Best Practices

### File Naming

- Use kebab-case for files: `item-form.tsx`, `use-permissions.ts`
- Use PascalCase for components: `ItemForm`, `UserCard`
- Use camelCase for functions: `fetchItems`, `handleSubmit`

### Component Organization

```tsx
// 1. Imports
import React, { useState, useEffect } from 'react';
import { useForm } from '@inertiajs/react';
import { Button } from '@/components/ui/button';

// 2. Types
interface Props {
  item: Item;
}

// 3. Component
export default function ItemForm({ item }: Props) {
  // 3a. Hooks
  const { data, setData, post } = useForm({ ... });
  const [loading, setLoading] = useState(false);

  // 3b. Effects
  useEffect(() => {
    // ...
  }, []);

  // 3c. Handlers
  const handleSubmit = () => {
    // ...
  };

  // 3d. Render
  return (
    <div>
      {/* JSX */}
    </div>
  );
}
```

### Performance

- Use `React.memo()` for expensive components
- Lazy load pages: `const Page = lazy(() => import('./pages/page'))`
- Debounce search inputs
- Virtualize long lists

### Accessibility

- Use semantic HTML: `<button>`, `<nav>`, `<main>`
- Add ARIA labels where needed
- Ensure keyboard navigation works
- Test with screen readers

## Debugging

### React DevTools

Install React DevTools browser extension for debugging.

### Console Logging

```tsx
console.log('Data:', data);
console.error('Error:', error);
```

### Inertia DevTools

Check the network tab for Inertia requests (look for `X-Inertia` header).

## Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [API Documentation](API.md)
- [React Documentation](https://react.dev/)
- [Inertia.js Documentation](https://inertiajs.com/)
- [Tailwind CSS Documentation](https://tailwindcss.com/)
- [Shadcn UI](https://ui.shadcn.com/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
