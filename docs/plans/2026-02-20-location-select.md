# Location Select Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add searchable Nigerian state/LGA location selector to item listing wizard (Logistics step).

**Architecture:** Generic Ash read action loads hierarchical OptionSet data (states + LGAs) via RPC. Frontend flattens to searchable list, stores selection as `{_state, _lga}` in Item.attributes map. Client-side search for instant UX.

**Tech Stack:** Elixir/Ash Framework, AshTypescript, React 19, shadcn/ui Combobox, Zod validation, TanStack Query

---

## Task 1: Create Nigerian Locations Seed Script

**Files:**
- Create: `priv/repo/seeds/nigerian_locations.exs`

**Step 1: Write seed script with test data (3 states)**

Create seed script with Abia, Lagos, FCT and their LGAs for testing:

```elixir
# priv/repo/seeds/nigerian_locations.exs
#
# Run: mix run priv/repo/seeds/nigerian_locations.exs
#
# Creates Nigerian states and LGAs as hierarchical option sets.
# Safe to run multiple times (idempotent).

alias Angle.Catalog.OptionSet
require Ash.Query

# State definitions with their LGAs
states_with_lgas = [
  %{
    state: "Abia",
    lgas: [
      "Aba North", "Aba South", "Arochukwu", "Bende", "Ikwuano",
      "Isiala Ngwa North", "Isiala Ngwa South", "Isuikwuato", "Obi Ngwa",
      "Ohafia", "Osisioma", "Ugwunagbo", "Ukwa East", "Ukwa West",
      "Umuahia North", "Umuahia South", "Umu Nneochi"
    ]
  },
  %{
    state: "Lagos",
    lgas: [
      "Agege", "Ajeromi-Ifelodun", "Alimosho", "Amuwo-Odofin", "Apapa",
      "Badagry", "Epe", "Eti-Osa", "Ibeju-Lekki", "Ifako-Ijaiye",
      "Ikeja", "Ikorodu", "Kosofe", "Lagos Island", "Lagos Mainland",
      "Mushin", "Ojo", "Oshodi-Isolo", "Shomolu", "Surulere"
    ]
  },
  %{
    state: "FCT",
    lgas: [
      "Abaji", "Abuja Municipal", "Bwari", "Gwagwalada", "Kuje", "Kwali"
    ]
  }
]

# Create parent option set for states
IO.puts("Creating Nigerian States option set...")

states_option_set =
  case OptionSet
       |> Ash.Query.filter(slug == "ng-states")
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      state_values =
        Enum.map(states_with_lgas, fn %{state: name} ->
          %{value: name, label: name, sort_order: 0}
        end)

      OptionSet
      |> Ash.Changeset.for_create(
        :create_with_values,
        %{
          name: "Nigerian States",
          slug: "ng-states",
          description: "All Nigerian states and Federal Capital Territory",
          values: state_values
        },
        authorize?: false
      )
      |> Ash.create!()

    {:ok, existing} ->
      IO.puts("  → Nigerian States option set already exists, skipping")
      existing
  end

IO.puts("✓ Nigerian States created")

# Create child option sets for each state's LGAs
IO.puts("\nCreating LGA option sets...")

for %{state: state_name, lgas: lgas} <- states_with_lgas do
  slug = "ng-lgas-#{String.downcase(state_name) |> String.replace(" ", "-")}"

  case OptionSet
       |> Ash.Query.filter(slug == ^slug)
       |> Ash.read_one(authorize?: false) do
    {:ok, nil} ->
      lga_values =
        lgas
        |> Enum.with_index(1)
        |> Enum.map(fn {lga, idx} ->
          %{
            value: lga,
            label: lga,
            parent_value: state_name,
            sort_order: idx
          }
        end)

      OptionSet
      |> Ash.Changeset.for_create(
        :create_with_values,
        %{
          name: "#{state_name} LGAs",
          slug: slug,
          description: "Local Government Areas in #{state_name}",
          parent_id: states_option_set.id,
          values: lga_values
        },
        authorize?: false
      )
      |> Ash.create!()

      IO.puts("  ✓ Created #{state_name} LGAs (#{length(lgas)} LGAs)")

    {:ok, _existing} ->
      IO.puts("  → #{state_name} LGAs already exist, skipping")
  end
end

IO.puts("\n✓ Done seeding Nigerian locations (3 states for testing)")
IO.puts("Total: #{length(states_with_lgas)} states, #{Enum.sum(Enum.map(states_with_lgas, fn s -> length(s.lgas) end))} LGAs")
```

