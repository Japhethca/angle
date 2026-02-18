# Listing Form & Detail Page Fixes — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix image management bugs, improve category field placement, and render item attributes on the detail page.

**Architecture:** All changes are frontend-only (React/TypeScript). The backend already has a `DELETE /uploads/:id` endpoint and the `item_detail` typed query already includes `attributes`. We just need to wire up the UI.

**Tech Stack:** React 19, TypeScript, Tailwind CSS, Lucide React icons, shadcn/ui

---

### Task 1: Fix multi-image upload bug (reset file input)

**Files:**
- Modify: `assets/js/features/listing-form/components/basic-details-step.tsx:107-115`

**Step 1: Fix the `handleImageSelect` callback**

The bug is that `e.target.value` is not reset after reading files, so the browser reuses stale data on repeated selections.

In `basic-details-step.tsx`, change the `handleImageSelect` callback (lines 107-115) from:

```typescript
const handleImageSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    const total = selectedImages.length + existingUploaded.length + files.length;
    if (total > 10) {
      toast.error("Maximum 10 images allowed");
      return;
    }
    setSelectedImages((prev) => [...prev, ...files]);
  }, [selectedImages, existingUploaded]);
```

to:

```typescript
const handleImageSelect = useCallback((e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    const total = selectedImages.length + existingUploaded.length + files.length;
    if (total > 10) {
      toast.error("Maximum 10 images allowed");
      return;
    }
    setSelectedImages((prev) => [...prev, ...files]);
  }, [selectedImages, existingUploaded]);
```

The only change is adding `e.target.value = "";` immediately after reading the file list. This must come after `Array.from()` since resetting clears the FileList.

**Step 2: Verify manually**

Run: Open browser at `localhost:4113/store/listings/new`, select 3 different images — each should show a distinct preview.

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/basic-details-step.tsx
git commit -m "fix: reset file input value after reading images to prevent duplicate previews"
```

---

### Task 2: Add delete button on uploaded images

**Files:**
- Modify: `assets/js/features/listing-form/components/basic-details-step.tsx`

This task adds an `×` button on each previously-uploaded image thumbnail, and calls `DELETE /uploads/:id` to remove it from the server.

**Step 1: Add state and handler for image deletion**

Add a `deletingImageId` state and a `handleDeleteUploadedImage` callback. Place these near the existing `removeSelectedImage` callback (around line 117-119):

```typescript
const [deletingImageId, setDeletingImageId] = useState<string | null>(null);

const handleDeleteUploadedImage = useCallback(async (imageId: string) => {
  setDeletingImageId(imageId);
  try {
    const csrfToken = getPhoenixCSRFToken();
    const res = await fetch(`/uploads/${imageId}`, {
      method: "DELETE",
      headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
    });
    if (!res.ok) throw new Error("Failed to delete image");
    // Remove from parent state via onNext's uploadedImages
    // We need a way to update existingUploaded — add a callback prop or manage locally
  } catch {
    toast.error("Failed to delete image");
  } finally {
    setDeletingImageId(null);
  }
}, []);
```

**However**, `existingUploaded` comes from the parent `ListingWizard` via props. We need the parent to know about deletions. The simplest approach: add an `onDeleteImage` callback prop to `BasicDetailsStep`, and have the wizard dispatch a new reducer action.

**Step 2: Add reducer action for removing an uploaded image**

In `assets/js/features/listing-form/schemas/listing-form-schema.ts`, add a new action type to the `ListingFormAction` union (line 45-54):

```typescript
export type ListingFormAction =
  | { type: "SET_STEP"; step: 1 | 2 | 3 }
  | { type: "SET_DRAFT_ID"; id: string }
  | { type: "SET_BASIC_DETAILS"; data: BasicDetailsData }
  | { type: "SET_AUCTION_INFO"; data: AuctionInfoData }
  | { type: "SET_LOGISTICS"; data: LogisticsData }
  | { type: "SET_SELECTED_IMAGES"; files: File[] }
  | { type: "SET_UPLOADED_IMAGES"; images: ListingFormState["uploadedImages"] }
  | { type: "REMOVE_UPLOADED_IMAGE"; id: string }
  | { type: "SET_SUBMITTING"; value: boolean }
  | { type: "SET_PUBLISHED"; value: boolean };
```

Add the handler in `listingFormReducer` (inside the switch, before `default`):

```typescript
case "REMOVE_UPLOADED_IMAGE":
  return { ...state, uploadedImages: state.uploadedImages.filter((img) => img.id !== action.id) };
```

**Step 3: Wire up `onDeleteImage` in ListingWizard**

In `assets/js/features/listing-form/components/listing-wizard.tsx`, add a callback and pass it to `BasicDetailsStep`:

After the existing `handleBasicDetailsNext` (around line 80), add:

```typescript
const handleDeleteImage = useCallback((imageId: string) => {
  dispatch({ type: "REMOVE_UPLOADED_IMAGE", id: imageId });
}, []);
```

Then update the `BasicDetailsStep` JSX (around line 123-130) to pass it:

```tsx
<BasicDetailsStep
  categories={categories}
  defaultValues={state.basicDetails}
  defaultImages={state.selectedImages}
  draftItemId={state.draftItemId}
  uploadedImages={state.uploadedImages}
  onNext={handleBasicDetailsNext}
  onDeleteImage={handleDeleteImage}
