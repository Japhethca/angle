# Location Select for Item Listings - Design Document

**Date:** 2026-02-20
**Status:** Approved
**Feature:** Add Nigerian state and local government selection to item listing flow

## Overview

Add a searchable location combobox to the listing wizard's Logistics step, allowing sellers to specify their item's location using a two-level hierarchy: State (required) → Local Government Area (optional). The feature uses a generic, reusable OptionSet structure and client-side search for instant UX.

## Requirements Summary

- **Where:** Logistics step (Step 3) of the listing wizard
- **Selection:** Two-level hierarchy - Nigerian States → Local Government Areas
- **Validation:** State required, LGA optional
- **Data:** All 36 states + FCT and 774 LGAs
- **UX:** Single searchable combobox showing both levels (e.g., "Lagos → Ikeja")
- **Storage:** Structured data in Item's attributes map (`{_state: "Lagos", _lga: "Ikeja"}`)
- **Loading:** Dynamic RPC call when Logistics step mounts

## Architecture Decisions

### Data Loading Strategy

**Chosen:** Pre-flattened list with client-side search

**Rationale:**
- 811 total items (37 states + 774 LGAs) = ~50KB payload
- Instant search with no network latency
- Simple implementation - one RPC query, cached in component
- Nigerian location data is static and changes rarely

**Alternatives considered:**
- Server-side search: Added complexity, network latency, requires debouncing
- Two-stage loading: Extra network request, worse UX for state-only selection

### Storage Format

**Chosen:** Structured data in attributes map

**Format:**
```json
{
  "_deliveryPreference": "meetup",
  "_state": "Lagos",
  "_lga": "Ikeja"
}
```

**Rationale:**
- No database migration needed (attributes field already exists)
- Still structured and queryable
- Consistent with existing pattern (e.g., `_deliveryPreference`)
- Easy to migrate to dedicated fields later if needed

**Alternatives considered:**
- Text in location field: Less queryable, harder to filter/search
- Separate UUID fields: Requires migration, overkill for read-only reference data

### UX Pattern

**Chosen:** Single searchable combobox with hierarchical results

**Behavior:**
- Shows both state-only and state+LGA options in results
- User types "ikeja" → sees "Lagos → Ikeja"
- User types "lagos" → sees "Lagos" (state only) + all "Lagos → {LGA}" options
- Selecting state-only: `{state: "Lagos"}`
- Selecting state+LGA: `{state: "Lagos", lga: "Ikeja"}`

**Rationale:**
- Modern, efficient - users who know their location can find it in one search
- Honors "state required, LGA optional" naturally
- Single field keeps form clean

**Alternatives considered:**
- Two separate dropdowns: More clicks, less efficient
- Multi-step within combobox: Confusing UX, more complex state management

## Data Structure

### Database Schema

Using existing OptionSet/OptionSetValue resources with parent-child relationships:

```
OptionSet: "Nigerian States"
├─ slug: "ng-states"
├─ parent_id: null
└─ OptionSetValues:
   ├─ "Abia"
   ├─ "Lagos"
   └─ ... (37 total)

OptionSet: "Abia LGAs"
├─ slug: "ng-lgas-abia"
├─ parent_id: <Abia option set ID>
└─ OptionSetValues:
   ├─ "Aba North" (parent_value: "Abia")
   ├─ "Aba South" (parent_value: "Abia")
   └─ ... (17 total for Abia)

OptionSet: "Lagos LGAs"
├─ slug: "ng-lgas-lagos"
├─ parent_id: <Lagos option set ID>
└─ OptionSetValues:
   ├─ "Ikeja" (parent_value: "Lagos")
   ├─ "Surulere" (parent_value: "Lagos")
   └─ ... (20 total for Lagos)
```

### Flattened Frontend Format

