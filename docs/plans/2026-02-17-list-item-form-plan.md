# List Item Form Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a 4-step wizard form at `/items/new` that lets sellers create auction listings with category-specific fields, image upload, and a publish flow.

**Architecture:** Multi-step wizard using React Hook Form + Zod per step, with `useReducer` for cross-step state. Draft created after Step 1 (for image upload), remaining data accumulated client-side, finalized on Publish via `updateDraftItem` + `publishItem` RPC calls.

**Tech Stack:** Phoenix controllers (Inertia props), Ash typed queries, AshTypescript RPC, React 19, React Hook Form, Zod, shadcn/ui, TanStack Query, Lucide icons, Tailwind CSS.

**Design doc:** `docs/plans/2026-02-17-list-item-form-design.md`

**Figma file key:** `jk9qoWNcSpgUa8lsj7uXa9`

---

## Task 1: Backend — Add listing_form_category typed query + codegen

The `nav_category` typed query only loads `[:id, :name, :slug]` — it doesn't include `attributeSchema`. We need a new typed query that loads categories with their `attribute_schema` for the listing form's category picker.

**Files:**
- Modify: `lib/angle/catalog.ex:10-27`
- Regenerate: `assets/js/ash_rpc.ts`

**Step 1: Add the typed query**

In `lib/angle/catalog.ex`, add a new typed query inside the `resource Angle.Catalog.Category` block (after the existing `nav_category` query at line 25):

```elixir
typed_query :listing_form_category, :top_level do
  ts_result_type_name "ListingFormCategory"
  ts_fields_const_name "listingFormCategoryFields"
  fields [:id, :name, :slug, :attribute_schema, categories: [:id, :name, :slug, :attribute_schema]]
end
```

**Step 2: Run codegen**

```bash
mix ash_typescript.codegen
```

Verify that `assets/js/ash_rpc.ts` now contains `listingFormCategoryFields` and the `ListingFormCategory` type.

**Step 3: Commit**

```bash
git add lib/angle/catalog.ex assets/js/ash_rpc.ts
git commit -m "feat: add listing_form_category typed query with attributeSchema"
```

---

## Task 2: Backend — Update ItemsController.new to load props

The current `new/2` action renders a placeholder page with no props. We need to load categories and the user's store profile delivery preference.

**Files:**
- Modify: `lib/angle_web/controllers/items_controller.ex:9-11`

**Step 1: Update the new action**

Replace the `new/2` function (lines 9-11) with:

```elixir
def new(conn, _params) do
  categories = load_listing_form_categories(conn)
  store_profile = load_store_profile(conn)

  conn
  |> assign_prop(:categories, categories)
  |> assign_prop(:store_profile, store_profile)
  |> render_inertia("items/new")
end
```

**Step 2: Add the category loading helper**

Add this private function after the existing helpers in the controller:

```elixir
defp load_listing_form_categories(conn) do
  case AshTypescript.Rpc.run_typed_query(:angle, :listing_form_category, %{}, conn) do
    %{"success" => true, "data" => data} -> extract_results(data)
    _ -> []
  end
end
```

**Step 3: Add the store profile loading helper**

```elixir
defp load_store_profile(conn) do
  case conn.assigns[:current_user] do
    nil ->
      nil

    user ->
      case Angle.Accounts.StoreProfile
           |> Ash.Query.filter(user_id == ^user.id)
           |> Ash.read_one(authorize?: false) do
        {:ok, nil} -> nil
        {:ok, profile} -> %{
          "deliveryPreference" => profile.delivery_preference
        }
        _ -> nil
      end
  end
end
```

**Step 4: Run tests**

```bash
mix test test/angle_web/controllers/ --max-failures 3
```

**Step 5: Commit**

```bash
git add lib/angle_web/controllers/items_controller.ex
git commit -m "feat: load categories and store profile in items/new controller"
```

---

## Task 3: Backend — Seed category attribute_schema data

Categories need `attribute_schema` populated so the listing form can render category-specific fields. Create a seed script.

**Files:**
- Create: `priv/repo/seeds/category_schemas.exs`

**Step 1: Create the seed script**

```elixir
# priv/repo/seeds/category_schemas.exs
#
# Run: mix run priv/repo/seeds/category_schemas.exs
#
# Populates attribute_schema for existing categories.
# Safe to run multiple times (uses Ash update).

alias Angle.Catalog.Category

schemas = %{
  "Smartphones" => %{
    "fields" => [
      %{"name" => "Model", "type" => "string", "required" => true},
      %{"name" => "Storage", "type" => "string"},
      %{"name" => "Color", "type" => "string"},
      %{"name" => "Display", "type" => "string"},
      %{"name" => "Chip", "type" => "string"},
      %{"name" => "Camera", "type" => "string"},
      %{"name" => "Battery", "type" => "string"},
      %{"name" => "Connectivity", "type" => "string"}
    ]
  },
  "Tablets & iPads" => %{
    "fields" => [
      %{"name" => "Model", "type" => "string", "required" => true},
      %{"name" => "Storage", "type" => "string"},
      %{"name" => "Screen Size", "type" => "string"},
      %{"name" => "Connectivity", "type" => "string"}
    ]
  },
  "Laptops" => %{
    "fields" => [
      %{"name" => "Brand & Model", "type" => "string", "required" => true},
      %{"name" => "Processor", "type" => "string"},
      %{"name" => "RAM", "type" => "string"},
      %{"name" => "Storage", "type" => "string"},
      %{"name" => "Screen Size", "type" => "string"},
      %{"name" => "Graphics", "type" => "string"}
    ]
  },
  "Gaming Consoles & Accessories" => %{
    "fields" => [
      %{"name" => "Console/Accessory", "type" => "string", "required" => true},
      %{"name" => "Model", "type" => "string"},
      %{"name" => "Storage", "type" => "string"},
      %{"name" => "Included Accessories", "type" => "string"}
    ]
  },
  "Smartwatches & Wearables" => %{
    "fields" => [
      %{"name" => "Brand & Model", "type" => "string", "required" => true},
      %{"name" => "Display Type", "type" => "string"},
      %{"name" => "Battery Life", "type" => "string"},
      %{"name" => "Connectivity", "type" => "string"}
    ]
  },
  "Smart Home Devices" => %{
    "fields" => [
      %{"name" => "Device Type", "type" => "string", "required" => true},
      %{"name" => "Brand", "type" => "string"},
      %{"name" => "Connectivity", "type" => "string"}
    ]
  },
  "Traditional Clothing & Textiles" => %{
    "fields" => [
      %{"name" => "Type", "type" => "string", "required" => true},
      %{"name" => "Origin/Region", "type" => "string"},
      %{"name" => "Material", "type" => "string"},
      %{"name" => "Size", "type" => "string"}
    ]
  },
  "Handmade Crafts" => %{
    "fields" => [
      %{"name" => "Craft Type", "type" => "string", "required" => true},
      %{"name" => "Material", "type" => "string"},
      %{"name" => "Origin", "type" => "string"},
      %{"name" => "Dimensions", "type" => "string"}
    ]
  },
  "Televisions & Screens" => %{
    "fields" => [
      %{"name" => "Brand & Model", "type" => "string", "required" => true},
      %{"name" => "Screen Size", "type" => "string"},
      %{"name" => "Resolution", "type" => "string"},
      %{"name" => "Display Type", "type" => "string"}
    ]
  },
  "Vintage Coins & Currency" => %{
    "fields" => [
      %{"name" => "Type", "type" => "string", "required" => true},
      %{"name" => "Year/Period", "type" => "string"},
      %{"name" => "Country of Origin", "type" => "string"},
      %{"name" => "Grade/Condition", "type" => "string"}
    ]
  },
  "Refrigerators & Freezers" => %{
    "fields" => [
      %{"name" => "Brand & Model", "type" => "string", "required" => true},
      %{"name" => "Capacity", "type" => "string"},
      %{"name" => "Type", "type" => "string"},
      %{"name" => "Energy Rating", "type" => "string"}
    ]
  }
}

# Update categories that exist in the DB
for {name, schema} <- schemas do
  case Category
       |> Ash.Query.filter(name == ^name)
       |> Ash.read_one(authorize?: false) do
    {:ok, %Category{} = cat} ->
      cat
      |> Ash.Changeset.for_update(:update, %{attribute_schema: schema}, authorize?: false)
      |> Ash.update!()

      IO.puts("Updated attribute_schema for: #{name}")

    _ ->
      IO.puts("Category not found, skipping: #{name}")
  end
end

IO.puts("\nDone seeding category schemas.")
```