/>
```

**Step 4: Update BasicDetailsStep props and delete handler**

In `basic-details-step.tsx`:

1. Add `onDeleteImage` to the interface (line 28-35):

```typescript
interface BasicDetailsStepProps {
  categories: Category[];
  defaultValues: BasicDetailsData;
  defaultImages: File[];
  draftItemId: string | null;
  uploadedImages: ListingFormState["uploadedImages"];
  onNext: (data: BasicDetailsData, draftId: string, uploadedImages: ListingFormState["uploadedImages"]) => void;
  onDeleteImage: (imageId: string) => void;
}
```

2. Destructure it in the component function (line 37-44):

```typescript
export function BasicDetailsStep({
  categories,
  defaultValues,
  defaultImages,
  draftItemId,
  uploadedImages: existingUploaded,
  onNext,
  onDeleteImage,
}: BasicDetailsStepProps) {
```

3. Add state and handler (after `removeSelectedImage`, around line 119):

```typescript
const [deletingImageId, setDeletingImageId] = useState<string | null>(null);

const handleDeleteUploadedImage = useCallback(async (imageId: string) => {
  setDeletingImageId(imageId);
  try {
    const csrfToken = getPhoenixCSRFToken();
    const res = await fetch(`/uploads/${imageId}`, {
      method: "DELETE",
      headers: csrfToken ? { "X-CSRF-Token": csrfToken } : {},
    });
    if (!res.ok) throw new Error("Failed to delete image");
    onDeleteImage(imageId);
  } catch {
    toast.error("Failed to delete image");
  } finally {
    setDeletingImageId(null);
  }
}, [onDeleteImage]);
```

4. Update the uploaded images grid (lines 271-283) to add the delete button:

Replace this block:

```tsx
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
```

With:

```tsx
{existingUploaded.length > 0 && (
  <div className="grid grid-cols-4 gap-2">
    {existingUploaded.map((img) => (
      <div key={img.id} className="group relative aspect-square overflow-hidden rounded-md bg-surface-muted">
        <img
          src={img.variants.thumbnail || img.variants.original}
          alt=""
          className="size-full object-cover"
        />
        <button
          type="button"
          disabled={deletingImageId === img.id}
          onClick={() => handleDeleteUploadedImage(img.id)}
          className="absolute right-1 top-1 flex size-5 items-center justify-center rounded-full bg-black/60 text-xs text-white opacity-0 transition-opacity group-hover:opacity-100 disabled:opacity-50"
        >
          {deletingImageId === img.id ? "..." : "\u00d7"}
        </button>
      </div>
    ))}
  </div>
)}
```

**Step 5: Verify manually**

1. Go to `localhost:4113/store/listings/<draft-id>/edit` for a draft with images
2. Hover over an uploaded image — `×` button should appear
3. Click `×` — image should disappear, server should delete it (check network tab for 204)

**Step 6: Commit**

```bash
git add assets/js/features/listing-form/components/basic-details-step.tsx assets/js/features/listing-form/schemas/listing-form-schema.ts assets/js/features/listing-form/components/listing-wizard.tsx
git commit -m "feat: add delete button on uploaded images in listing form"
```

---

### Task 3: Move category attribute fields below category selector

**Files:**
- Modify: `assets/js/features/listing-form/components/basic-details-step.tsx:251-264`

**Step 1: Reorder the JSX**

Currently the order in the form JSX (inside the `<form>` element) is:

1. Title (line 176)
2. Description (line 189)
3. Category + Condition grid (line 200-250)
4. Features (line 253)
5. Category-specific fields (line 256-264)
6. Photo upload (line 267)
7. Next button (line 328)

Move the category-specific fields block (lines 255-264) to appear right after the Category + Condition grid (after line 250), before Features.

The new order becomes:

1. Title
2. Description
3. Category + Condition grid
4. **Category-specific fields** (moved up)
5. Features
6. Photo upload
7. Next button

Cut this block:

```tsx
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
```

And paste it between the closing `</div>` of the Category + Condition grid (line 250) and the `{/* Features */}` comment (line 252).

**Step 2: Verify manually**

Open `localhost:4113/store/listings/new`, select a category that has attribute fields (e.g., one with Brand/Model). Verify the attribute fields appear right below the category/condition row, above Features.

**Step 3: Commit**

```bash
git add assets/js/features/listing-form/components/basic-details-step.tsx
git commit -m "fix: move category attribute fields below category selector"
```

---

### Task 4: Render item attributes and features on detail page

**Files:**
- Modify: `assets/js/pages/items/show.tsx:112-121`
- Modify: `assets/js/features/items/components/item-detail-tabs.tsx`

**Step 1: Pass `attributes` to `ItemDetailTabs` from `show.tsx`**

In `assets/js/pages/items/show.tsx`, the `<ItemDetailTabs>` is rendered at lines 115 and 120. Update both calls to pass `attributes`:

Line 115 (desktop):
```tsx
<ItemDetailTabs description={item.description} attributes={item.attributes} />
```

Line 120 (mobile):
```tsx
<ItemDetailTabs description={item.description} attributes={item.attributes} />
```

**Step 2: Update `ItemDetailTabs` to accept and render attributes**

In `assets/js/features/items/components/item-detail-tabs.tsx`:

1. Update the interface (lines 3-5):

```typescript
interface ItemDetailTabsProps {
  description: string | null;
  attributes?: Record<string, any> | null;
}
```

2. Add attribute parsing logic at the top of the component function (after the destructuring, line 16):

```typescript
export function ItemDetailTabs({ description, attributes }: ItemDetailTabsProps) {
  const attrs = (attributes || {}) as Record<string, string>;

  // Category-specific attributes (non-underscore-prefixed, non-empty)
  const categoryAttrs = Object.entries(attrs)
    .filter(([key, val]) => !key.startsWith("_") && val)
    .map(([key, val]) => ({ key, value: val }));

  // Custom features from _customFeatures
  const customFeatures = attrs._customFeatures
    ? attrs._customFeatures.split("|||").filter(Boolean)
    : [];

  const hasFeatures = categoryAttrs.length > 0 || customFeatures.length > 0;
```

3. Replace the desktop Features tab content (lines 36-40):

From:
```tsx
<TabsContent value="features" className="mt-4">
  <p className="text-sm text-content-tertiary">
    Feature details will be available soon.
  </p>
</TabsContent>
```

To:
```tsx
<TabsContent value="features" className="mt-4">
  {hasFeatures ? (
    <div className="space-y-4">
      {categoryAttrs.length > 0 && (
        <dl className="grid grid-cols-2 gap-x-6 gap-y-3">
          {categoryAttrs.map(({ key, value }) => (
            <div key={key}>
              <dt className="text-xs text-content-tertiary">{key}</dt>
              <dd className="text-sm font-medium text-content">{value}</dd>
            </div>
          ))}
        </dl>
      )}
      {categoryAttrs.length > 0 && customFeatures.length > 0 && (
        <hr className="border-border" />
      )}
      {customFeatures.length > 0 && (
        <ul className="space-y-2">
          {customFeatures.map((f, i) => (
            <li key={i} className="flex items-center gap-2 text-sm text-content-secondary">
              <Check className="size-4 shrink-0 text-primary-600" />
              {f}
            </li>
          ))}
        </ul>
      )}
    </div>
  ) : (
    <p className="text-sm text-content-tertiary">
      No features listed for this item.
    </p>
  )}
</TabsContent>
```

4. Replace the mobile Features section (lines 79-86):

From:
```tsx
<section>
  <h3 className="mb-2 font-heading text-sm font-medium text-content">
    Features
  </h3>
  <p className="text-sm text-content-tertiary">
    Feature details will be available soon.
  </p>
</section>
```

To:
```tsx
<section>
  <h3 className="mb-2 font-heading text-sm font-medium text-content">
    Features
  </h3>
  {hasFeatures ? (
    <div className="space-y-3">
      {categoryAttrs.length > 0 && (
        <dl className="grid grid-cols-2 gap-x-4 gap-y-2">
          {categoryAttrs.map(({ key, value }) => (
            <div key={key}>
              <dt className="text-xs text-content-tertiary">{key}</dt>
              <dd className="text-sm font-medium text-content">{value}</dd>
            </div>
          ))}
        </dl>
      )}
      {categoryAttrs.length > 0 && customFeatures.length > 0 && (
        <hr className="border-border" />
      )}
      {customFeatures.length > 0 && (
        <ul className="space-y-2">
          {customFeatures.map((f, i) => (
            <li key={i} className="flex items-center gap-2 text-sm text-content-secondary">
              <Check className="size-4 shrink-0 text-primary-600" />
              {f}
            </li>
          ))}
        </ul>
      )}
    </div>
  ) : (
    <p className="text-sm text-content-tertiary">
      No features listed for this item.
    </p>
  )}
</section>
```

5. Add the `Check` icon import at the top of the file:

```typescript
import { Check } from "lucide-react";
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs";
```

**Step 3: Verify manually**

1. Go to `localhost:4113/items/<slug>` for a published item with attributes
2. Click the "Features" tab — should show key-value grid for category attributes and check-icon list for custom features
3. On mobile viewport — Features section should show the same content inline

**Step 4: Commit**

```bash
git add assets/js/features/items/components/item-detail-tabs.tsx assets/js/pages/items/show.tsx
git commit -m "feat: render item attributes and features on detail page"
```
