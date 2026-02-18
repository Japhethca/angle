# List Item Form Design

## Overview

A 4-step wizard form that lets sellers create auction listings. The flow uses a draft-then-publish pattern: create a draft after Step 1 (to enable image upload), accumulate remaining data client-side, then finalize on Publish.

## Figma References

| Screen | Node IDs |
|--------|----------|
| Step 1: Basic Details (Desktop) | `501-5959`, `575-4340` |
| Step 1: Basic Details (Mobile) | `722-8448` |
| Category Picker Modals | `708-7093`, `703-11431`, `703-11369`, `703-11508`, `708-7059`, `708-7127` |
| Category Back Arrow | `703-11503` |
| Add Feature Helper | `575-5079` |
| Step 2: Auction Info (Desktop) | `722-8782`, `585-7547` |
| Step 2: Auction Info (Mobile) | `722-8940`, `585-7725` |
| Auction Duration Helper | `586-8082` |
| Step 3: Logistics (Desktop) | `722-9056`, `585-7913` |
| Step 3: Logistics (Mobile) | `722-9151`, `722-9217` |
| Step 4: Preview (Desktop) | `586-8083` |
| Step 4: Preview (Mobile) | `722-9334` |
| Success Modal (Desktop) | `586-8295` |
| Success Modal (Mobile) | `722-9334` |

Figma file key: `jk9qoWNcSpgUa8lsj7uXa9`

## URL Structure

- `/items/new` — List Item wizard (requires authentication)

## Data Flow

```
Step 1 (Basic Details) → createDraftItem RPC → get item ID → upload images
Step 2 (Auction Info)  → client-side state only
Step 3 (Logistics)     → client-side state only (reads/updates StoreProfile)
Step 4 (Preview)       → updateDraftItem (auction fields + computed end_time) → publishItem → success modal
```

## Backend Changes

### No schema migrations needed

All data fits existing fields:
- **Features** → stored in `Item.attributes` map as `{"Model": "iPhone 13 Pro", "Storage": "128GB", ...}`
- **Auction duration** → computed client-side into `start_time` (now) + `end_time` (now + duration) when publishing
- **Delivery method** → stored on `StoreProfile.delivery_preference` (not per-item)

### Category resource changes

Add two new read actions:

1. **`children_of`** — Load subcategories by parent_id:
   ```elixir
   read :children_of do
     argument :parent_id, :uuid, allow_nil?: false
     filter expr(parent_id == ^arg(:parent_id))
   end
   ```

2. **`search`** — Search categories by name:
   ```elixir
   read :search do
     argument :query, :string, allow_nil?: false
     filter expr(contains(name, ^arg(:query)))
   end
   ```

Both actions need to be exposed via AshTypescript RPC.

### Controller changes

**`ItemsController.new/2`** — Load Inertia props:
- Top-level categories (via `top_level` action)
- Current user's StoreProfile (delivery_preference)

### Existing actions used

- `createDraftItem` — Create item in draft status (Step 1)
- `updateDraftItem` — Update draft with auction info before publish (Step 4)
- `publishItem` — Set publication_status to published + schedule end auction (Step 4)
- Image upload endpoints — Upload images to draft item (Step 1)
- `upsertStoreProfile` — Update delivery preference (Step 3)

## Frontend Structure

### New files

```
assets/js/pages/items/new.tsx                    — Wizard page (replace placeholder)
assets/js/features/listing-form/
  ├── components/
  │   ├── listing-wizard.tsx                     — Step orchestrator + progress bar
  │   ├── basic-details-step.tsx                 — Step 1
  │   ├── auction-info-step.tsx                  — Step 2
  │   ├── logistics-step.tsx                     — Step 3
  │   ├── preview-step.tsx                       — Step 4
  │   ├── category-picker.tsx                    — Hierarchical modal with search
  │   ├── category-field-renderer.tsx            — Dynamic fields from category attribute_schema
  │   ├── feature-fields.tsx                     — Dynamic add/remove custom feature inputs
  │   └── success-modal.tsx                      — Confetti celebration modal
  └── schemas/
      └── listing-form-schema.ts                 — Zod schemas for each step
```

### Form state management

Use `useReducer` for cross-step state. Each step validates its own section via Zod + React Hook Form.

```typescript
type ListingFormState = {
  currentStep: 1 | 2 | 3 | 4;
  draftItemId: string | null;  // Set after Step 1 createDraftItem
  basicDetails: {
    title: string;
    description: string;
    categoryId: string | null;
    condition: "new" | "used" | "refurbished";
    attributes: Record<string, string>;   // Category-defined + custom features
  };
  auctionInfo: {
    startingPrice: string;  // Decimal as string for form input
    reservePrice: string;
    auctionDuration: "24h" | "3d" | "7d";
  };
  logistics: {
    deliveryPreference: "meetup" | "buyer_arranges" | "seller_arranges";
  };
  images: File[];  // Client-side before upload
};
```

## Step-by-Step UI Design

### Progress Indicator