**Step 2: Run the seed**

```bash
mix run priv/repo/seeds/category_schemas.exs
```

**Step 3: Commit**

```bash
git add priv/repo/seeds/category_schemas.exs
git commit -m "feat: add category attribute_schema seed data for listing form"
```

---

## Task 4: Frontend — Listing wizard shell + Zod schemas + state management

Build the wizard page component, step progress indicator, form state reducer, and Zod schemas.

**Files:**
- Modify: `assets/js/pages/items/new.tsx` (replace placeholder)
- Create: `assets/js/features/listing-form/schemas/listing-form-schema.ts`
- Create: `assets/js/features/listing-form/components/listing-wizard.tsx`
- Create: `assets/js/features/listing-form/components/step-indicator.tsx`

**Step 1: Create Zod schemas**

Create `assets/js/features/listing-form/schemas/listing-form-schema.ts`:

```typescript
import { z } from "zod";

export const basicDetailsSchema = z.object({
  title: z.string().min(1, "Title is required").max(200),
  description: z.string().optional().default(""),
  categoryId: z.string().min(1, "Category is required"),
  subcategoryId: z.string().optional().default(""),
  condition: z.enum(["new", "used", "refurbished"]),
  attributes: z.record(z.string(), z.string()).default({}),
  customFeatures: z.array(z.string()).default([]),
});

export const auctionInfoSchema = z.object({
  startingPrice: z.string().min(1, "Starting price is required").refine(
    (val) => !isNaN(Number(val)) && Number(val) > 0,
    "Must be a positive number"
  ),
  reservePrice: z.string().optional().default(""),
  auctionDuration: z.enum(["24h", "3d", "7d"]),
});

export const logisticsSchema = z.object({
  deliveryPreference: z.enum(["meetup", "buyer_arranges", "seller_arranges"]),
});

export type BasicDetailsData = z.infer<typeof basicDetailsSchema>;
export type AuctionInfoData = z.infer<typeof auctionInfoSchema>;
export type LogisticsData = z.infer<typeof logisticsSchema>;

export type ListingFormState = {
  currentStep: 1 | 2 | 3 | 4;
  draftItemId: string | null;
  basicDetails: BasicDetailsData;
  auctionInfo: AuctionInfoData;
  logistics: LogisticsData;
  selectedImages: File[];
  uploadedImages: Array<{ id: string; position: number; variants: Record<string, string> }>;
  isSubmitting: boolean;
  isPublished: boolean;
};

export type ListingFormAction =
  | { type: "SET_STEP"; step: 1 | 2 | 3 | 4 }
  | { type: "SET_DRAFT_ID"; id: string }
  | { type: "SET_BASIC_DETAILS"; data: BasicDetailsData }
  | { type: "SET_AUCTION_INFO"; data: AuctionInfoData }
  | { type: "SET_LOGISTICS"; data: LogisticsData }
  | { type: "SET_SELECTED_IMAGES"; files: File[] }
  | { type: "SET_UPLOADED_IMAGES"; images: ListingFormState["uploadedImages"] }
  | { type: "SET_SUBMITTING"; value: boolean }
  | { type: "SET_PUBLISHED"; value: boolean };

export const initialFormState: ListingFormState = {
  currentStep: 1,
  draftItemId: null,
  basicDetails: {
    title: "",
    description: "",
    categoryId: "",
    subcategoryId: "",
    condition: "used",
    attributes: {},
    customFeatures: [],
  },
  auctionInfo: {
    startingPrice: "",
    reservePrice: "",
    auctionDuration: "7d",
  },
  logistics: {
    deliveryPreference: "buyer_arranges",
  },
  selectedImages: [],
  uploadedImages: [],
  isSubmitting: false,
  isPublished: false,
};

export function listingFormReducer(
  state: ListingFormState,
  action: ListingFormAction
): ListingFormState {
  switch (action.type) {
    case "SET_STEP":
      return { ...state, currentStep: action.step };
    case "SET_DRAFT_ID":
      return { ...state, draftItemId: action.id };
    case "SET_BASIC_DETAILS":
      return { ...state, basicDetails: action.data };
    case "SET_AUCTION_INFO":
      return { ...state, auctionInfo: action.data };
    case "SET_LOGISTICS":
      return { ...state, logistics: action.data };
    case "SET_SELECTED_IMAGES":
      return { ...state, selectedImages: action.files };
    case "SET_UPLOADED_IMAGES":
      return { ...state, uploadedImages: action.images };
    case "SET_SUBMITTING":
      return { ...state, isSubmitting: action.value };
    case "SET_PUBLISHED":
      return { ...state, isPublished: action.value };
    default:
      return state;
  }
}
```

**Step 2: Create the step indicator component**

Create `assets/js/features/listing-form/components/step-indicator.tsx`:

