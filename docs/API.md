# Angle - API Documentation

## Overview

Angle provides four API interfaces:
1. **TypeScript RPC** - Type-safe client generated from Ash resources (Recommended)
2. **JSON:API** - RESTful API following JSON:API specification
3. **GraphQL** - Flexible query language via Absinthe
4. **Phoenix Controllers** - Traditional server-rendered endpoints

Most endpoints require authentication via session cookies or JWT tokens.

## TypeScript RPC API (Recommended)

### Overview

The TypeScript RPC API provides type-safe access to all Ash actions with full IDE autocomplete and compile-time type checking.

### Setup

Generate the TypeScript client from your Ash resources:

```bash
mix ash_typescript.generate
```

This creates `assets/js/ash_rpc.ts` with all types and functions.

### Endpoints

```
POST /rpc/run        - Execute Ash actions (requires auth)
POST /rpc/validate   - Validate action inputs (public)
```

### Authentication

RPC calls automatically use session authentication:

```typescript
import { Bidding } from '@/ash_rpc';

// Session cookies are sent automatically
const bid = await Bidding.Bid.makeBid({
  amount: '150.00',
  itemId: 'item-uuid'
});
```

### Basic Usage

```typescript
import { Bidding, Inventory, Accounts } from '@/ash_rpc';

// Place a bid
const bid = await Bidding.Bid.makeBid({
  amount: '150.00',
  itemId: 'item-id'
});

// List items
const items = await Inventory.Item.read();

// Get user info
const user = await Accounts.User.read({ id: 'user-id' });
```

### Error Handling

```typescript
try {
  await Bidding.Bid.makeBid({ amount: '50', itemId: 'xyz' });
} catch (error) {
  if (error.status === 401) {
    // Not authenticated
    window.location.href = '/auth/login';
  } else if (error.status === 403) {
    // No permission
    console.error('Forbidden:', error.message);
  } else if (error.status === 422) {
    // Validation errors
    error.errors.forEach(err => {
      console.error(`${err.field}: ${err.message}`);
    });
  }
}
```

### Validation

```typescript
import { validateMakeBid } from '@/ash_rpc';

const result = await validateMakeBid({
  amount: '150.00',
  itemId: 'item-id'
});

if (result.valid) {
  // Proceed with submission
} else {
  // Show errors
  result.errors.forEach(err => {
    console.error(err.message);
  });
}
```

### Benefits

- ✅ Full TypeScript type safety
- ✅ IDE autocomplete for all actions and fields
- ✅ Compile-time error checking
- ✅ Automatic session authentication
- ✅ Client-side validation
- ✅ No manual API client code

## Authentication

### Obtaining a Token

**Register a new user:**
```http
POST /auth/register
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password_123",
  "password_confirmation": "secure_password_123"
}

Response 200:
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "confirmed_at": null
  }
}
```

**Login:**
```http
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password_123"
}

Response 200:
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "confirmed_at": "2024-01-15T10:30:00Z"
  }
}
```

### Using the Token

Include the JWT token in the `Authorization` header:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

### Password Reset

**Request reset token:**
```http
POST /auth/forgot-password
Content-Type: application/json

{
  "email": "user@example.com"
}

Response 200:
{
  "message": "If an account exists, a reset link has been sent"
}
```

**Reset password:**
```http
POST /auth/reset-password
Content-Type: application/json

{
  "reset_token": "token_from_email",
  "password": "new_password_123",
  "password_confirmation": "new_password_123"
}

Response 200:
{
  "token": "new_jwt_token...",
  "message": "Password reset successful"
}
```

## JSON:API Endpoints

Base URL: `/api/v1`