**Step 2: Run seed script**

```bash
mix run priv/repo/seeds/nigerian_locations.exs
```

Expected output:
```
Creating Nigerian States option set...
✓ Nigerian States created

Creating LGA option sets...
  ✓ Created Abia LGAs (17 LGAs)
  ✓ Created Lagos LGAs (20 LGAs)
  ✓ Created FCT LGAs (6 LGAs)

✓ Done seeding Nigerian locations (3 states for testing)
Total: 3 states, 43 LGAs
```

**Step 3: Verify data in database**

```bash
mix run -e "
  Angle.Catalog.OptionSet
  |> Ash.Query.filter(slug == \"ng-states\")
  |> Ash.read_one!(authorize?: false, load: [:option_set_values, children: [:option_set_values]])
  |> then(fn os ->
    IO.puts(\"States: #{length(os.option_set_values)}\")
    IO.puts(\"Child option sets: #{length(os.children)}\")
    Enum.each(os.children, fn child ->
      IO.puts(\"  #{child.name}: #{length(child.option_set_values)} LGAs\")
    end)
  end)
"
```

Expected output:
```
States: 3
Child option sets: 3
  Abia LGAs: 17 LGAs
  Lagos LGAs: 20 LGAs
  FCT LGAs: 6 LGAs
```

**Step 4: Commit seed script**

```bash
git add priv/repo/seeds/nigerian_locations.exs
git commit -m "feat: add Nigerian states/LGAs seed script (3 states for testing)

Create hierarchical option sets for Nigerian locations:
- Parent: Nigerian States (ng-states)
- Children: State LGAs (ng-lgas-{state})

Includes Abia (17 LGAs), Lagos (20 LGAs), FCT (6 LGAs).
Idempotent - safe to run multiple times.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Add Generic Ash Read Action

**Files:**
- Modify: `lib/angle/catalog/option_set.ex` (after line 68, in actions block)
- Test: `test/angle/catalog/option_set_test.exs`

**Step 1: Write failing test**

Create test file if it doesn't exist, or add to existing file:

```elixir
# test/angle/catalog/option_set_test.exs
defmodule Angle.Catalog.OptionSetTest do
  use Angle.DataCase, async: true

  alias Angle.Catalog.OptionSet

  describe "read_with_descendants/1" do
    test "loads option set with children and their values" do
      # Create parent option set with values
      {:ok, parent} =
        OptionSet
        |> Ash.Changeset.for_create(
          :create_with_values,
          %{
            name: "Test Parent",
            slug: "test-parent",
            values: [
              %{value: "Option 1", label: "Option 1"},
              %{value: "Option 2", label: "Option 2"}
            ]
          },
          authorize?: false
        )
        |> Ash.create()

      # Create child option set with values
      {:ok, _child} =
        OptionSet
        |> Ash.Changeset.for_create(
          :create_with_values,
          %{
            name: "Test Child",
            slug: "test-child",
            parent_id: parent.id,
            values: [
              %{value: "Child 1", label: "Child 1", parent_value: "Option 1"},
              %{value: "Child 2", label: "Child 2", parent_value: "Option 1"}
            ]
          },
          authorize?: false
        )
        |> Ash.create()

      # Test the read_with_descendants action
      {:ok, result} =
        OptionSet
        |> Ash.Query.for_read(:read_with_descendants, %{slug: "test-parent"})
        |> Ash.read_one(authorize?: false)

      # Assert structure
      assert result.name == "Test Parent"
      assert length(result.option_set_values) == 2
      assert length(result.children) == 1

      child = List.first(result.children)
      assert child.name == "Test Child"
      assert length(child.option_set_values) == 2
    end

    test "returns error when slug not found" do
      result =
        OptionSet
        |> Ash.Query.for_read(:read_with_descendants, %{slug: "nonexistent"})
        |> Ash.read_one(authorize?: false)

      assert {:ok, nil} = result
    end
  end