```tsx
import { Check } from "lucide-react";
import { cn } from "@/lib/utils";

const STEPS = [
  { number: 1, label: "Basic Details" },
  { number: 2, label: "Auction Info" },
  { number: 3, label: "Logistics" },
] as const;

interface StepIndicatorProps {
  currentStep: number;
}

export function StepIndicator({ currentStep }: StepIndicatorProps) {
  return (
    <>
      {/* Desktop: tab-style */}
      <div className="hidden md:flex items-center gap-1 border-b border-border">
        {STEPS.map((step) => {
          const isCompleted = currentStep > step.number;
          const isActive = currentStep === step.number || (currentStep === 4 && step.number === 3);
          return (
            <button
              key={step.number}
              type="button"
              disabled
              className={cn(
                "flex items-center gap-2 px-4 py-3 text-sm font-medium border-b-2 -mb-px transition-colors",
                isActive
                  ? "border-primary-600 text-primary-600"
                  : isCompleted
                    ? "border-transparent text-content-secondary"
                    : "border-transparent text-content-tertiary"
              )}
            >
              {isCompleted && <Check className="size-4 text-feedback-success" />}
              {step.label}
            </button>
          );
        })}
      </div>

      {/* Mobile: progress bar */}
      <div className="md:hidden">
        <div className="flex gap-1.5">
          {[1, 2, 3, 4].map((step) => (
            <div
              key={step}
              className={cn(
                "h-1 flex-1 rounded-full transition-colors",
                step <= currentStep ? "bg-primary-600" : "bg-surface-muted"
              )}
            />
          ))}
        </div>
      </div>
    </>
  );
}
```

**Step 3: Create the listing wizard orchestrator**

Create `assets/js/features/listing-form/components/listing-wizard.tsx`:

```tsx
import { useReducer, useCallback } from "react";
import { ArrowLeft } from "lucide-react";
import { StepIndicator } from "./step-indicator";
import { BasicDetailsStep } from "./basic-details-step";
import { AuctionInfoStep } from "./auction-info-step";
import { LogisticsStep } from "./logistics-step";
import { PreviewStep } from "./preview-step";
import { SuccessModal } from "./success-modal";
import {
  listingFormReducer,
  initialFormState,
  type ListingFormState,
  type BasicDetailsData,
  type AuctionInfoData,
  type LogisticsData,
} from "../schemas/listing-form-schema";

interface CategoryField {
  name: string;
  type: string;
  required?: boolean;
}

interface Subcategory {
  id: string;
  name: string;
  slug: string | null;
  attributeSchema: { fields?: CategoryField[] } | Record<string, never>;
}

export interface Category {
  id: string;
  name: string;
  slug: string | null;
  attributeSchema: { fields?: CategoryField[] } | Record<string, never>;
  categories: Subcategory[];
}

interface ListingWizardProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
}

export function ListingWizard({ categories, storeProfile }: ListingWizardProps) {
  const defaultDelivery = mapDeliveryPreference(storeProfile?.deliveryPreference);

  const [state, dispatch] = useReducer(listingFormReducer, {
    ...initialFormState,
    logistics: { deliveryPreference: defaultDelivery },
  });

  const goToStep = useCallback((step: ListingFormState["currentStep"]) => {
    dispatch({ type: "SET_STEP", step });
  }, []);

  const handleBasicDetailsNext = useCallback((data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => {
    dispatch({ type: "SET_BASIC_DETAILS", data });
    dispatch({ type: "SET_DRAFT_ID", id: draftId });
    dispatch({ type: "SET_UPLOADED_IMAGES", images: uploadedImages });
    dispatch({ type: "SET_STEP", step: 2 });
  }, []);

  const handleAuctionInfoNext = useCallback((data: AuctionInfoData) => {
    dispatch({ type: "SET_AUCTION_INFO", data });
    dispatch({ type: "SET_STEP", step: 3 });
  }, []);

  const handleLogisticsNext = useCallback((data: LogisticsData) => {
    dispatch({ type: "SET_LOGISTICS", data });
    dispatch({ type: "SET_STEP", step: 4 });
  }, []);

  const handlePublished = useCallback(() => {
    dispatch({ type: "SET_PUBLISHED", value: true });
  }, []);

  const handleBack = useCallback(() => {
    if (state.currentStep > 1) {
      dispatch({ type: "SET_STEP", step: (state.currentStep - 1) as ListingFormState["currentStep"] });
    }
  }, [state.currentStep]);

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        {state.currentStep > 1 && state.currentStep < 4 && (
          <button
            type="button"
            onClick={handleBack}
            className="mb-2 flex items-center gap-1 text-sm text-content-secondary hover:text-content"
          >
            <ArrowLeft className="size-4" />
            Back
          </button>
        )}
        <h1 className="text-xl font-bold text-content">
          {state.currentStep === 4 ? "Preview Listing" : "List An Item"}
        </h1>
        <p className="mt-1 text-sm text-content-tertiary">
          {state.currentStep === 4
            ? "Make sure everything looks good before you publish."
            : "Turn your item into cash by creating a quick listing"}
        </p>
      </div>

      {/* Step indicator */}
      <StepIndicator currentStep={state.currentStep} />

      {/* Step content */}
      {state.currentStep === 1 && (
        <BasicDetailsStep
          categories={categories}
          defaultValues={state.basicDetails}
          defaultImages={state.selectedImages}
          draftItemId={state.draftItemId}
          uploadedImages={state.uploadedImages}
          onNext={handleBasicDetailsNext}
        />
      )}
      {state.currentStep === 2 && (
        <AuctionInfoStep
          defaultValues={state.auctionInfo}
          onNext={handleAuctionInfoNext}
          onBack={handleBack}
        />
      )}
      {state.currentStep === 3 && (
        <LogisticsStep
          defaultValues={state.logistics}
          onNext={handleLogisticsNext}
          onBack={handleBack}
        />
      )}
      {state.currentStep === 4 && (
        <PreviewStep
          state={state}
          categories={categories}
          onEdit={goToStep}
          onPublished={handlePublished}
        />
      )}

      {/* Success modal */}
      <SuccessModal
        open={state.isPublished}
        itemId={state.draftItemId}
      />
    </div>
  );
}

function mapDeliveryPreference(pref: string | null | undefined): "meetup" | "buyer_arranges" | "seller_arranges" {
  switch (pref) {
    case "pickup_only": return "meetup";
    case "seller_delivers": return "seller_arranges";
    case "you_arrange":
    default: return "buyer_arranges";
  }
}
```

**Step 4: Update the page**

Replace `assets/js/pages/items/new.tsx`:

```tsx
import { Head } from "@inertiajs/react";
import { ListingWizard, type Category } from "@/features/listing-form/components/listing-wizard";

interface NewItemPageProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
}

export default function NewItem({ categories, storeProfile }: NewItemPageProps) {
  return (
    <>
      <Head title="List An Item" />
      <div className="mx-auto max-w-2xl px-4 py-6 lg:max-w-3xl">
        <ListingWizard categories={categories} storeProfile={storeProfile} />
      </div>
    </>
  );
}
```

**Step 5: Build assets to verify compilation**

```bash
mix assets.build
```

This will fail because the step components don't exist yet — that's OK. Create minimal stubs for each:

`assets/js/features/listing-form/components/basic-details-step.tsx`:
```tsx
export function BasicDetailsStep(_props: any) {
  return <div>Step 1: Basic Details (TODO)</div>;
}
```