```typescript
[
  { value: "Abia", label: "Abia", type: "state" },
  { value: "Abia|Aba North", label: "Abia → Aba North", type: "lga" },
  { value: "Abia|Aba South", label: "Abia → Aba South", type: "lga" },
  // ... 774 more LGAs
  { value: "Lagos", label: "Lagos", type: "state" },
  { value: "Lagos|Ikeja", label: "Lagos → Ikeja", type: "lga" },
  { value: "Lagos|Surulere", label: "Lagos → Surulere", type: "lga" },
]
```

## Backend Implementation

### New Ash Action

Add to `lib/angle/catalog/option_set.ex`:

```elixir
read :read_with_descendants do
  description "Read option set with its values, children, and children's values loaded"

  argument :slug, :string, allow_nil?: false

  filter expr(slug == ^arg(:slug))

  prepare build(load: [:option_set_values, children: [:option_set_values]])
end
```

**Generic & Reusable:**
- Works for Nigerian locations: `slug: "ng-states"`
- Works for any future hierarchical option sets

### AshTypescript Integration

1. Expose action in `config/config.exs`:
```elixir
config :angle, AshTypescript,
  domains: [
    {Angle.Catalog, actions: [
      Angle.Catalog.OptionSet.read_with_descendants
    ]}
  ]
```

2. Run `mix ash_typescript.codegen`

3. Generated in `ash_rpc.ts`:
```typescript
export async function readOptionSetWithDescendants(params: {
  slug: string;
  headers?: Record<string, string>;
}): Promise<RpcResult<OptionSet>>
```

### Seed Script

Create `priv/repo/seeds/nigerian_locations.exs`:

**Content:**
- All 36 states + Federal Capital Territory (FCT)
- All 774 Local Government Areas organized by state
- Uses `create_with_values` action (idempotent, safe to re-run)

**Structure:**
```elixir
# Create parent option set for states
states_option_set = OptionSet.create!(%{
  name: "Nigerian States",
  slug: "ng-states",
  values: [
    %{value: "Abia", label: "Abia"},
    %{value: "Lagos", label: "Lagos"},
    # ... all 37
  ]
})

# Create child option set for each state's LGAs
OptionSet.create!(%{
  name: "Lagos LGAs",
  slug: "ng-lgas-lagos",
  parent_id: states_option_set.id,
  values: [
    %{value: "Ikeja", label: "Ikeja", parent_value: "Lagos"},
    %{value: "Surulere", label: "Surulere", parent_value: "Lagos"},
    # ... all 20 Lagos LGAs
  ]
})
```

**Key:** Use `parent_value` field to enable quick filtering without extra queries.

## Frontend Implementation

### Component: LocationCombobox

**File:** `assets/js/components/forms/location-combobox.tsx`

**Interface:**
```typescript
interface LocationOption {
  value: string;        // "Lagos" or "Lagos|Ikeja"
  label: string;        // "Lagos" or "Lagos → Ikeja"
  type: "state" | "lga";
}

interface LocationComboboxProps {
  value?: { state: string; lga?: string };
  onChange: (value: { state: string; lga?: string }) => void;
  error?: string;
}
```

**Features:**
1. **Load data on mount:**
```typescript
const { data: optionSetData, isLoading } = useAshQuery(
  "readOptionSetWithDescendants",
  { slug: "ng-states" }
);
```

2. **Flatten hierarchical data:**
```typescript
const flattenedOptions = useMemo(() => {
  if (!optionSetData) return [];

  const states = optionSetData.option_set_values.map(state => ({
    value: state.value,
    label: state.label,
    type: "state"
  }));

  const lgas = optionSetData.children.flatMap(child =>
    child.option_set_values.map(lga => ({
      value: `${lga.parent_value}|${lga.value}`,
      label: `${lga.parent_value} → ${lga.value}`,
      type: "lga"
    }))
  );

  return [...states, ...lgas];
}, [optionSetData]);
```

3. **Client-side search:**
```typescript
const filteredOptions = flattenedOptions.filter(opt =>
  opt.label.toLowerCase().includes(searchQuery.toLowerCase())
);
```