All JSON:API endpoints follow the [JSON:API specification](https://jsonapi.org/).

### Items

#### List Items

```http
GET /api/v1/items
Authorization: Bearer {token}

Query Parameters:
  - page[limit]: Number of items per page (default: 25)
  - page[offset]: Offset for pagination
  - filter[publication_status]: Filter by status (draft, published)
  - filter[auction_status]: Filter by auction status
  - filter[category_id]: Filter by category
  - include: Include related resources (category, user)
  - sort: Sort by field (title, created_at, start_time)

Response 200:
{
  "data": [
    {
      "type": "item",
      "id": "uuid",
      "attributes": {
        "title": "Vintage Camera",
        "description": "Rare 1960s camera in excellent condition",
        "starting_price": "100.00",
        "current_price": "150.00",
        "reserve_price": "200.00",
        "bid_increment": "5.00",
        "publication_status": "published",
        "auction_status": "active",
        "start_time": "2024-01-20T10:00:00Z",
        "end_time": "2024-01-27T10:00:00Z",
        "condition": "used",
        "sale_type": "auction",
        "view_count": 45
      },
      "relationships": {
        "category": {
          "data": { "type": "category", "id": "uuid" }
        },
        "user": {
          "data": { "type": "user", "id": "uuid" }
        }
      }
    }
  ],
  "links": {
    "self": "/api/v1/items",
    "next": "/api/v1/items?page[offset]=25"
  },
  "meta": {
    "total": 150
  }
}
```

#### Create Item (Draft)

```http
POST /api/v1/items/draft
Authorization: Bearer {token}
Content-Type: application/json

{
  "data": {
    "type": "item",
    "attributes": {
      "title": "Vintage Camera",
      "description": "Rare 1960s camera",
      "starting_price": "100.00",
      "reserve_price": "200.00",
      "bid_increment": "5.00",
      "start_time": "2024-01-20T10:00:00Z",
      "end_time": "2024-01-27T10:00:00Z",
      "category_id": "uuid",
      "condition": "used",
      "sale_type": "auction",
      "auction_format": "standard"
    }
  }
}

Response 201:
{
  "data": {
    "type": "item",
    "id": "uuid",
    "attributes": {
      "title": "Vintage Camera",
      "publication_status": "draft",
      "auction_status": "pending",
      ...
    }
  }
}
```

#### Update Draft Item

```http
PATCH /api/v1/items/draft/{id}
Authorization: Bearer {token}
Content-Type: application/json

{
  "data": {
    "type": "item",
    "id": "uuid",
    "attributes": {
      "title": "Updated Title",
      "description": "Updated description"
    }
  }
}

Response 200:
{
  "data": {
    "type": "item",
    "id": "uuid",
    "attributes": { ... }
  }
}
```

#### Publish Item

```http
PATCH /api/v1/items/publish
Authorization: Bearer {token}
Content-Type: application/json

{
  "data": {
    "type": "item",
    "id": "uuid"
  }
}

Response 200:
{
  "data": {
    "type": "item",
    "id": "uuid",
    "attributes": {
      "publication_status": "published",
      ...
    }
  }
}
```

### Bids

#### List Bids

```http
GET /api/v1/bids
Authorization: Bearer {token}

Query Parameters:
  - filter[item_id]: Filter by item
  - filter[user_id]: Filter by user
  - include: Include related resources (item, user)
  - sort: Sort by field (bid_time, amount)

Response 200:
{
  "data": [
    {
      "type": "bid",
      "id": "uuid",
      "attributes": {
        "amount": "155.00",
        "bid_type": "standard",
        "bid_time": "2024-01-22T14:30:00Z"
      },
      "relationships": {
        "item": {
          "data": { "type": "item", "id": "uuid" }
        },
        "user": {
          "data": { "type": "user", "id": "uuid" }
        }
      }
    }
  ]
}
```

#### Place Bid

```http
POST /api/v1/bids/make
Authorization: Bearer {token}
Content-Type: application/json

{
  "data": {
    "type": "bid",
    "attributes": {
      "amount": "160.00",
      "bid_type": "standard",
      "item_id": "uuid"
    }
  }
}

Response 201:
{
  "data": {
    "type": "bid",
    "id": "uuid",
    "attributes": {
      "amount": "160.00",
      "bid_type": "standard",
      "bid_time": "2024-01-22T15:00:00Z"
    }
  }
}

Error 422 (Invalid bid):
{
  "errors": [
    {
      "title": "Invalid bid amount",
      "detail": "Bid must be higher than current price plus increment",
      "source": { "pointer": "/data/attributes/amount" }
    }
  ]
}

Error 403 (Forbidden):
{
  "errors": [
    {
      "title": "Forbidden",
      "detail": "You don't have permission to place bids"
    }
  ]
}
```

### Categories

#### List Categories

```http
GET /api/v1/categories
Authorization: Bearer {token}

Response 200:
{
  "data": [
    {
      "type": "category",
      "id": "uuid",
      "attributes": {
        "name": "Electronics",
        "description": "Electronic devices and gadgets"
      }
    }
  ]
}
```

## GraphQL API

Base URL: `/gql`

GraphQL Playground: `/gql/playground` (development only)

### Schema

#### Types

```graphql
type Bid {
  id: ID!
  amount: Decimal!
  bidType: String!
  bidTime: DateTime!
  item: Item!
  user: User!
}

type Item {
  id: ID!
  title: String!
  description: String
  startingPrice: Decimal!
  currentPrice: Decimal
  reservePrice: Decimal
  bidIncrement: Decimal
  publicationStatus: String!
  auctionStatus: String!
  startTime: DateTime
  endTime: DateTime
  condition: String!
  saleType: String!
  category: Category
}

type Category {
  id: ID!
  name: String!
  description: String
}

type User {
  id: ID!
  email: String!
  confirmedAt: DateTime
}
```

#### Queries

**Get single bid:**
```graphql
query GetBid($id: ID!) {
  bid(id: $id) {
    id
    amount
    bidType
    bidTime
    item {
      id
      title
      currentPrice
    }
    user {
      id
      email
    }
  }
}
```

**List bids:**
```graphql
query ListBids {
  bids {
    id
    amount
    bidTime
    item {
      title
    }
  }
}
```

#### Mutations

**Place a bid:**
```graphql
mutation MakeBid($input: MakeBidInput!) {
  makeBid(input: $input) {
    result {
      id
      amount
      bidTime
    }
    errors {
      message
      field
    }
  }
}

# Variables:
{
  "input": {
    "amount": "160.00",
    "bidType": "standard",
    "itemId": "uuid"
  }
}
```

### GraphQL Request Examples

**Using cURL:**
```bash
curl -X POST http://localhost:4000/gql \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {token}" \
  -d '{
    "query": "query { bids { id amount bidTime } }"
  }'
```

**Using JavaScript:**
```javascript
const response = await fetch('http://localhost:4000/gql', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    query: `
      query GetBid($id: ID!) {
        bid(id: $id) {
          id
          amount
          bidTime
        }
      }
    `,
    variables: { id: 'uuid' }
  })
});

const { data, errors } = await response.json();
```

## Permission Requirements

Different API operations require specific permissions:

### Item Operations

| Action | Permission Required |
|--------|-------------------|
| List published items | None (public) |
| List own draft items | Authenticated user |
| Create item | `create_items` |
| Update own item | `update_own_items` |
| Delete own item | `delete_own_items` |
| Publish item | `publish_items` |
| Manage any item | `manage_all_items` |

### Bid Operations

| Action | Permission Required |
|--------|-------------------|
| View bids | `view_bids` |
| Place bid | `place_bids` |
| Manage bids | `manage_bids` |

### User Operations

| Action | Permission Required |
|--------|-------------------|
| View user profile | Self or `read_users` |
| Update user | Self |
| Manage users | `manage_users` |

## Error Responses

### JSON:API Errors

```json
{
  "errors": [
    {
      "title": "Validation Error",
      "detail": "Title can't be blank",
      "source": {
        "pointer": "/data/attributes/title"
      },
      "status": "422"
    }
  ]
}
```

### Common HTTP Status Codes

- `200 OK` - Successful GET/PATCH request
- `201 Created` - Successful POST request
- `204 No Content` - Successful DELETE request
- `400 Bad Request` - Invalid request format
- `401 Unauthorized` - Missing or invalid token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Resource not found
- `422 Unprocessable Entity` - Validation errors
- `500 Internal Server Error` - Server error

## Rate Limiting

Currently, there is no rate limiting implemented. This should be added for production use.

**Recommended limits:**
- 100 requests per minute per IP for authenticated endpoints
- 10 requests per minute per IP for authentication endpoints
- 1000 requests per hour per authenticated user

## Webhooks

Webhooks are not currently implemented but could be added for:
- Bid placed notifications
- Auction ended notifications
- Item published notifications
- User registered notifications

## API Versioning

The current API is version 1 (`/api/v1`). Future versions will be released as `/api/v2`, etc.

Breaking changes will always require a new version. Non-breaking changes may be added to existing versions.

## OpenAPI Documentation

Interactive API documentation is available at:

**Development:**
- Swagger UI: `http://localhost:4000/api/v1/public/docs`
- OpenAPI Spec: `http://localhost:4000/api/v1/open_api`

The OpenAPI specification is auto-generated from the Ash resources using AshJsonApi.

## Testing the API

### Using cURL

**Get items:**
```bash
curl -X GET http://localhost:4000/api/v1/items \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/vnd.api+json"
```

**Create draft item:**
```bash
curl -X POST http://localhost:4000/api/v1/items/draft \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/vnd.api+json" \
  -d '{
    "data": {
      "type": "item",
      "attributes": {
        "title": "Test Item",
        "starting_price": "10.00"
      }
    }
  }'
```

### Using HTTPie

```bash
# Login
http POST :4000/auth/login email=user@example.com password=password123

# Get items
http GET :4000/api/v1/items "Authorization: Bearer {token}"

# Place bid
http POST :4000/api/v1/bids/make "Authorization: Bearer {token}" \
  data:='{"type":"bid","attributes":{"amount":"50.00","item_id":"uuid"}}'
```

### Using Postman

Import the OpenAPI spec from `http://localhost:4000/api/v1/open_api` into Postman for a complete API collection.

## Code Examples

### JavaScript/TypeScript

```typescript
// API client class
class AngleAPI {
  private baseURL = 'http://localhost:4000/api/v1';
  private token: string | null = null;

  async login(email: string, password: string) {
    const response = await fetch(`${this.baseURL}/../auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });
    const data = await response.json();
    this.token = data.token;
    return data;
  }

  async getItems(params = {}) {
    const query = new URLSearchParams(params).toString();
    const response = await fetch(`${this.baseURL}/items?${query}`, {
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/vnd.api+json'
      }
    });
    return response.json();
  }

  async placeBid(itemId: string, amount: string) {
    const response = await fetch(`${this.baseURL}/bids/make`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/vnd.api+json'
      },
      body: JSON.stringify({
        data: {
          type: 'bid',
          attributes: { amount, item_id: itemId }
        }
      })
    });
    return response.json();
  }
}

