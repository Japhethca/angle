# Store Settings Page Design

## Goal

Add a "Store" section to the settings page where users can manage their seller/store profile — store name, contact info, WhatsApp link, location, address, and delivery preferences.

## Architecture

Introduce a new `StoreProfile` Ash resource backed by its own `store_profiles` table with a 1:1 relationship to User. This separates store/seller data from personal user data, making the store independently extensible (future: store photos, reviews, multi-user management).

## Data Model

### New Resource: `Angle.Accounts.StoreProfile`

Table: `store_profiles`

| Field | Type | Notes |
|-------|------|-------|
| `id` | UUID | primary key |
| `user_id` | UUID FK | belongs_to User, unique, not null |
| `store_name` | string | required, migrated from User |
| `contact_phone` | string | store-specific phone number |
| `whatsapp_link` | string | e.g. "wa.me/2348012345678" |
| `location` | string | Nigerian state from hardcoded list |
| `address` | string | physical address |
| `delivery_preference` | string | "you_arrange" / "seller_delivers" / "pickup_only" |
| `inserted_at` | utc_datetime_usec | |
| `updated_at` | utc_datetime_usec | |

### Changes to User Resource

- Remove `store_name` attribute (data migrated to StoreProfile)
- Add `has_one :store_profile, Angle.Accounts.StoreProfile`
- Keep `whatsapp_number` on User (personal WhatsApp)

### Migration

1. Create `store_profiles` table
2. Migrate existing `store_name` data from `users` to `store_profiles`
3. Remove `store_name` column from `users`

## Backend Actions & RPC

### StoreProfile Actions

- **`upsert`** (create action with `upsert? true, upsert_identity: :user_id`): Creates or updates the store profile. Accepts all fields. The frontend calls a single RPC function regardless of whether the profile exists yet.
- **`read`**: For loading in the controller.

### Typed Queries

- New `store_profile_data` query for loading the user's store profile in the settings controller.
- Update existing `seller_profile` query to read `store_name` from StoreProfile instead of User.

### RPC

`mix ash_typescript.codegen` generates `upsertStoreProfile` function in `ash_rpc.ts`.

## Frontend

### New Page: `pages/settings/store.tsx`

Same pattern as `account.tsx`: receives `user` and `store_profile` (nullable) as Inertia props, wraps in `<SettingsLayout>`.

### New Component: `features/settings/components/store-form.tsx`

- React Hook Form + Zod validation
- Store logo section (static placeholder with Change/Delete buttons)
- Store Name (text input, required)
- Contact phone (with Nigerian 234 prefix, same pattern as account form)
- WhatsApp Link (with "http://" prefix label + text input)
- Location (dropdown of 36 Nigerian states + FCT Abuja)
- Address (text input)
- Verification section (static placeholder: Personal ID + Business ID cards)
- Preferences section (Delivery dropdown)
- Save Changes button (orange)
- Uses `useAshMutation` with `upsertStoreProfile` RPC

### Updated Components

- `settings-layout.tsx`: Enable "Store" sidebar item, link to `/settings/store`
- `features/settings/index.ts`: Add barrel exports + `StoreProfile` type

### Route & Controller

- Add `get "/settings/store"` to router
- Add `store` action to `SettingsController` that loads user + store_profile

## Dropdown Values

### Nigerian States (36 + FCT)

Abia, Adamawa, Akwa Ibom, Anambra, Bauchi, Bayelsa, Benue, Borno, Cross River, Delta, Ebonyi, Edo, Ekiti, Enugu, FCT Abuja, Gombe, Imo, Jigawa, Kaduna, Kano, Katsina, Kebbi, Kogi, Kwara, Lagos, Nasarawa, Niger, Ogun, Ondo, Osun, Oyo, Plateau, Rivers, Sokoto, Taraba, Yobe, Zamfara

### Delivery Preferences

- "You arrange delivery" (default)
- "Seller delivers"
- "Pickup only"

## Responsive Layout

Follows existing settings page pattern:
- **Desktop**: Sidebar (Store highlighted orange) + form content with breadcrumb "Store > Store Profile"
- **Mobile**: Back arrow "< Store" header + full-width form, no sidebar

No new responsive infrastructure needed — `SettingsLayout` handles this.

## Verification & Store Logo

Both are **static placeholders** in this iteration:
- Store logo: shows icon + Change/Delete buttons, no actual upload
- Verification: shows two cards (Personal ID, Business ID) with hardcoded data, no upload

## Testing

- **Resource tests**: StoreProfile upsert action (create + update), validation (store_name required)
- **Controller tests**: `/settings/store` renders for authenticated user, redirects when unauthenticated
- **Factory**: Add `create_store_profile/1` helper

## Figma References

- Desktop: node `678-6906`
- Mobile: node `678-7347`
- File: `jk9qoWNcSpgUa8lsj7uXa9`