end
```

**Step 2: Run test to verify it fails**

```bash
mix test test/angle/catalog/option_set_test.exs
```

Expected: FAIL with "no action :read_with_descendants"

**Step 3: Implement read_with_descendants action**

Add to `lib/angle/catalog/option_set.ex` after the existing `read_with_parent` action (around line 68):

```elixir
read :read_with_descendants do
  description "Read option set with its values, children, and children's values loaded"

  argument :slug, :string, allow_nil?: false

  filter expr(slug == ^arg(:slug))

  prepare build(load: [:option_set_values, children: [:option_set_values]])
end
```

**Step 4: Run test to verify it passes**

```bash
mix test test/angle/catalog/option_set_test.exs
```

Expected: PASS (2 tests)

**Step 5: Commit**

```bash
git add lib/angle/catalog/option_set.ex test/angle/catalog/option_set_test.exs
git commit -m "feat: add read_with_descendants action to OptionSet

Add generic action to load option set with children and their values.
Supports hierarchical data loading for location selectors and similar
use cases.

Accepts slug argument, returns option set with:
- option_set_values loaded
- children loaded with their option_set_values

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Expose Action via AshTypescript

**Files:**
- Modify: `config/config.exs` (AshTypescript config section)

**Step 1: Add action to AshTypescript config**

Find the AshTypescript config in `config/config.exs` and add the new action:

```elixir
# Find this section (around line 10-22)
config :angle, AshTypescript,
  # ... existing config ...

# Update to include the new action in the appropriate place
# The exact location depends on current config structure
```

**Note:** Since the exact config structure may vary, search for `AshTypescript` and ensure `Angle.Catalog.OptionSet` domain/resource is exposed with the new action.

**Step 2: Run TypeScript codegen**

```bash
mix ash_typescript.codegen
```

Expected output:
```
Generating TypeScript types...
✓ Generated types for Angle.Catalog
✓ Generated RPC functions
```

**Step 3: Verify generated function exists**

```bash
grep -n "readOptionSetWithDescendants" assets/js/ash_rpc.ts
```

Expected: Shows line number with function definition

**Step 4: Commit**

```bash
git add config/config.exs assets/js/ash_rpc.ts
git commit -m "feat: expose read_with_descendants via AshTypescript RPC

Generate readOptionSetWithDescendants function for frontend.
Enables loading hierarchical option sets from React components.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Update Logistics Schema

**Files:**
- Modify: `assets/js/features/listing-form/schemas/listing-form-schema.ts`

**Step 1: Write test for updated schema**

Create test file:

```typescript
// assets/js/features/listing-form/schemas/listing-form-schema.test.ts
import { describe, it, expect } from "vitest";
import { logisticsSchema } from "./listing-form-schema";