// Usage
const api = new AngleAPI();
await api.login('user@example.com', 'password');
const items = await api.getItems({ 'filter[publication_status]': 'published' });
const bid = await api.placeBid('item-uuid', '150.00');
```

### Python

```python
import requests

class AngleAPI:
    def __init__(self, base_url='http://localhost:4000'):
        self.base_url = base_url
        self.token = None

    def login(self, email, password):
        response = requests.post(
            f'{self.base_url}/auth/login',
            json={'email': email, 'password': password}
        )
        data = response.json()
        self.token = data['token']
        return data

    def get_items(self, **params):
        response = requests.get(
            f'{self.base_url}/api/v1/items',
            headers={
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/vnd.api+json'
            },
            params=params
        )
        return response.json()

    def place_bid(self, item_id, amount):
        response = requests.post(
            f'{self.base_url}/api/v1/bids/make',
            headers={
                'Authorization': f'Bearer {self.token}',
                'Content-Type': 'application/vnd.api+json'
            },
            json={
                'data': {
                    'type': 'bid',
                    'attributes': {'amount': amount, 'item_id': item_id}
                }
            }
        )
        return response.json()

# Usage
api = AngleAPI()
api.login('user@example.com', 'password')
items = api.get_items(**{'filter[publication_status]': 'published'})
bid = api.place_bid('item-uuid', '150.00')
```

## Additional Resources

- [Architecture Documentation](ARCHITECTURE.md)
- [Frontend Guide](FRONTEND.md)
- [JSON:API Specification](https://jsonapi.org/)
- [GraphQL Documentation](https://graphql.org/)
- [Ash Framework](https://hexdocs.pm/ash)
- [AshJsonApi](https://hexdocs.pm/ash_json_api)
- [AshGraphql](https://hexdocs.pm/ash_graphql)