4. **Handle selection:**
```typescript
const handleSelect = (selectedValue: string) => {
  if (selectedValue.includes("|")) {
    // LGA selected: "Lagos|Ikeja"
    const [state, lga] = selectedValue.split("|");
    onChange({ state, lga });
  } else {
    // State only: "Lagos"
    onChange({ state: selectedValue });
  }
};
```

**Built on:**
- shadcn/ui Combobox (Radix UI primitives)
- Accessible, keyboard navigation
- Loading/error states

### Form Integration

**File:** `assets/js/features/listing-form/schemas/listing-form-schema.ts`

**Update schema:**
```typescript
export const logisticsSchema = z.object({
  deliveryPreference: z.enum(["meetup", "buyer_arranges", "seller_arranges"]),
  location: z.object({
    state: z.string().min(1, "State is required"),
    lga: z.string().optional(),
  }),
});
```

**Update initial state:**
```typescript
logistics: {
  deliveryPreference: "buyer_arranges",
  location: { state: "", lga: "" },
},
```

**File:** `assets/js/features/listing-form/components/logistics-step.tsx`

**Add to form:**
```tsx
<div className="space-y-3">
  <Label className="text-base font-medium">
    Where is the item located? <span className="text-destructive">*</span>
  </Label>
  <LocationCombobox
    value={watch("location")}
    onChange={(val) => setValue("location", val)}
    error={errors.location?.state?.message}
  />
  <p className="text-xs text-content-tertiary">
    Buyers need to know the item's location for delivery/pickup planning
  </p>
</div>
```

**Update save logic:**
```typescript
const result = await updateDraftItem({
  identity: draftItemId,
  input: {
    id: draftItemId,
    attributes: {
      _deliveryPreference: data.deliveryPreference,
      _state: data.location.state,
      _lga: data.location.lga || null,
    },
  },
  headers: buildCSRFHeaders(),
});
```

## Data Flow

### 1. Logistics Step Mount
```
LogisticsStep renders
└─> LocationCombobox mounts
    └─> useAshQuery("readOptionSetWithDescendants", {slug: "ng-states"})
        └─> Returns hierarchical OptionSet data
            └─> Component flattens to 811 searchable items
                └─> Ready for user input
```

### 2. User Search & Selection
```
User types "ikeja"
└─> Client filters 811 items
    └─> Shows "Lagos → Ikeja"
        └─> User clicks
            └─> Parses "Lagos|Ikeja"
                └─> Calls onChange({state: "Lagos", lga: "Ikeja"})
                    └─> Form state updated
```

### 3. Form Submission
```
User clicks "Preview"
└─> Zod validates: state ✓ required, lga ✓ optional
    └─> updateDraftItem RPC
        └─> Saves to Item.attributes:
            {_state: "Lagos", _lga: "Ikeja"}
            └─> Navigate to preview page
```

### 4. Edit Flow
```
User edits existing draft
└─> Controller loads item with attributes
    └─> Wizard initialized with:
        logistics: {
          location: {
            state: item.attributes._state,
            lga: item.attributes._lga
          }
        }
        └─> LocationCombobox displays current selection
```

## Display & Usage

### Item Preview Page
```tsx
<div className="text-sm text-content-secondary">
  <MapPin className="inline size-4 mr-1" />
  {item.attributes._lga
    ? `${item.attributes._state}, ${item.attributes._lga}`
    : item.attributes._state
  }
</div>
```

### Item Cards (Future)
```tsx
// In listing grids/search results
<div className="text-xs text-content-tertiary">
  {item.attributes._state}
  {item.attributes._lga && ` • ${item.attributes._lga}`}
</div>
```

### Search Filters (Future Enhancement)
```typescript
// Can filter by state
items.filter(item => item.attributes._state === "Lagos")

// Can filter by LGA
items.filter(item => item.attributes._lga === "Ikeja")
```

## Testing Strategy

### Backend Tests

**File:** `test/angle/catalog/option_set_test.exs`