describe("logisticsSchema", () => {
  it("validates delivery preference is required", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos" },
    });
    expect(result.success).toBe(true);
  });

  it("requires state in location", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "" },
    });
    expect(result.success).toBe(false);
    expect(result.error?.issues[0].path).toEqual(["location", "state"]);
  });

  it("allows LGA to be optional", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos" },
    });
    expect(result.success).toBe(true);
  });

  it("accepts state with LGA", () => {
    const result = logisticsSchema.safeParse({
      deliveryPreference: "meetup",
      location: { state: "Lagos", lga: "Ikeja" },
    });
    expect(result.success).toBe(true);
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npm test -- listing-form-schema.test.ts
```

Expected: FAIL with "location field doesn't exist" or similar

**Step 3: Update schema**

Modify `assets/js/features/listing-form/schemas/listing-form-schema.ts`:

```typescript
// Update logisticsSchema (around line 34)
export const logisticsSchema = z.object({
  deliveryPreference: z.enum(["meetup", "buyer_arranges", "seller_arranges"]),
  location: z.object({
    state: z.string().min(1, "State is required"),
    lga: z.string().optional(),
  }),
});

// Update initialFormState (around line 83)
logistics: {
  deliveryPreference: "buyer_arranges",
  location: { state: "", lga: "" },
},
```

**Step 4: Run test to verify it passes**

```bash
npm test -- listing-form-schema.test.ts
```

Expected: PASS (4 tests)

**Step 5: Commit**

```bash
git add assets/js/features/listing-form/schemas/listing-form-schema.ts assets/js/features/listing-form/schemas/listing-form-schema.test.ts
git commit -m "feat: add location field to logistics schema

Add location validation:
- state: required (min 1 char)
- lga: optional

Update initialFormState with location defaults.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Create LocationCombobox Component

**Files:**
- Create: `assets/js/components/forms/location-combobox.tsx`
- Test: `assets/js/components/forms/location-combobox.test.tsx`

**Step 1: Write component test**

```typescript
// assets/js/components/forms/location-combobox.test.tsx
import { describe, it, expect, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LocationCombobox } from "./location-combobox";
import * as ashQuery from "@/hooks/use-ash-query";

// Mock useAshQuery
vi.mock("@/hooks/use-ash-query");

const mockLocationData = {
  id: "test-id",
  name: "Nigerian States",
  slug: "ng-states",
  option_set_values: [
    { id: "1", value: "Lagos", label: "Lagos" },
    { id: "2", value: "Abia", label: "Abia" },
  ],
  children: [
    {
      id: "child-1",
      name: "Lagos LGAs",
      option_set_values: [
        { id: "3", value: "Ikeja", label: "Ikeja", parent_value: "Lagos" },
        { id: "4", value: "Surulere", label: "Surulere", parent_value: "Lagos" },
      ],
    },
    {
      id: "child-2",
      name: "Abia LGAs",
      option_set_values: [
        { id: "5", value: "Aba North", label: "Aba North", parent_value: "Abia" },
      ],
    },
  ],
};

describe("LocationCombobox", () => {
  it("loads and flattens location data", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    // Should show searchable combobox
    expect(screen.getByRole("combobox")).toBeInTheDocument();
  });

  it("filters options based on search query", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    const input = screen.getByRole("combobox");
    await user.type(input, "ikeja");

    await waitFor(() => {
      expect(screen.getByText(/Lagos → Ikeja/i)).toBeInTheDocument();
    });
  });

  it("handles state-only selection", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    const input = screen.getByRole("combobox");
    await user.click(input);
    await user.click(screen.getByText("Lagos"));

    expect(onChange).toHaveBeenCalledWith({ state: "Lagos" });
  });

  it("handles state+LGA selection", async () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: mockLocationData,
      isLoading: false,
      error: null,
    } as any);

    const onChange = vi.fn();
    const user = userEvent.setup();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    const input = screen.getByRole("combobox");
    await user.click(input);
    await user.click(screen.getByText(/Lagos → Ikeja/i));

    expect(onChange).toHaveBeenCalledWith({ state: "Lagos", lga: "Ikeja" });
  });

  it("displays loading state while fetching", () => {
    vi.mocked(ashQuery.useAshQuery).mockReturnValue({
      data: null,
      isLoading: true,
      error: null,
    } as any);

    const onChange = vi.fn();
    render(<LocationCombobox value={undefined} onChange={onChange} />);

    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });
});
```

**Step 2: Run test to verify it fails**

```bash
npm test -- location-combobox.test.tsx
```

Expected: FAIL with "module not found" or component doesn't exist

**Step 3: Create LocationCombobox component**

```typescript
// assets/js/components/forms/location-combobox.tsx
import { useMemo, useState } from "react";
import { Check, ChevronsUpDown, Loader2 } from "lucide-react";
import { useAshQuery } from "@/hooks/use-ash-query";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import {
  Command,
  CommandEmpty,
  CommandGroup,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";

interface LocationOption {
  value: string;
  label: string;
  type: "state" | "lga";
}

interface LocationComboboxProps {
  value?: { state: string; lga?: string };
  onChange: (value: { state: string; lga?: string }) => void;
  error?: string;
}

export function LocationCombobox({ value, onChange, error }: LocationComboboxProps) {
  const [open, setOpen] = useState(false);

  const { data: optionSetData, isLoading } = useAshQuery(
    "readOptionSetWithDescendants",
    { slug: "ng-states" }
  );

  const flattenedOptions = useMemo<LocationOption[]>(() => {
    if (!optionSetData) return [];

    const states: LocationOption[] = optionSetData.option_set_values.map((state) => ({
      value: state.value,
      label: state.label,
      type: "state" as const,
    }));

    const lgas: LocationOption[] = optionSetData.children.flatMap((child) =>
      child.option_set_values.map((lga) => ({
        value: `${lga.parent_value}|${lga.value}`,
        label: `${lga.parent_value} → ${lga.value}`,
        type: "lga" as const,
      }))
    );

    return [...states, ...lgas];
  }, [optionSetData]);

  const displayValue = useMemo(() => {
    if (!value?.state) return "Select location...";
    if (value.lga) return `${value.state} → ${value.lga}`;
    return value.state;
  }, [value]);

  const selectedValue = useMemo(() => {
    if (!value?.state) return "";
    if (value.lga) return `${value.state}|${value.lga}`;
    return value.state;
  }, [value]);

  const handleSelect = (selectedValue: string) => {
    if (selectedValue.includes("|")) {
      const [state, lga] = selectedValue.split("|");
      onChange({ state, lga });
    } else {
      onChange({ state: selectedValue });
    }
    setOpen(false);
  };

  if (isLoading) {
    return (
      <div className="flex items-center gap-2 text-sm text-content-tertiary">
        <Loader2 className="size-4 animate-spin" />
        Loading locations...
      </div>
    );
  }

  return (
    <div className="space-y-2">
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverTrigger asChild>
          <Button
            variant="outline"
            role="combobox"
            aria-expanded={open}
            className={cn(
              "w-full justify-between font-normal",
              !value?.state && "text-content-tertiary",
              error && "border-destructive"
            )}
          >
            {displayValue}
            <ChevronsUpDown className="ml-2 size-4 shrink-0 opacity-50" />
          </Button>
        </PopoverTrigger>
        <PopoverContent className="w-[400px] p-0" align="start">
          <Command>
            <CommandInput placeholder="Search location..." />
            <CommandList>
              <CommandEmpty>No location found.</CommandEmpty>
              <CommandGroup>
                {flattenedOptions.map((option) => (
                  <CommandItem
                    key={option.value}
                    value={option.value}
                    onSelect={handleSelect}
                    className={cn(
                      option.type === "lga" && "pl-6",
                      option.type === "state" && "font-medium"
                    )}
                  >
                    <Check
                      className={cn(
                        "mr-2 size-4",
                        selectedValue === option.value ? "opacity-100" : "opacity-0"
                      )}
                    />
                    {option.label}
                  </CommandItem>
                ))}
              </CommandGroup>
            </CommandList>
          </Command>
        </PopoverContent>
      </Popover>
      {error && <p className="text-sm text-destructive">{error}</p>}
    </div>
  );
}
```

**Step 4: Run test to verify it passes**

```bash
npm test -- location-combobox.test.tsx
```

Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add assets/js/components/forms/location-combobox.tsx assets/js/components/forms/location-combobox.test.tsx
git commit -m "feat: create LocationCombobox component

Add searchable location selector with:
- Loads Nigerian states/LGAs via RPC
- Client-side filtering (instant search)
- Hierarchical display (state bold, LGA indented)
- Supports state-only or state+LGA selection
- Loading and error states

Built on shadcn/ui Combobox (Command + Popover).

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Integrate LocationCombobox into LogisticsStep

**Files:**
- Modify: `assets/js/features/listing-form/components/logistics-step.tsx`

**Step 1: Add location field to form**

Update `logistics-step.tsx` to import and use LocationCombobox:

```typescript
// Add import at top
import { LocationCombobox } from "@/components/forms/location-combobox";

// In the component, update useForm to include errors
const {
  handleSubmit,
  watch,
  setValue,
  formState: { errors }, // Add this
} = useForm<LogisticsData>({
  resolver: zodResolver(logisticsSchema),
  defaultValues,
});

// Add location field after delivery preference (around line 100, before the submit button)
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

**Step 2: Update save logic**

Update the `onSubmit` function to include location:

```typescript
// Around line 40-50, update the updateDraftItem call
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

**Step 3: Test manually**

```bash
# Start dev server if not running
mix phx.server

# Navigate to http://localhost:4111/store/listings/new
# Go through wizard to Logistics step
# Verify location combobox appears and works
```

**Step 4: Commit**

```bash
git add assets/js/features/listing-form/components/logistics-step.tsx
git commit -m "feat: integrate location select into logistics step

Add LocationCombobox to form:
- State required, LGA optional (validated)
- Save to Item.attributes as _state and _lga
- Display helper text for context

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: Update Edit Flow to Load Existing Location

**Files:**
- Modify: `assets/js/pages/store/listings/edit.tsx` (if it passes location in initialData)
- Verify: Wizard properly loads existing location from attributes

**Step 1: Check current edit page implementation**

Read `assets/js/pages/store/listings/edit.tsx` to see how it loads initialData.

**Step 2: Ensure location is extracted from attributes**

If the edit page loads `initialData`, ensure it includes location:

```typescript
// In the controller or wherever initialData is prepared
logistics: {
  deliveryPreference: mapDeliveryPreference(item.attributes._deliveryPreference),
  location: {
    state: item.attributes._state || "",
    lga: item.attributes._lga || "",
  },
},
```

**Step 3: Test edit flow manually**

```bash
# Create a listing with location
# Edit it
# Verify location field shows previously selected value
```

**Step 4: Commit if changes made**

```bash
git add assets/js/pages/store/listings/edit.tsx
git commit -m "fix: load existing location in edit flow

Extract _state and _lga from item attributes when editing.
Pre-populate LocationCombobox with saved values.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Add Location Display to Preview Page

**Files:**
- Modify: `assets/js/pages/store/listings/preview.tsx`

**Step 1: Add MapPin icon import**

```typescript
import { MapPin } from "lucide-react";
```

**Step 2: Add location display section**

Find where item details are displayed and add location:

```tsx
{/* Location */}
{item.attributes._state && (
  <div className="flex items-center gap-2 text-sm text-content-secondary">
    <MapPin className="size-4" />
    <span>
      {item.attributes._lga
        ? `${item.attributes._state}, ${item.attributes._lga}`
        : item.attributes._state}
    </span>
  </div>
)}
```

**Step 3: Test manually**

```bash
# Create listing with location
# Preview it
# Verify location displays correctly
```

**Step 4: Commit**

```bash
git add assets/js/pages/store/listings/preview.tsx
git commit -m "feat: display location on preview page

Show item location with MapPin icon.
Format: \"State, LGA\" or just \"State\" if no LGA.

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Add All 36 States + FCT to Seed Script

**Files:**
- Modify: `priv/repo/seeds/nigerian_locations.exs`

**Step 1: Expand seed data to all states**

Replace the test data (3 states) with complete data for all 36 states + FCT.

**Data source:** Use official Nigerian government LGA list.

**Format:** Keep same structure, expand `states_with_lgas` array to include all states.

**Step 2: Run expanded seed script**

```bash
mix run priv/repo/seeds/nigerian_locations.exs
```

Expected output:
```
✓ Done seeding Nigerian locations
Total: 37 states, 774 LGAs
```

**Step 3: Verify complete data**

```bash
mix run -e "
  Angle.Catalog.OptionSet
  |> Ash.Query.filter(slug == \"ng-states\")
  |> Ash.read_one!(authorize?: false, load: [:option_set_values, children: [:option_set_values]])
  |> then(fn os ->
    IO.puts(\"Total states: #{length(os.option_set_values)}\")
    IO.puts(\"Total LGA option sets: #{length(os.children)}\")
    total_lgas = Enum.sum(Enum.map(os.children, fn c -> length(c.option_set_values) end))
    IO.puts(\"Total LGAs: #{total_lgas}\")
  end)
"
```

Expected output:
```
Total states: 37
Total LGA option sets: 37
Total LGAs: 774
```

**Step 4: Commit**

```bash
git add priv/repo/seeds/nigerian_locations.exs
git commit -m "feat: add complete Nigerian states/LGAs data (37 states, 774 LGAs)

Expand seed script with all Nigerian states and local governments:
- 36 states + Federal Capital Territory
- 774 Local Government Areas
- Official government structure data

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: End-to-End Manual Testing

**Files:**
- None (manual testing)

**Step 1: Test complete create flow**

1. Navigate to `/store/listings/new`
2. Fill Basic Details (Step 1) → Next
3. Fill Auction Info (Step 2) → Next
4. Fill Logistics (Step 3):
   - Select delivery preference
   - Search for "ikeja" in location
   - Select "Lagos → Ikeja"
   - Click Preview
5. Verify preview shows "Lagos, Ikeja"
6. Publish item
7. Verify item is saved with location in attributes

**Step 2: Test state-only selection**

1. Create new listing
2. In Logistics step, select just "Lagos" (no LGA)
3. Preview and verify shows "Lagos" (not "Lagos, ")
4. Publish and verify

**Step 3: Test edit flow**

1. Edit a listing with location
2. Verify location pre-populates correctly
3. Change location
4. Save and verify update persists

**Step 4: Test validation**

1. Create new listing
2. In Logistics step, skip location (leave empty)
3. Click Preview
4. Verify validation error: "State is required"
5. Select location and proceed

**Step 5: Test search functionality**

1. In location combobox, type "aba"
2. Verify shows:
   - "Abia" (state)
   - "Abia → Aba North"
   - "Abia → Aba South"
3. Test case-insensitive search
4. Test filtering with partial matches

**Step 6: Document any issues**

Create GitHub issues for any bugs found.

---

## Task 11: Run Full Test Suite

**Files:**
- None (verification)

**Step 1: Run backend tests**

```bash
mix test
```

Expected: All tests pass

**Step 2: Run frontend tests**

```bash
npm test
```

Expected: All tests pass

**Step 3: Run linters**

```bash
mix format --check-formatted
mix credo
npm run lint
```

Expected: No errors

**Step 4: Verify TypeScript compilation**

```bash
npm run build
```

Expected: Successful build

---

## Task 12: Final Commit and Summary

**Step 1: Review all changes**

```bash
git log --oneline -15
```

**Step 2: Create feature summary**

Document in commit message or PR description:
- What was built
- How to use it
- What was tested

**Step 3: Push to remote (if applicable)**

```bash
git push origin <branch-name>
```

---

## Completion Checklist

- [ ] Seed script creates Nigerian states/LGAs (37 states, 774 LGAs)
- [ ] Generic `read_with_descendants` Ash action works
- [ ] Action exposed via AshTypescript RPC
- [ ] LocationCombobox component loads and displays data
- [ ] Client-side search filters correctly
- [ ] State-only selection works (no LGA)
- [ ] State+LGA selection works
- [ ] Logistics schema validates state as required, LGA as optional
- [ ] Location saves to `Item.attributes` as `_state` and `_lga`
- [ ] Edit flow loads existing location
- [ ] Preview page displays location with icon
- [ ] All tests pass (backend and frontend)
- [ ] Manual end-to-end testing completed
- [ ] Code reviewed and linted

---

## Future Tasks (Not in This Plan)

- Add location display to item cards in listing grids
- Add state/LGA filters to search page
- Add location-based search
- Add location analytics dashboard
- Integrate delivery cost estimation APIs

---

## Reference Documentation

- **Design Doc:** `docs/plans/2026-02-20-location-select-design.md`
- **Ash Usage Rules:** `docs/rules/ash_patterns.md`
- **React Best Practices:** @react-best-practices skill
- **TDD Workflow:** @superpowers:test-driven-development skill
- **shadcn/ui Combobox:** https://ui.shadcn.com/docs/components/combobox