(Same pattern for `auction-info-step.tsx`, `logistics-step.tsx`, `preview-step.tsx`, `success-modal.tsx`)

**Step 6: Build again and verify**

```bash
mix assets.build
```

Expected: Compiles successfully.

**Step 7: Commit**

```bash
git add assets/js/pages/items/new.tsx assets/js/features/listing-form/
git commit -m "feat: add listing wizard shell with state management and step indicator"
```

---

## Task 5: Frontend — Category picker modal

The most complex UI component. A hierarchical modal that shows top-level categories, lets users navigate into subcategories, and supports search.

**Files:**
- Create: `assets/js/features/listing-form/components/category-picker.tsx`

**Step 1: Implement the category picker**

Create `assets/js/features/listing-form/components/category-picker.tsx`:

```tsx
import { useState, useMemo } from "react";
import { ArrowLeft, ChevronRight, Check, Search } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { cn } from "@/lib/utils";
import type { Category } from "./listing-wizard";

interface CategoryPickerProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  categories: Category[];
  selectedCategoryId: string;
  selectedSubcategoryId: string;
  onSelect: (categoryId: string, subcategoryId: string, categoryName: string) => void;
}

export function CategoryPicker({
  open,
  onOpenChange,
  categories,
  selectedCategoryId,
  selectedSubcategoryId,
  onSelect,
}: CategoryPickerProps) {
  const [activeParent, setActiveParent] = useState<Category | null>(null);
  const [searchQuery, setSearchQuery] = useState("");

  // Flat list of all subcategories for search
  const allSubcategories = useMemo(() => {
    return categories.flatMap((cat) =>
      cat.categories.map((sub) => ({
        ...sub,
        parentId: cat.id,
        parentName: cat.name,
      }))
    );
  }, [categories]);

  const filteredSubcategories = useMemo(() => {
    if (!searchQuery.trim()) return [];
    const q = searchQuery.toLowerCase();
    return allSubcategories.filter(
      (sub) =>
        sub.name.toLowerCase().includes(q) ||
        sub.parentName.toLowerCase().includes(q)
    );
  }, [allSubcategories, searchQuery]);

  const handleSelectSubcategory = (parentId: string, subId: string, name: string) => {
    onSelect(parentId, subId, name);
    onOpenChange(false);
    setActiveParent(null);
    setSearchQuery("");
  };

  const handleClose = () => {
    onOpenChange(false);
    setActiveParent(null);
    setSearchQuery("");
  };

  const isSearching = searchQuery.trim().length > 0;

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="max-h-[80vh] overflow-hidden p-0 sm:max-w-md">
        <DialogHeader className="border-b px-4 py-3">
          <div className="flex items-center gap-2">
            {activeParent && !isSearching && (
              <button
                type="button"
                onClick={() => setActiveParent(null)}
                className="text-content-secondary hover:text-content"
              >
                <ArrowLeft className="size-5" />
              </button>
            )}
            <DialogTitle className="text-base">
              {activeParent && !isSearching ? activeParent.name : "Select Category"}
            </DialogTitle>
          </div>
        </DialogHeader>

        {/* Search */}
        <div className="border-b px-4 py-2">
          <div className="relative">
            <Search className="absolute left-3 top-1/2 size-4 -translate-y-1/2 text-content-tertiary" />
            <Input
              placeholder="Search category"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>
        </div>

        {/* Category list */}
        <div className="max-h-[50vh] overflow-y-auto">
          {isSearching ? (
            // Search results
            filteredSubcategories.length === 0 ? (
              <p className="p-4 text-center text-sm text-content-tertiary">
                No categories found
              </p>
            ) : (
              filteredSubcategories.map((sub) => (
                <button
                  key={sub.id}
                  type="button"
                  onClick={() => handleSelectSubcategory(sub.parentId, sub.id, sub.name)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
                >
                  <div>
                    <span className="text-content">{sub.name}</span>
                    <span className="ml-2 text-xs text-content-tertiary">
                      in {sub.parentName}
                    </span>
                  </div>
                  {sub.id === selectedSubcategoryId && (
                    <Check className="size-4 text-primary-600" />
                  )}
                </button>
              ))
            )
          ) : activeParent ? (
            // Subcategories
            activeParent.categories.length === 0 ? (
              <p className="p-4 text-center text-sm text-content-tertiary">
                No subcategories
              </p>
            ) : (
              activeParent.categories.map((sub) => (
                <button
                  key={sub.id}
                  type="button"
                  onClick={() => handleSelectSubcategory(activeParent.id, sub.id, sub.name)}
                  className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
                >
                  <span className="text-content">{sub.name}</span>
                  {sub.id === selectedSubcategoryId && (
                    <Check className="size-4 text-primary-600" />
                  )}
                </button>
              ))
            )
          ) : (
            // Top-level categories
            categories.map((cat) => (
              <button
                key={cat.id}
                type="button"
                onClick={() => {
                  if (cat.categories.length > 0) {
                    setActiveParent(cat);
                  } else {
                    handleSelectSubcategory(cat.id, "", cat.name);
                  }
                }}
                className="flex w-full items-center justify-between px-4 py-3 text-left text-sm hover:bg-surface-secondary"
              >
                <span className="text-content">{cat.name}</span>
                {cat.categories.length > 0 ? (
                  <ChevronRight className="size-4 text-content-tertiary" />
                ) : cat.id === selectedCategoryId ? (
                  <Check className="size-4 text-primary-600" />
                ) : null}
              </button>
            ))
          )}
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

**Step 2: Verify build**

```bash
mix assets.build
```

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/category-picker.tsx
git commit -m "feat: add hierarchical category picker modal with search"
```

---

## Task 6: Frontend — Basic Details step (Step 1)

The largest form step: title, description, category picker, dynamic category fields, custom features, condition, and photo selection.

**Files:**
- Create: `assets/js/features/listing-form/components/basic-details-step.tsx`
- Create: `assets/js/features/listing-form/components/category-fields.tsx`
- Create: `assets/js/features/listing-form/components/feature-fields.tsx`

**Step 1: Create the category fields renderer**

Create `assets/js/features/listing-form/components/category-fields.tsx`:

```tsx
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

interface CategoryField {
  name: string;
  type: string;
  required?: boolean;
}

interface CategoryFieldsProps {
  fields: CategoryField[];
  values: Record<string, string>;
  onChange: (key: string, value: string) => void;
}

export function CategoryFields({ fields, values, onChange }: CategoryFieldsProps) {
  if (fields.length === 0) return null;

  return (
    <div className="space-y-4">
      <Label className="text-sm font-medium">Category Details</Label>
      <div className="grid gap-3 sm:grid-cols-2">
        {fields.map((field) => (
          <div key={field.name} className="space-y-1.5">
            <Label htmlFor={`attr-${field.name}`} className="text-xs text-content-secondary">
              {field.name}
              {field.required && <span className="text-feedback-error"> *</span>}
            </Label>
            <Input
              id={`attr-${field.name}`}
              placeholder={`Enter ${field.name.toLowerCase()}`}
              value={values[field.name] || ""}
              onChange={(e) => onChange(field.name, e.target.value)}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
```