**Desktop:** Tab-style row with labels ("Basic Details", "Auction Info", "Logistics"). Active tab highlighted in orange. Completed tabs show checkmark icons.

**Mobile:** Step progress bar (dots or numbered segments). Current step label shown below.

### Step 1: Basic Details

**Fields:**
1. Item Title (text, required)
2. Description (textarea)
3. Category picker (opens hierarchical modal)
4. **Category-specific fields** — When a category is selected, render dynamic form fields based on that category's `attribute_schema`. For example, selecting "Smartphones" shows: Model, Storage, Color, Display, Chip, Camera, Battery, Connectivity.
5. "Add Feature" button — Adds a custom key-value field beyond the category defaults
6. Condition dropdown (New / Used / Refurbished)
7. Photo upload (drag-and-drop area with image previews)

**Category Picker Modal:**
- Full-screen modal on mobile, dialog on desktop
- Top-level categories shown as a list with right-arrow icons
- Clicking a category shows its subcategories
- Subcategories show checkmarks for selection
- Search bar at top filters across all categories
- Back arrow navigates up the hierarchy

**Category-Specific Fields (from `attribute_schema`):**
- Category's `attribute_schema` defines fields: `{"fields": [{"name": "Model", "type": "string", "required": true}, ...]}`
- When user selects a category, these fields render dynamically
- Changing category replaces the fields (with confirmation if values already entered)
- Values stored in `Item.attributes` map

**"Add Feature" Button:**
- Adds an extra text input below the category fields
- User enters custom feature text (e.g., "Comes with original box")
- Stored in `attributes` with auto-generated keys or as a `_custom_features` array

**On "Next" click:**
1. Validate all fields via Zod schema
2. Call `createDraftItem` RPC with: title, description, categoryId, condition, attributes
3. Upload selected images to the new draft item
4. Advance to Step 2

### Step 2: Auction Info

**Fields:**
1. Starting Price (number input, NGN currency prefix, required)
   - Helper text: "This is the minimum amount buyers can bid"
2. Reserve Price (number input, NGN currency prefix, optional)
   - Helper text: "Only you will see this. Item won't sell unless bids meet this amount."
3. Auction Duration (dropdown: 24 hours, 3 days, 7 days)
   - Helper tooltip: "Dropdown options: 24 hours, 3 days, 7 days."

**On "Next" click:**
1. Validate via Zod schema
2. Store in form state (no backend call)
3. Advance to Step 3

### Step 3: Logistics

**Pre-filled** from current user's `StoreProfile.delivery_preference` (passed as Inertia prop).

**Fields:**
- Radio group: "How will buyers get the item?"
  1. Meet-up in person
  2. Buyer arranges delivery
  3. Seller (you) arranges delivery

**On "Preview" click:**
1. If delivery preference changed, update StoreProfile via `upsertStoreProfile` RPC
2. Advance to Step 4

### Step 4: Preview & Publish

**Read-only preview showing:**
- Item image (first uploaded image)
- Title + condition badge
- Price: Reserve price or starting price
- Auction duration display (e.g., "7 d 0h 0m")
- Bid count: "0 bids"
- Product Description section with "Edit" link → navigates to Step 1
- Key Features section with "Edit" link → navigates to Step 1
- Logistics section with "Edit" link → navigates to Step 3
- Warranty info (placeholder: "7-day DOA protection")
- Return policy (placeholder: "7-day return policy")

**On "Publish" click:**
1. Compute `startTime` = now, `endTime` = now + chosen duration
2. Call `updateDraftItem` with: startingPrice, reservePrice, startTime, endTime
3. Call `publishItem` with item ID
4. Show success modal

### Success Modal

- Overlay modal with confetti animation (use a lightweight confetti library)
- Green checkmark circle icon
- Headline: "Your Item is Live!"
- Subtext: "Buyers can now bid on your listing. You'll get notified when someone places a bid."
- CTA button: "View Listing" → navigates to item detail page

## Responsive Design

**Desktop:** Reuses the store dashboard layout pattern — left sidebar nav + content area. The form appears in the content area.

**Mobile:** Full-width form. Header shows back arrow + "List An Item" title. Step progress bar below header.

## Category Seed Data

Categories need their `attribute_schema` populated. Example schemas:

**Smartphones:**
```json
{"fields": [
  {"name": "Model", "type": "string", "required": true},
  {"name": "Storage", "type": "string"},
  {"name": "Color", "type": "string"},
  {"name": "Display", "type": "string"},
  {"name": "Chip", "type": "string"},
  {"name": "Camera", "type": "string"},
  {"name": "Battery", "type": "string"},
  {"name": "Connectivity", "type": "string"}
]}
```

**Cultural Artifacts:**
```json
{"fields": [
  {"name": "Origin", "type": "string", "required": true},
  {"name": "Age/Period", "type": "string"},
  {"name": "Material", "type": "string"},
  {"name": "Dimensions", "type": "string"}
]}
```

Other categories should follow similar patterns during seed data setup.