```elixir
describe "read_with_descendants/1" do
  test "loads option set with children and their values" do
    # Create states option set with values
    # Create child LGA option sets
    # Call read_with_descendants
    # Assert structure is correct
  end
end
```

### Frontend Tests

**File:** `assets/js/components/forms/location-combobox.test.tsx`

```typescript
describe("LocationCombobox", () => {
  it("loads and flattens location data");
  it("filters options based on search query");
  it("handles state-only selection");
  it("handles state+LGA selection");
  it("shows validation error when required");
  it("displays loading state while fetching");
});
```

**File:** `assets/js/features/listing-form/components/logistics-step.test.tsx`

```typescript
describe("LogisticsStep with location", () => {
  it("validates state is required");
  it("allows LGA to be optional");
  it("saves location to item attributes");
  it("loads existing location on edit");
});
```

## Implementation Phases

### Phase 1: Data Setup
1. Create seed script with Nigerian states/LGAs
2. Run seed script to populate database
3. Verify data structure and relationships

### Phase 2: Backend API
1. Add `read_with_descendants` action to OptionSet
2. Update AshTypescript config
3. Run codegen to generate TypeScript types/functions
4. Test RPC endpoint

### Phase 3: Frontend Component
1. Create LocationCombobox component
2. Implement data loading and flattening
3. Implement search/filter logic
4. Add visual styling (state bold, LGA with arrow)
5. Test component in isolation

### Phase 4: Form Integration
1. Update logistics schema with location validation
2. Add LocationCombobox to LogisticsStep
3. Update form submission to save location
4. Update initial state handling for edits
5. Test complete flow: create → edit → publish

### Phase 5: Display
1. Add location display to preview page
2. Add location display to item cards
3. Add location icon (MapPin from lucide-react)

## Future Enhancements

### Search by Location
- Add state/LGA filters to search page
- Show item count per state
- "Items near me" based on user's saved location

### Location Analytics
- Most popular states for listings
- Most active buying/selling regions
- Inform delivery partnership decisions

### Delivery Cost Estimation
- Integrate with logistics APIs
- Show estimated shipping cost based on buyer/seller locations
- Auto-calculate delivery fees

### Multiple Locations
- Allow sellers to list items in multiple locations (branches)
- Support "Ships from multiple locations"

## Success Metrics

- **Adoption:** % of new listings with location specified
- **Completion:** % of users who complete location field vs skip/bounce
- **Quality:** % of listings with LGA specified (not just state)
- **Search:** Location-based search usage (future)

## Risks & Mitigations

### Risk: Large Data Payload
**Impact:** Slow initial load
**Mitigation:** 811 items = ~50KB (negligible), cached in component
**Monitoring:** Check bundle size after implementation

### Risk: Incorrect State/LGA Mappings
**Impact:** User frustration, incorrect locations
**Mitigation:** Use official government data source, test with Nigerian team members
**Monitoring:** Allow users to report incorrect mappings

### Risk: Search Performance
**Impact:** Laggy UX when typing
**Mitigation:** Simple includes-based search is fast for 811 items, can upgrade to fuzzy search if needed
**Monitoring:** Performance profiling during testing

## Open Questions

None - all design decisions have been made and approved.

## Appendix: Nigerian Location Data Source

Data source for seed script:
- National Bureau of Statistics (Nigeria)
- 36 states + Federal Capital Territory
- 774 Local Government Areas
- Official government structure (stable, rarely changes)

States list: Abia, Adamawa, Akwa Ibom, Anambra, Bauchi, Bayelsa, Benue, Borno, Cross River, Delta, Ebonyi, Edo, Ekiti, Enugu, FCT, Gombe, Imo, Jigawa, Kaduna, Kano, Katsina, Kebbi, Kogi, Kwara, Lagos, Nasarawa, Niger, Ogun, Ondo, Osun, Oyo, Plateau, Rivers, Sokoto, Taraba, Yobe, Zamfara