**Step 2: Create the custom feature fields**

Create `assets/js/features/listing-form/components/feature-fields.tsx`:

```tsx
import { Plus, X } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

interface FeatureFieldsProps {
  features: string[];
  onChange: (features: string[]) => void;
}

export function FeatureFields({ features, onChange }: FeatureFieldsProps) {
  const addFeature = () => {
    onChange([...features, ""]);
  };

  const removeFeature = (index: number) => {
    onChange(features.filter((_, i) => i !== index));
  };

  const updateFeature = (index: number, value: string) => {
    const updated = [...features];
    updated[index] = value;
    onChange(updated);
  };

  return (
    <div className="space-y-3">
      <Label className="text-sm font-medium">Additional Features</Label>
      {features.map((feature, index) => (
        <div key={index} className="flex items-center gap-2">
          <Input
            placeholder="e.g., Comes with original box"
            value={feature}
            onChange={(e) => updateFeature(index, e.target.value)}
          />
          <button
            type="button"
            onClick={() => removeFeature(index)}
            className="shrink-0 text-content-tertiary hover:text-feedback-error"
          >
            <X className="size-4" />
          </button>
        </div>
      ))}
      <Button
        type="button"
        variant="outline"
        size="sm"
        onClick={addFeature}
        className="gap-1.5"
      >
        <Plus className="size-3.5" />
        Add Feature
      </Button>
    </div>
  );
}
```

**Step 3: Create the Basic Details step**

Create `assets/js/features/listing-form/components/basic-details-step.tsx`:

```tsx
import { useState, useMemo, useCallback } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { ChevronDown, Upload } from "lucide-react";
import { toast } from "sonner";
import { createDraftItem, buildCSRFHeaders } from "@/ash_rpc";
import { getPhoenixCSRFToken } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { CategoryPicker } from "./category-picker";
import { CategoryFields } from "./category-fields";
import { FeatureFields } from "./feature-fields";
import {
  basicDetailsSchema,
  type BasicDetailsData,
  type ListingFormState,
} from "../schemas/listing-form-schema";
import type { Category } from "./listing-wizard";

interface BasicDetailsStepProps {
  categories: Category[];
  defaultValues: BasicDetailsData;
  defaultImages: File[];
  draftItemId: string | null;
  uploadedImages: ListingFormState["uploadedImages"];
  onNext: (data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => void;
}

export function BasicDetailsStep({
  categories,
  defaultValues,
  defaultImages,
  draftItemId,
  uploadedImages: existingUploaded,
  onNext,
}: BasicDetailsStepProps) {
  const [pickerOpen, setPickerOpen] = useState(false);
  const [categoryName, setCategoryName] = useState(() => {
    if (defaultValues.subcategoryId || defaultValues.categoryId) {
      return findCategoryName(categories, defaultValues.categoryId, defaultValues.subcategoryId);
    }
    return "";
  });
  const [attributes, setAttributes] = useState<Record<string, string>>(defaultValues.attributes);
  const [customFeatures, setCustomFeatures] = useState<string[]>(defaultValues.customFeatures);
  const [selectedImages, setSelectedImages] = useState<File[]>(defaultImages);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const {
    register,
    handleSubmit,
    control,
    setValue,
    watch,
    formState: { errors },
  } = useForm<BasicDetailsData>({
    resolver: zodResolver(basicDetailsSchema),
    defaultValues,
  });

  const watchCategoryId = watch("categoryId");
  const watchSubcategoryId = watch("subcategoryId");

  // Get the selected (sub)category's attributeSchema fields
  const categoryFields = useMemo(() => {
    const subcatId = watchSubcategoryId;
    const catId = watchCategoryId;
    if (!catId) return [];

    for (const cat of categories) {
      if (cat.id === catId && !subcatId) {
        return cat.attributeSchema?.fields || [];
      }
      for (const sub of cat.categories) {
        if (sub.id === subcatId) {
          return sub.attributeSchema?.fields || [];
        }
      }
    }
    return [];
  }, [categories, watchCategoryId, watchSubcategoryId]);

  const handleCategorySelect = useCallback(
    (parentId: string, subId: string, name: string) => {
      setValue("categoryId", subId || parentId, { shouldValidate: true });
      setValue("subcategoryId", subId);
      setCategoryName(name);
      setAttributes({});
    },
    [setValue]
  );

  const handleImageSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    const total = selectedImages.length + existingUploaded.length + files.length;
    if (total > 10) {
      toast.error("Maximum 10 images allowed");
      return;
    }
    setSelectedImages((prev) => [...prev, ...files]);
  }, [selectedImages, existingUploaded]);

  const removeSelectedImage = useCallback((index: number) => {
    setSelectedImages((prev) => prev.filter((_, i) => i !== index));
  }, []);

  const onSubmit = async (data: BasicDetailsData) => {
    setIsSubmitting(true);

    try {
      // Merge attributes + custom features
      const mergedAttributes = { ...attributes };
      const nonEmptyFeatures = customFeatures.filter((f) => f.trim());
      if (nonEmptyFeatures.length > 0) {
        mergedAttributes._customFeatures = nonEmptyFeatures.join("|||");
      }

      const submitData = { ...data, attributes: mergedAttributes, customFeatures: nonEmptyFeatures };

      let itemId = draftItemId;
      let currentUploaded = existingUploaded;

      if (!itemId) {
        // Create the draft
        const result = await createDraftItem({
          input: {
            title: data.title,
            description: data.description || undefined,
            startingPrice: "1", // Placeholder, will be updated in Step 4
            categoryId: data.categoryId || undefined,
            condition: data.condition,
            attributes: mergedAttributes,
          },
          fields: ["id"],
          headers: buildCSRFHeaders(),
        });

        if (!result.success) {
          throw new Error(result.errors.map((e) => e.message).join("; "));
        }

        itemId = result.data.id;
      }

      // Upload images
      if (selectedImages.length > 0) {
        const newUploaded = await uploadImages(itemId, selectedImages);
        currentUploaded = [...existingUploaded, ...newUploaded];
      }

      onNext(submitData, itemId, currentUploaded);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save draft");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      {/* Title */}
      <div className="space-y-1.5">
        <Label htmlFor="title">Item Title</Label>
        <Input
          id="title"
          placeholder="e.g., Apple iPhone 13 Pro, 128GB, Blue"
          {...register("title")}
        />
        {errors.title && (
          <p className="text-xs text-feedback-error">{errors.title.message}</p>
        )}
      </div>

      {/* Description */}
      <div className="space-y-1.5">
        <Label htmlFor="description">Description</Label>
        <Textarea
          id="description"
          placeholder="Describe your item in detail..."
          rows={4}
          {...register("description")}
        />
      </div>

      {/* Category picker */}
      <div className="space-y-1.5">
        <Label>Item Category</Label>
        <button
          type="button"
          onClick={() => setPickerOpen(true)}
          className="flex w-full items-center justify-between rounded-md border border-input bg-surface px-3 py-2 text-sm ring-offset-background focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
        >
          <span className={categoryName ? "text-content" : "text-content-tertiary"}>
            {categoryName || "Select a category"}
          </span>
          <ChevronDown className="size-4 text-content-tertiary" />
        </button>
        {errors.categoryId && (
          <p className="text-xs text-feedback-error">{errors.categoryId.message}</p>
        )}
        <CategoryPicker
          open={pickerOpen}
          onOpenChange={setPickerOpen}
          categories={categories}
          selectedCategoryId={watchCategoryId}
          selectedSubcategoryId={watchSubcategoryId || ""}
          onSelect={handleCategorySelect}
        />
      </div>

      {/* Category-specific fields */}
      {categoryFields.length > 0 && (
        <CategoryFields
          fields={categoryFields}
          values={attributes}
          onChange={(key, value) =>
            setAttributes((prev) => ({ ...prev, [key]: value }))
          }
        />
      )}

      {/* Custom features */}
      <FeatureFields features={customFeatures} onChange={setCustomFeatures} />

      {/* Condition */}
      <div className="space-y-1.5">
        <Label>Item Condition</Label>
        <Controller
          name="condition"
          control={control}
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue placeholder="Select condition" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="new">New</SelectItem>
                <SelectItem value="used">Fairly Used</SelectItem>
                <SelectItem value="refurbished">Refurbished</SelectItem>
              </SelectContent>
            </Select>
          )}
        />
      </div>

      {/* Photo upload */}
      <div className="space-y-3">
        <Label>Photos</Label>

        {/* Preview existing uploaded images */}
        {existingUploaded.length > 0 && (
          <div className="grid grid-cols-4 gap-2">
            {existingUploaded.map((img) => (
              <div key={img.id} className="aspect-square overflow-hidden rounded-md bg-surface-muted">
                <img
                  src={img.variants.thumbnail || img.variants.original}
                  alt=""
                  className="size-full object-cover"
                />
              </div>
            ))}
          </div>
        )}

        {/* Preview selected files */}
        {selectedImages.length > 0 && (
          <div className="grid grid-cols-4 gap-2">
            {selectedImages.map((file, idx) => (
              <div key={idx} className="group relative aspect-square overflow-hidden rounded-md bg-surface-muted">
                <img
                  src={URL.createObjectURL(file)}
                  alt=""
                  className="size-full object-cover"
                />
                <button
                  type="button"
                  onClick={() => removeSelectedImage(idx)}
                  className="absolute right-1 top-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100"
                >
                  ×
                </button>
              </div>
            ))}
          </div>
        )}

        {/* Upload area */}
        {existingUploaded.length + selectedImages.length < 10 && (
          <label className="flex cursor-pointer flex-col items-center gap-2 rounded-lg border-2 border-dashed border-border p-6 text-center transition-colors hover:border-primary-600/50 hover:bg-surface-secondary">
            <Upload className="size-8 text-content-tertiary" />
            <div>
              <span className="text-sm font-medium text-primary-600">Click to upload</span>
              <span className="text-sm text-content-tertiary"> or drag and drop</span>
            </div>
            <span className="text-xs text-content-tertiary">PNG, JPG up to 10MB</span>
            <input
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={handleImageSelect}
            />
          </label>
        )}
      </div>

      {/* Next button */}
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Next"}
      </Button>
    </form>
  );
}

async function uploadImages(itemId: string, files: File[]) {
  const csrfToken = getPhoenixCSRFToken();
  const uploaded: Array<{ id: string; position: number; variants: Record<string, string> }> = [];

  for (let i = 0; i < files.length; i++) {
    const formData = new FormData();
    formData.append("file", files[i]);
    formData.append("owner_type", "item");
    formData.append("owner_id", itemId);

    const res = await fetch("/uploads", {
      method: "POST",
      headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
      body: formData,
    });

    if (res.ok) {
      const data = await res.json();
      uploaded.push({
        id: data.image.id,
        position: data.image.position,
        variants: data.image.variants,
      });
    }
  }

  return uploaded;
}

function findCategoryName(categories: Category[], catId: string, subId: string): string {
  for (const cat of categories) {
    if (subId) {
      const sub = cat.categories.find((s) => s.id === subId);
      if (sub) return sub.name;
    }
    if (cat.id === catId) return cat.name;
  }
  return "";
}
```

**Step 4: Build and verify**

```bash
mix assets.build
```

**Step 5: Commit**

```bash
git add assets/js/features/listing-form/components/basic-details-step.tsx assets/js/features/listing-form/components/category-fields.tsx assets/js/features/listing-form/components/feature-fields.tsx
git commit -m "feat: add Basic Details step with category picker and dynamic fields"
```

---

## Task 7: Frontend — Auction Info step (Step 2)

Starting price, reserve price, and auction duration dropdown.

**Files:**
- Replace stub: `assets/js/features/listing-form/components/auction-info-step.tsx`

**Step 1: Implement the Auction Info step**

```tsx
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Info } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { auctionInfoSchema, type AuctionInfoData } from "../schemas/listing-form-schema";

interface AuctionInfoStepProps {
  defaultValues: AuctionInfoData;
  onNext: (data: AuctionInfoData) => void;
  onBack: () => void;
}

export function AuctionInfoStep({ defaultValues, onNext, onBack }: AuctionInfoStepProps) {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<AuctionInfoData>({
    resolver: zodResolver(auctionInfoSchema),
    defaultValues,
  });

  return (
    <form onSubmit={handleSubmit(onNext)} className="space-y-5">
      {/* Auction Duration */}
      <div className="space-y-1.5">
        <div className="flex items-center gap-1.5">
          <Label>Auction Duration</Label>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Info className="size-3.5 text-content-tertiary" />
              </TooltipTrigger>
              <TooltipContent>
                <p>Choose how long your auction will run.</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
        <Controller
          name="auctionDuration"
          control={control}
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue placeholder="Select duration" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="24h">24 hours</SelectItem>
                <SelectItem value="3d">3 days</SelectItem>
                <SelectItem value="7d">7 days</SelectItem>
              </SelectContent>
            </Select>
          )}
        />
      </div>

      {/* Starting Price */}
      <div className="space-y-1.5">
        <Label htmlFor="startingPrice">Starting Price</Label>
        <div className="flex">
          <span className="flex items-center rounded-l-md border border-r-0 border-input bg-surface-muted px-3 text-sm text-content-tertiary">
            ₦
          </span>
          <Input
            id="startingPrice"
            placeholder="0.00"
            className="rounded-l-none"
            {...register("startingPrice")}
          />
        </div>
        <p className="text-xs text-content-tertiary">
          This is the minimum amount buyers can bid
        </p>
        {errors.startingPrice && (
          <p className="text-xs text-feedback-error">{errors.startingPrice.message}</p>
        )}
      </div>

      {/* Reserve Price */}
      <div className="space-y-1.5">
        <Label htmlFor="reservePrice">Reserve Price (Optional)</Label>
        <div className="flex">
          <span className="flex items-center rounded-l-md border border-r-0 border-input bg-surface-muted px-3 text-sm text-content-tertiary">
            ₦
          </span>
          <Input
            id="reservePrice"
            placeholder="0.00"
            className="rounded-l-none"
            {...register("reservePrice")}
          />
        </div>
        <p className="text-xs text-content-tertiary">
          Only you will see this. Item won't sell unless bids meet this amount.
        </p>
        {errors.reservePrice && (
          <p className="text-xs text-feedback-error">{errors.reservePrice.message}</p>
        )}
      </div>

      {/* Buttons */}
      <Button
        type="submit"
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        Next
      </Button>
    </form>
  );
}
```

**Step 2: Build and verify**

```bash
mix assets.build
```

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/auction-info-step.tsx
git commit -m "feat: add Auction Info step with price inputs and duration"
```

---

## Task 8: Frontend — Logistics step (Step 3)

Radio buttons pre-filled from store profile. On change, updates store profile via RPC.

**Files:**
- Replace stub: `assets/js/features/listing-form/components/logistics-step.tsx`

**Step 1: Implement the Logistics step**

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { logisticsSchema, type LogisticsData } from "../schemas/listing-form-schema";

const DELIVERY_OPTIONS = [
  { value: "meetup", label: "Meet-up in person" },
  { value: "buyer_arranges", label: "Buyer arranges delivery" },
  { value: "seller_arranges", label: "Seller (you) arranges delivery" },
] as const;

interface LogisticsStepProps {
  defaultValues: LogisticsData;
  onNext: (data: LogisticsData) => void;
  onBack: () => void;
}

export function LogisticsStep({ defaultValues, onNext }: LogisticsStepProps) {
  const {
    handleSubmit,
    watch,
    setValue,
  } = useForm<LogisticsData>({
    resolver: zodResolver(logisticsSchema),
    defaultValues,
  });

  const selected = watch("deliveryPreference");

  return (
    <form onSubmit={handleSubmit(onNext)} className="space-y-6">
      <div className="space-y-3">
        <Label className="text-base font-medium">How will buyers get the item?</Label>
        <div className="space-y-2">
          {DELIVERY_OPTIONS.map((opt) => (
            <label
              key={opt.value}
              className={cn(
                "flex cursor-pointer items-center gap-3 rounded-lg border px-4 py-3 transition-colors",
                selected === opt.value
                  ? "border-primary-600 bg-primary-600/5"
                  : "border-border hover:bg-surface-secondary"
              )}
            >
              <div
                className={cn(
                  "flex size-5 items-center justify-center rounded-full border-2",
                  selected === opt.value
                    ? "border-primary-600"
                    : "border-content-tertiary"
                )}
              >
                {selected === opt.value && (
                  <div className="size-2.5 rounded-full bg-primary-600" />
                )}
              </div>
              <input
                type="radio"
                name="deliveryPreference"
                value={opt.value}
                checked={selected === opt.value}
                onChange={() => setValue("deliveryPreference", opt.value)}
                className="hidden"
              />
              <span className="text-sm font-medium text-content">{opt.label}</span>
            </label>
          ))}
        </div>
      </div>

      <Button
        type="submit"
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        Preview
      </Button>
    </form>
  );
}
```

**Step 2: Build and verify**

```bash
mix assets.build
```

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/logistics-step.tsx
git commit -m "feat: add Logistics step with delivery preference radio buttons"
```

---

## Task 9: Frontend — Preview step (Step 4) + Publish flow

Read-only preview of all item data with edit links. Publish button triggers `updateDraftItem` + `publishItem`.

**Files:**
- Replace stub: `assets/js/features/listing-form/components/preview-step.tsx`

**Step 1: Implement the Preview step**

```tsx
import { useState } from "react";
import { Pencil } from "lucide-react";
import { toast } from "sonner";
import { updateDraftItem, publishItem, buildCSRFHeaders } from "@/ash_rpc";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { ConditionBadge } from "@/features/items/components/condition-badge";
import type { ListingFormState } from "../schemas/listing-form-schema";
import type { Category } from "./listing-wizard";

const DURATION_MAP: Record<string, { label: string; ms: number }> = {
  "24h": { label: "24h 0m", ms: 24 * 60 * 60 * 1000 },
  "3d": { label: "3 d 0h 0m", ms: 3 * 24 * 60 * 60 * 1000 },
  "7d": { label: "7 d 0h 0m", ms: 7 * 24 * 60 * 60 * 1000 },
};

const DELIVERY_LABELS: Record<string, string> = {
  meetup: "Meet-up in person",
  buyer_arranges: "Buyer arranges delivery",
  seller_arranges: "Seller arranges delivery",
};

interface PreviewStepProps {
  state: ListingFormState;
  categories: Category[];
  onEdit: (step: 1 | 2 | 3 | 4) => void;
  onPublished: () => void;
}

export function PreviewStep({ state, categories, onEdit, onPublished }: PreviewStepProps) {
  const [isPublishing, setIsPublishing] = useState(false);

  const { basicDetails, auctionInfo, logistics, uploadedImages, draftItemId } = state;
  const duration = DURATION_MAP[auctionInfo.auctionDuration] || DURATION_MAP["7d"];
  const coverImage = uploadedImages[0];

  // Build display features
  const categoryFeatures = Object.entries(basicDetails.attributes)
    .filter(([key]) => key !== "_customFeatures")
    .map(([key, val]) => `${key}: ${val}`)
    .filter(([, val]) => val);

  const customFeatures = basicDetails.customFeatures.filter((f) => f.trim());
  const allFeatures = [...categoryFeatures, ...customFeatures];

  const handlePublish = async () => {
    if (!draftItemId) return;
    setIsPublishing(true);

    try {
      const now = new Date();
      const endTime = new Date(now.getTime() + duration.ms);

      // Update the draft with final auction info
      const updateResult = await updateDraftItem({
        identity: draftItemId,
        input: {
          id: draftItemId,
          startingPrice: auctionInfo.startingPrice,
          reservePrice: auctionInfo.reservePrice || undefined,
          startTime: now.toISOString(),
          endTime: endTime.toISOString(),
          attributes: basicDetails.attributes,
        },
        headers: buildCSRFHeaders(),
      });

      if (!updateResult.success) {
        throw new Error(updateResult.errors.map((e) => e.message).join("; "));
      }

      // Publish the item
      const publishResult = await publishItem({
        identity: draftItemId,
        headers: buildCSRFHeaders(),
      });

      if (!publishResult.success) {
        throw new Error(publishResult.errors.map((e) => e.message).join("; "));
      }

      // Update store profile delivery preference if needed
      // (deferred — store profile update is optional)

      onPublished();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to publish");
    } finally {
      setIsPublishing(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Cover image */}
      {coverImage && (
        <div className="aspect-video overflow-hidden rounded-lg bg-surface-muted">
          <img
            src={coverImage.variants.medium || coverImage.variants.original}
            alt={basicDetails.title}
            className="size-full object-contain"
          />
        </div>
      )}

      {/* Title + condition */}
      <div className="flex items-start justify-between gap-3">
        <div>
          <h2 className="text-lg font-bold text-content">{basicDetails.title}</h2>
          <ConditionBadge condition={basicDetails.condition} />
        </div>
      </div>

      {/* Price & duration */}
      <div className="flex items-center gap-4 text-sm">
        <span className="text-lg font-bold text-content">
          ₦{Number(auctionInfo.startingPrice).toLocaleString()}
        </span>
        <span className="text-content-tertiary">{duration.label}</span>
        <span className="text-content-tertiary">0 bids</span>
      </div>

      {/* Description */}
      <Section title="Product Description" onEdit={() => onEdit(1)}>
        <p className="text-sm text-content-secondary whitespace-pre-line">
          {basicDetails.description || "No description provided."}
        </p>
      </Section>

      {/* Features */}
      {allFeatures.length > 0 && (
        <Section title="Key Features" onEdit={() => onEdit(1)}>
          <ul className="list-inside list-disc space-y-1 text-sm text-content-secondary">
            {allFeatures.map((f, i) => (
              <li key={i}>{f}</li>
            ))}
          </ul>
        </Section>
      )}

      {/* Logistics */}
      <Section title="Logistics" onEdit={() => onEdit(3)}>
        <p className="text-sm text-content-secondary">
          {DELIVERY_LABELS[logistics.deliveryPreference]}
        </p>
      </Section>

      {/* Publish button */}
      <Button
        onClick={handlePublish}
        disabled={isPublishing}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isPublishing ? "Publishing..." : "Publish"}
      </Button>
    </div>
  );
}

function Section({
  title,
  onEdit,
  children,
}: {
  title: string;
  onEdit: () => void;
  children: React.ReactNode;
}) {
  return (
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-semibold text-content">{title}</h3>
        <button
          type="button"
          onClick={onEdit}
          className="flex items-center gap-1 text-xs font-medium text-primary-600 hover:text-primary-700"
        >
          <Pencil className="size-3" />
          Edit
        </button>
      </div>
      {children}
    </div>
  );
}
```

**Step 2: Build and verify**

```bash
mix assets.build
```

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/preview-step.tsx
git commit -m "feat: add Preview step with publish flow"
```

---

## Task 10: Frontend — Success modal with confetti

The celebration modal shown after successful publish.

**Files:**
- Replace stub: `assets/js/features/listing-form/components/success-modal.tsx`

**Step 1: Install confetti library** (optional — use CSS animation instead)

No external dependency needed. Use a simple CSS burst animation.

**Step 2: Implement the success modal**

```tsx
import { router } from "@inertiajs/react";
import { CheckCircle } from "lucide-react";
import {
  Dialog,
  DialogContent,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface SuccessModalProps {
  open: boolean;
  itemId: string | null;
}

export function SuccessModal({ open, itemId }: SuccessModalProps) {
  const handleViewListing = () => {
    if (itemId) {
      router.visit(`/items/${itemId}`);
    }
  };

  const handleListAnother = () => {
    router.visit("/items/new");
  };

  return (
    <Dialog open={open}>
      <DialogContent
        className="text-center sm:max-w-sm"
        showCloseButton={false}
      >
        <div className="flex flex-col items-center gap-4 py-4">
          <div className="flex size-16 items-center justify-center rounded-full bg-feedback-success/10">
            <CheckCircle className="size-10 text-feedback-success" />
          </div>
          <div className="space-y-2">
            <h2 className="text-xl font-bold text-content">Your Item is Live!</h2>
            <p className="text-sm text-content-secondary">
              Buyers can now bid on your listing. You'll get notified when someone places a bid.
            </p>
          </div>
          <div className="flex w-full flex-col gap-2 pt-2">
            <Button
              onClick={handleViewListing}
              className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
            >
              View Listing
            </Button>
            <Button
              variant="outline"
              onClick={handleListAnother}
              className="w-full rounded-full"
            >
              List Another Item
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

**Step 3: Build and verify**

```bash
mix assets.build
```

**Step 4: Commit**

```bash
git add assets/js/features/listing-form/components/success-modal.tsx
git commit -m "feat: add success modal for published listings"
```

---

## Task 11: Controller test

Test that the `items/new` route loads correctly with props.

**Files:**
- Modify or create: `test/angle_web/controllers/items_controller_test.exs`

**Step 1: Write the test**

```elixir
defmodule AngleWeb.ItemsControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /items/new" do
    test "returns 200 with categories and store profile for authenticated user", %{conn: conn} do
      user = create_user()
      create_store_profile(%{user_id: user.id, delivery_preference: "seller_delivers"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/items/new")

      assert html_response(conn, 200) =~ "items/new"
    end

    test "returns 200 even without store profile", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/items/new")

      assert html_response(conn, 200) =~ "items/new"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/items/new")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
```

**Step 2: Run the test**

```bash
mix test test/angle_web/controllers/items_controller_test.exs --max-failures 3
```

**Step 3: Commit**

```bash
git add test/angle_web/controllers/items_controller_test.exs
git commit -m "test: add items controller tests for new listing page"
```

---

## Task 12: Final build, full test suite, and cleanup

**Step 1: Run full codegen**

```bash
mix ash_typescript.codegen
```

**Step 2: Build assets**

```bash
mix assets.build
```

**Step 3: Run full test suite**

```bash
mix test --max-failures 5
```

**Step 4: Fix any issues found**

**Step 5: Remove stub files if any remain**

Verify all stub components have been replaced with real implementations.

**Step 6: Final commit**

```bash
git add -A
git commit -m "chore: final cleanup for list item form feature"
```

---

## Task 13: Visual QA against Figma

Compare browser screenshots with Figma designs and fix discrepancies.

**Figma node IDs to compare:**
- Desktop Basic Details: `501-5959`, `575-4340`
- Mobile Basic Details: `722-8448`
- Desktop Auction Info: `722-8782`, `585-7547`
- Mobile Auction Info: `722-8940`
- Desktop Logistics: `722-9056`, `585-7913`
- Mobile Logistics: `722-9151`, `722-9217`
- Desktop Preview: `586-8083`
- Mobile Preview: `722-9334`
- Success Modal: `586-8295`

**Step 1: Start dev server (in worktree)**

```bash
PORT=4113 mix phx.server
```

**Step 2: Navigate to `localhost:4113/items/new`** and take screenshots

**Step 3: Fetch Figma screenshots** for each node ID

**Step 4: Compare and fix visual discrepancies**

**Step 5: Commit fixes**
