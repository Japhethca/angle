# Listing Preview & Edit Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the inline preview wizard step with a server-loaded preview page at `/store/listings/:id/preview` that mirrors the public item detail page, and add `/store/listings/:id/edit` for editing drafts.

**Architecture:** Extract an `ItemDetailLayout` component from `items/show.tsx` that handles the two-column desktop / single-column mobile structure. Both the public page and preview page compose the same layout with different content slots. Each wizard step saves to the server, so the preview page loads the full draft server-side.

**Tech Stack:** Phoenix controllers, Inertia.js, React, AshTypescript RPC, existing item detail components (ImageGallery, ConditionBadge, etc.)

**Design doc:** `docs/plans/2026-02-17-listing-preview-design.md`

---

## Task 1: Add MergeAttributes Ash change for update_draft

The `attributes` field is a freeform JSONB map that holds category-specific data (brand, size, _customFeatures) from Step 1. Steps 2 and 3 also store data in attributes (_auctionDuration, _deliveryPreference). Without merging, each update would overwrite the entire map. Add a server-side change that deep-merges incoming attributes with existing ones.

**Files:**
- Create: `lib/angle/inventory/item/merge_attributes.ex`
- Modify: `lib/angle/inventory/item.ex`

**Step 1: Create MergeAttributes change**

```elixir
# lib/angle/inventory/item/merge_attributes.ex
defmodule Angle.Inventory.Item.MergeAttributes do
  @moduledoc """
  Ash change that merges incoming attributes with existing ones
  instead of replacing the entire map. Only runs when attributes
  is actually being changed, to avoid unnecessary DB writes.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if :attributes in Ash.Changeset.changing_attributes(changeset) do
      new_attrs = Ash.Changeset.get_attribute(changeset, :attributes)
      existing = Map.get(changeset.data, :attributes) || %{}
      merged = Map.merge(existing, new_attrs)
      Ash.Changeset.force_change_attribute(changeset, :attributes, merged)
    else
      changeset
    end
  end
end
```

**Step 2: Add change to update_draft action**

In `lib/angle/inventory/item.ex`, add the change to the `update_draft` action:

```elixir
update :update_draft do
  description "Update an existing item in draft status"

  accept @draft_fields

  argument :id, :uuid, allow_nil?: false
  change {Angle.Inventory.Item.MergeAttributes, []}
end
```

**Step 3: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add lib/angle/inventory/item/merge_attributes.ex lib/angle/inventory/item.ex
git commit -m "feat: add MergeAttributes change for server-side attributes merging"
```

---

## Task 2: Save auction info to server at Step 2

Currently Step 2 (auction info) only saves client-side. Add `updateDraftItem` call when the user clicks Next. With the MergeAttributes change from Task 1, sending partial attributes (just `_auctionDuration`) is safe — it will merge with existing category attributes.

**Files:**
- Modify: `assets/js/features/listing-form/components/auction-info-step.tsx`
- Modify: `assets/js/features/listing-form/components/listing-wizard.tsx`

**Step 1: Update AuctionInfoStep to accept draftItemId and call updateDraftItem**

In `auction-info-step.tsx`, add `draftItemId` prop and save prices + duration on submit:

```tsx
// Add to imports
import { useState } from "react";
import { toast } from "sonner";
import { updateDraftItem, buildCSRFHeaders } from "@/ash_rpc";

// Update interface
interface AuctionInfoStepProps {
  defaultValues: AuctionInfoData;
  draftItemId: string;
  onNext: (data: AuctionInfoData) => void;
  onBack: () => void;
}

// Update component to save before advancing
export function AuctionInfoStep({ defaultValues, draftItemId, onNext, onBack }: AuctionInfoStepProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  // ... existing useForm setup ...

  const onSubmit = async (data: AuctionInfoData) => {
    setIsSubmitting(true);
    try {
      const result = await updateDraftItem({
        identity: draftItemId,
        input: {
          id: draftItemId,
          startingPrice: data.startingPrice,
          reservePrice: data.reservePrice || undefined,
          attributes: { _auctionDuration: data.auctionDuration },
        },
        headers: buildCSRFHeaders(),
      });

      if (!result.success) {
        throw new Error(result.errors.map((e: any) => e.message).join("; "));
      }

      onNext(data);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save auction info");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      {/* ... existing fields ... */}
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Next"}
      </Button>
    </form>
  );
};
```

**Step 2: Pass draftItemId from ListingWizard to AuctionInfoStep**

In `listing-wizard.tsx`, update the Step 2 render:

```tsx
{state.currentStep === 2 && (
  <AuctionInfoStep
    defaultValues={state.auctionInfo}
    draftItemId={state.draftItemId!}
    onNext={handleAuctionInfoNext}
    onBack={handleBack}
  />
)}
```

**Step 3: Verify build**

Run: `mix assets.build`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/features/listing-form/components/auction-info-step.tsx assets/js/features/listing-form/components/listing-wizard.tsx
git commit -m "feat: save auction info to server at Step 2"
```

---

## Task 3: Save logistics to server at Step 3, redirect to preview

Step 3 saves delivery preference via `updateDraftItem` on the item's attributes (keeping it simple — delivery preference is also on StoreProfile but storing on the item makes preview self-contained). With MergeAttributes from Task 1, sending partial attributes is safe. After saving, redirect to the preview page instead of advancing to Step 4.

**Files:**
- Modify: `assets/js/features/listing-form/components/logistics-step.tsx`
- Modify: `assets/js/features/listing-form/components/listing-wizard.tsx`

**Step 1: Update LogisticsStep to save and signal redirect**

In `logistics-step.tsx`:

```tsx
// Add imports
import { useState } from "react";
import { toast } from "sonner";
import { updateDraftItem, buildCSRFHeaders } from "@/ash_rpc";

// Update interface
interface LogisticsStepProps {
  defaultValues: LogisticsData;
  draftItemId: string;
  onNext: (data: LogisticsData) => void;
  onBack: () => void;
}

// Update component
export function LogisticsStep({ defaultValues, draftItemId, onNext }: LogisticsStepProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  // ... existing useForm setup ...

  const onSubmit = async (data: LogisticsData) => {
    setIsSubmitting(true);
    try {
      const result = await updateDraftItem({
        identity: draftItemId,
        input: {
          id: draftItemId,
          attributes: { _deliveryPreference: data.deliveryPreference },
        },
        headers: buildCSRFHeaders(),
      });

      if (!result.success) {
        throw new Error(result.errors.map((e: any) => e.message).join("; "));
      }

      onNext(data);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to save logistics");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
      {/* ... existing fields ... */}
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Preview"}
      </Button>
    </form>
  );
};
```

**Step 2: Update ListingWizard to redirect after Step 3**

In `listing-wizard.tsx`, change `handleLogisticsNext` to redirect instead of going to Step 4:

```tsx
import { router } from "@inertiajs/react";

const handleLogisticsNext = useCallback((data: LogisticsData) => {
  dispatch({ type: "SET_LOGISTICS", data });
  // Redirect to preview page
  router.visit(`/store/listings/${state.draftItemId}/preview`);
}, [state.draftItemId]);
```

Remove the Step 4 render block and the PreviewStep import (no longer used in wizard). Also remove `handlePublished` callback and `SuccessModal` from wizard since publish now happens on the preview page.

**Step 3: Pass draftItemId to LogisticsStep**

```tsx
{state.currentStep === 3 && (
  <LogisticsStep
    defaultValues={state.logistics}
    draftItemId={state.draftItemId!}
    onNext={handleLogisticsNext}
    onBack={handleBack}
  />
)}
```

**Step 4: Verify build**

Run: `mix assets.build`
Expected: No errors

**Step 5: Commit**

```bash
git add assets/js/features/listing-form/
git commit -m "feat: save logistics at Step 3, redirect to preview page"
```

---

## Task 4: Add preview and edit routes + controller actions

**Files:**
- Modify: `lib/angle_web/router.ex`
- Modify: `lib/angle_web/controllers/store_dashboard_controller.ex`

**Step 1: Add routes**

In `router.ex`, add after the `get "/store/listings/new"` line:

```elixir
get "/store/listings/:id/preview", StoreDashboardController, :preview
get "/store/listings/:id/edit", StoreDashboardController, :edit
```

**Step 2: Add preview action**

In `store_dashboard_controller.ex`:

```elixir
def preview(conn, %{"id" => id}) do
  user = conn.assigns.current_user

  case load_draft_item(conn, id, user.id) do
    {:ok, item, images} ->
      seller = serialize_preview_seller(user)

      conn
      |> assign_prop(:item, item)
      |> assign_prop(:images, images)
      |> assign_prop(:seller, seller)
      |> render_inertia("store/listings/preview")

    :not_found ->
      conn
      |> put_flash(:error, "Draft not found")
      |> redirect(to: ~p"/store/listings")
  end
end
```

**Step 3: Add edit action**

```elixir
def edit(conn, %{"id" => id} = params) do
  user = conn.assigns.current_user
  step = parse_positive_int(params["step"], 1)

  case load_draft_item(conn, id, user.id) do
    {:ok, item, images} ->
      categories = load_listing_form_categories(conn)
      store_profile_data = load_store_profile(conn)

      conn
      |> assign_prop(:item, item)
      |> assign_prop(:images, images)
      |> assign_prop(:categories, categories)
      |> assign_prop(:storeProfile, store_profile_data)
      |> assign_prop(:step, step)
      |> render_inertia("store/listings/edit")

    :not_found ->
      conn
      |> put_flash(:error, "Draft not found")
      |> redirect(to: ~p"/store/listings")
  end
end
```

**Step 4: Add helper functions**

```elixir
defp load_draft_item(conn, id, user_id) do
  params = %{filter: %{id: id, created_by_id: user_id}, page: %{limit: 1}}

  case AshTypescript.Rpc.run_typed_query(:angle, :item_detail, params, conn) do
    %{"success" => true, "data" => data} ->
      case extract_results(data) do
        [item | _] ->
          images = AngleWeb.ImageHelpers.load_item_images(id)
          {:ok, item, images}

        _ ->
          :not_found
      end

    _ ->
      :not_found
  end
end

defp serialize_preview_seller(user) do
  user = Ash.load!(user, [:avg_rating, :review_count], authorize?: false)

  %{
    "id" => user.id,
    "fullName" => user.full_name,
    "username" => user.username,
    "publishedItemCount" => nil
  }
end
```

**Step 5: Verify compilation**

Run: `mix compile --warnings-as-errors`
Expected: Compiles with no errors (warnings about PaymentsController are pre-existing)

**Step 6: Commit**

```bash
git add lib/angle_web/router.ex lib/angle_web/controllers/store_dashboard_controller.ex
git commit -m "feat: add preview and edit routes + controller actions"
```

---

## Task 5: Extract ItemDetailLayout from items/show.tsx

Create a shared layout component that handles the two-column desktop / single-column mobile structure. Both pages compose this layout with different slot content.

**Files:**
- Create: `assets/js/features/items/components/item-detail-layout.tsx`
- Modify: `assets/js/features/items/index.ts`
- Modify: `assets/js/pages/items/show.tsx`

**Step 1: Create ItemDetailLayout**

The layout handles: image gallery placement, title+condition+timer header, price display, and the two-column structure. It accepts slot-style render props for the action area and content sections.

```tsx
// assets/js/features/items/components/item-detail-layout.tsx
import { Eye } from "lucide-react";
import type { ImageData } from "@/lib/image-url";
import { formatNaira } from "@/lib/format";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { ConditionBadge } from "./condition-badge";
import { ItemImageGallery } from "./item-image-gallery";

interface ItemDetailLayoutProps {
  title: string;
  condition: string;
  price: string | null;
  priceLabel?: string;
  endTime?: string | null;
  viewCount?: number | null;
  images: ImageData[];
  /** Mobile header (back button, share, etc.) */
  mobileHeader?: React.ReactNode;
  /** Desktop breadcrumb / banner */
  desktopHeader?: React.ReactNode;
  /** Action area: bid section (public) or publish button (preview) */
  actionArea?: React.ReactNode;
  /** Content sections below the gallery: tabs (public) or linear sections (preview) */
  contentSections?: React.ReactNode;
  /** Footer: seller card, similar items, etc. */
  footer?: React.ReactNode;
}

export function ItemDetailLayout({
  title,
  condition,
  price,
  priceLabel = "Current Price",
  endTime,
  viewCount,
  images,
  mobileHeader,
  desktopHeader,
  actionArea,
  contentSections,
  footer,
}: ItemDetailLayoutProps) {
  const itemHeader = (
    <div className="space-y-3">
      <ConditionBadge condition={condition} />
      <h1 className="font-heading text-xl font-semibold text-content">{title}</h1>
      <div className="flex items-center gap-3 text-xs text-content-tertiary">
        {endTime && <CountdownTimer endTime={endTime} />}
        {viewCount != null && viewCount > 0 && (
          <span className="inline-flex items-center gap-1">
            <Eye className="size-3" />
            {viewCount} views
          </span>
        )}
      </div>
    </div>
  );

  const priceDisplay = price ? (
    <div>
      <p className="text-xs text-content-tertiary">{priceLabel}</p>
      <p className="text-2xl font-bold text-content">{formatNaira(price)}</p>
    </div>
  ) : null;

  return (
    <>
      {/* Mobile header */}
      {mobileHeader && <div className="lg:hidden">{mobileHeader}</div>}

      {/* Desktop header */}
      {desktopHeader && <div className="hidden lg:block">{desktopHeader}</div>}

      <div className="px-4 py-4 lg:px-8 lg:py-5">
        {/* Desktop: two-column layout */}
        <div className="hidden gap-8 lg:flex">
          {/* Left column */}
          <div className="min-w-0 flex-1 space-y-8">
            <ItemImageGallery title={title} images={images} />
            {contentSections}
            {footer}
          </div>

          {/* Right column - sticky */}
          <div className="w-[400px] shrink-0">
            <div className="sticky top-24 space-y-4">
              {itemHeader}
              {priceDisplay}
              {actionArea}
            </div>
          </div>
        </div>

        {/* Mobile: single-column */}
        <div className="space-y-6 lg:hidden">
          <ItemImageGallery title={title} images={images} />
          <div className="space-y-2">
            <ConditionBadge condition={condition} />
            <h1 className="font-heading text-lg font-semibold text-content">{title}</h1>
            <div className="flex items-center gap-3 text-xs text-content-tertiary">
              {endTime && <CountdownTimer endTime={endTime} />}
              {viewCount != null && viewCount > 0 && (
                <span className="inline-flex items-center gap-1">
                  <Eye className="size-3" />
                  {viewCount} views
                </span>
              )}
            </div>
          </div>
          {price && (
            <div>
              <p className="text-xs text-content-tertiary">{priceLabel}</p>
              <p className="text-xl font-bold text-content">{formatNaira(price)}</p>
            </div>
          )}
          {actionArea}
          {contentSections}
          {footer}
        </div>
      </div>
    </>
  );
}
```

**Step 2: Export from barrel**

In `assets/js/features/items/index.ts`, add:

```tsx
export { ItemDetailLayout } from "./components/item-detail-layout";
```

**Step 3: Refactor items/show.tsx to use ItemDetailLayout**

Replace the inline layout in `pages/items/show.tsx` with `ItemDetailLayout`:

```tsx
import { Head, Link } from "@inertiajs/react";
import { ArrowLeft, Share2, Heart, ChevronRight } from "lucide-react";
import type { ItemDetail, HomepageItemCard } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { coverImage as getCoverImage } from "@/lib/image-url";
import {
  ItemDetailLayout,
  ItemDetailTabs,
  SellerCard,
  SimilarItems,
} from '@/features/items';
import { BidSection } from '@/features/bidding';
import { useWatchlistToggle } from '@/features/watchlist/hooks/use-watchlist-toggle';
import { toast } from 'sonner';

interface Seller {
  id: string;
  fullName: string | null;
  username?: string | null;
  publishedItemCount?: number | null;
}

interface ShowProps {
  item: ItemDetail[number] & { user: Seller | null; images?: ImageData[] };
  similar_items: HomepageItemCard;
  watchlist_entry_id: string | null;
}

export default function Show({ item, similar_items = [], watchlist_entry_id = null }: ShowProps) {
  const price = item.currentPrice || item.startingPrice;
  const itemImages = item.images || [];
  const itemCoverImage = getCoverImage(itemImages);
  const {
    isWatchlisted,
    toggle: toggleWatch,
    isPending: isWatchPending,
  } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId: watchlist_entry_id,
    onAdd: () => toast.success('Added to your watchlist'),
    onRemove: () => toast.success('Removed from your watchlist'),
  });

  return (
    <>
      <Head title={item.title} />
      <ItemDetailLayout
        title={item.title}
        condition={item.condition}
        price={price}
        endTime={item.endTime}
        viewCount={item.viewCount}
        images={itemImages}
        mobileHeader={
          <div className="flex items-center justify-between px-4 py-3">
            <button
              onClick={() => window.history.back()}
              className="flex size-9 items-center justify-center rounded-full border border-strong"
            >
              <ArrowLeft className="size-4 text-content" />
            </button>
            <span className="text-sm font-medium text-content">{item.category?.name || 'Item'}</span>
            <div className="flex gap-2">
              <button className="flex size-9 items-center justify-center rounded-full border border-strong">
                <Share2 className="size-4 text-content" />
              </button>
              <button
                onClick={toggleWatch}
                disabled={isWatchPending}
                className="flex size-9 items-center justify-center rounded-full border border-strong"
              >
                <Heart className={`size-4 ${isWatchlisted ? 'fill-red-500 text-red-500' : 'text-content'}`} />
              </button>
            </div>
          </div>
        }
        desktopHeader={
          <div className="px-8 pt-5">
            <nav className="flex items-center gap-1.5 text-xs text-content-tertiary">
              <Link href="/" className="hover:text-content">Home</Link>
              <ChevronRight className="size-3" />
              {item.category && (
                <>
                  <span className="hover:text-content">{item.category.name}</span>
                  <ChevronRight className="size-3" />
                </>
              )}
              <span className="text-content">{item.title}</span>
            </nav>
          </div>
        }
        actionArea={
          <BidSection
            itemId={item.id}
            itemTitle={item.title}
            currentPrice={item.currentPrice}
            startingPrice={item.startingPrice}
            bidIncrement={item.bidIncrement}
            bidCount={item.bidCount}
            isWatchlisted={isWatchlisted}
            onToggleWatch={toggleWatch}
            isWatchPending={isWatchPending}
            coverImage={itemCoverImage}
          />
        }
        contentSections={
          <>
            <SellerCard seller={item.user} />
            <ItemDetailTabs description={item.description} />
          </>
        }
        footer={<SimilarItems items={similar_items} />}
      />
    </>
  );
}
```

**Step 4: Verify build and that the public item page still works**

Run: `mix assets.build`
Visit: `localhost:4113/items/<any-slug>` — verify it renders identically to before

**Step 5: Commit**

```bash
git add assets/js/features/items/ assets/js/pages/items/show.tsx
git commit -m "refactor: extract ItemDetailLayout for shared item page structure"
```

---

## Task 6: Create preview page

**Files:**
- Create: `assets/js/pages/store/listings/preview.tsx`

**Step 1: Create the preview page**

This page uses `ItemDetailLayout` in preview mode, wrapped in `StoreLayout`. It shows Edit links on each content section and a Publish button in the action area.

```tsx
// assets/js/pages/store/listings/preview.tsx
import { useState } from "react";
import { Head } from "@inertiajs/react";
import { router } from "@inertiajs/react";
import { Pencil } from "lucide-react";
import { toast } from "sonner";
import type { ItemDetail } from "@/ash_rpc";
import { updateDraftItem, publishItem, buildCSRFHeaders } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { Button } from "@/components/ui/button";
import { StoreLayout } from "@/features/store-dashboard";
import { ItemDetailLayout } from "@/features/items";
import { SuccessModal } from "@/features/listing-form/components/success-modal";

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

interface PreviewPageProps {
  item: ItemDetail[number];
  images: ImageData[];
  seller: { id: string; fullName: string | null; username?: string | null } | null;
}

export default function PreviewPage({ item, images, seller }: PreviewPageProps) {
  const [isPublishing, setIsPublishing] = useState(false);
  const [isPublished, setIsPublished] = useState(false);

  const attrs = (item.attributes || {}) as Record<string, string>;
  const durationKey = attrs._auctionDuration || "7d";
  const duration = DURATION_MAP[durationKey] || DURATION_MAP["7d"];
  const deliveryPref = attrs._deliveryPreference || "buyer_arranges";
  const price = item.startingPrice;

  // Build features from attributes (exclude internal keys)
  const features = Object.entries(attrs)
    .filter(([key, val]) => !key.startsWith("_") && val)
    .map(([key, val]) => `${key}: ${val}`);

  const handleEdit = (step: number) => {
    router.visit(`/store/listings/${item.id}/edit?step=${step}`);
  };

  const handlePublish = async () => {
    setIsPublishing(true);
    try {
      const now = new Date();
      const endTime = new Date(now.getTime() + duration.ms);

      // Set final start/end times
      const updateResult = await updateDraftItem({
        identity: item.id,
        input: {
          id: item.id,
          startTime: now.toISOString(),
          endTime: endTime.toISOString(),
        },
        headers: buildCSRFHeaders(),
      });

      if (!updateResult.success) {
        throw new Error(updateResult.errors.map((e: any) => e.message).join("; "));
      }

      const publishResult = await publishItem({
        identity: item.id,
        headers: buildCSRFHeaders(),
      });

      if (!publishResult.success) {
        throw new Error(publishResult.errors.map((e: any) => e.message).join("; "));
      }

      setIsPublished(true);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "Failed to publish");
    } finally {
      setIsPublishing(false);
    }
  };

  return (
    <>
      <Head title="Preview Listing" />
      <StoreLayout title="Preview Listing">
        <p className="mb-4 text-sm text-content-tertiary">
          Make sure everything looks good before you publish.
        </p>

        <ItemDetailLayout
          title={item.title}
          condition={item.condition}
          price={price}
          priceLabel="Starting Price"
          images={images}
          actionArea={
            <div className="space-y-3">
              <p className="text-sm text-content-tertiary">
                Duration: {duration.label}
              </p>
              <Button
                onClick={handlePublish}
                disabled={isPublishing}
                className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
              >
                {isPublishing ? "Publishing..." : "Publish"}
              </Button>
            </div>
          }
          contentSections={
            <div className="space-y-6">
              {/* Product Description */}
              <PreviewSection title="Product Description" onEdit={() => handleEdit(1)}>
                <p className="text-sm leading-relaxed text-content-secondary whitespace-pre-line">
                  {item.description || "No description provided."}
                </p>
              </PreviewSection>

              {/* Key Features */}
              {features.length > 0 && (
                <PreviewSection title="Key Features" onEdit={() => handleEdit(1)}>
                  <ul className="list-inside list-disc space-y-1 text-sm text-content-secondary">
                    {features.map((f, i) => (
                      <li key={i}>{f}</li>
                    ))}
                  </ul>
                </PreviewSection>
              )}

              {/* Logistics */}
              <PreviewSection title="Logistics" onEdit={() => handleEdit(3)}>
                <p className="text-sm text-content-secondary">
                  {DELIVERY_LABELS[deliveryPref] || deliveryPref}
                </p>
              </PreviewSection>
            </div>
          }
        />
      </StoreLayout>

      <SuccessModal open={isPublished} itemId={item.id} />
    </>
  );
}

function PreviewSection({
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

**Step 2: Verify build**

Run: `mix assets.build`
Expected: No errors

**Step 3: Commit**

```bash
git add assets/js/pages/store/listings/preview.tsx
git commit -m "feat: add server-loaded preview page at /store/listings/:id/preview"
```

---

## Task 7: Create edit page

**Files:**
- Create: `assets/js/pages/store/listings/edit.tsx`

**Step 1: Create the edit page**

This page renders the same `ListingWizard` component as `/store/listings/new` but pre-fills it from server-loaded draft data and starts at the specified step.

```tsx
// assets/js/pages/store/listings/edit.tsx
import { Head } from "@inertiajs/react";
import type { ItemDetail } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { StoreLayout } from "@/features/store-dashboard";
import { ListingWizard, type Category } from "@/features/listing-form/components/listing-wizard";

interface EditPageProps {
  item: ItemDetail[number];
  images: ImageData[];
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
  step: number;
}

export default function EditPage({ item, images, categories, storeProfile, step }: EditPageProps) {
  const attrs = (item.attributes || {}) as Record<string, string>;

  const initialData = {
    draftItemId: item.id,
    basicDetails: {
      title: item.title || "",
      description: item.description || "",
      categoryId: item.category?.id || "",
      subcategoryId: "",
      condition: (item.condition as "new" | "used" | "refurbished") || "used",
      attributes: attrs,
      customFeatures: attrs._customFeatures ? attrs._customFeatures.split("|||") : ["", "", ""],
    },
    auctionInfo: {
      startingPrice: item.startingPrice || "",
      reservePrice: item.reservePrice || "",
      auctionDuration: (attrs._auctionDuration as "24h" | "3d" | "7d") || "7d",
    },
    logistics: {
      deliveryPreference: (attrs._deliveryPreference as "meetup" | "buyer_arranges" | "seller_arranges") || "buyer_arranges",
    },
    uploadedImages: images.map((img, i) => ({
      id: img.id,
      position: i,
      variants: img.variants || {},
    })),
    step: Math.min(Math.max(step, 1), 3) as 1 | 2 | 3,
  };

  return (
    <>
      <Head title="Edit Listing" />
      <StoreLayout title="Edit Listing">
        <ListingWizard
          categories={categories}
          storeProfile={storeProfile}
          initialData={initialData}
        />
      </StoreLayout>
    </>
  );
}
```

**Step 2: Update ListingWizard to accept optional initialData prop**

In `listing-wizard.tsx`, add `initialData` to the props interface and use it to initialize the reducer:

```tsx
interface InitialWizardData {
  draftItemId: string;
  basicDetails: BasicDetailsData;
  auctionInfo: AuctionInfoData;
  logistics: LogisticsData;
  uploadedImages: ListingFormState["uploadedImages"];
  step: 1 | 2 | 3;
}

interface ListingWizardProps {
  categories: Category[];
  storeProfile: { deliveryPreference: string | null } | null;
  initialData?: InitialWizardData;
}

export function ListingWizard({ categories, storeProfile, initialData }: ListingWizardProps) {
  const defaultDelivery = mapDeliveryPreference(storeProfile?.deliveryPreference);

  const [state, dispatch] = useReducer(listingFormReducer, {
    ...initialFormState,
    ...(initialData
      ? {
          currentStep: initialData.step,
          draftItemId: initialData.draftItemId,
          basicDetails: initialData.basicDetails,
          auctionInfo: initialData.auctionInfo,
          logistics: initialData.logistics,
          uploadedImages: initialData.uploadedImages,
        }
      : {
          logistics: { deliveryPreference: defaultDelivery },
        }),
  });
  // ... rest unchanged
```

**Step 3: Verify build**

Run: `mix assets.build`
Expected: No errors

**Step 4: Commit**

```bash
git add assets/js/pages/store/listings/edit.tsx assets/js/features/listing-form/components/listing-wizard.tsx
git commit -m "feat: add edit page with pre-filled wizard from server data"
```

---

## Task 8: Clean up old preview step and update tests

**Files:**
- Delete: `assets/js/features/listing-form/components/preview-step.tsx`
- Modify: `test/angle_web/controllers/items_controller_test.exs` (rename to `store_listings_controller_test.exs` and add preview/edit tests)

**Step 1: Delete preview-step.tsx**

```bash
rm assets/js/features/listing-form/components/preview-step.tsx
```

Remove any remaining imports of `PreviewStep` from `listing-wizard.tsx` if not already done in Task 2.

**Step 2: Add tests for preview and edit routes**

Update the test file (currently at `test/angle_web/controllers/items_controller_test.exs`):

```elixir
defmodule AngleWeb.ItemsControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /store/listings/new" do
    test "returns 200 for authenticated user with store profile", %{conn: conn} do
      user = create_user()
      create_store_profile(%{user_id: user.id, delivery_preference: "seller_delivers"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/new")

      assert html_response(conn, 200) =~ "store/listings/new"
    end

    test "returns 200 for authenticated user without store profile", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/new")

      assert html_response(conn, 200) =~ "store/listings/new"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/new")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings/:id/preview" do
    test "returns 200 for owner of draft item", %{conn: conn} do
      user = create_user()
      item = create_item(%{created_by_id: user.id, publication_status: :draft})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{item.id}/preview")

      assert html_response(conn, 200) =~ "store/listings/preview"
    end

    test "redirects when item not found", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{Ecto.UUID.generate()}/preview")

      assert redirected_to(conn) == ~p"/store/listings"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/#{Ecto.UUID.generate()}/preview")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings/:id/edit" do
    test "returns 200 for owner of draft item", %{conn: conn} do
      user = create_user()
      item = create_item(%{created_by_id: user.id, publication_status: :draft})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings/#{item.id}/edit?step=2")

      assert html_response(conn, 200) =~ "store/listings/edit"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store/listings/#{Ecto.UUID.generate()}/edit")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/angle_web/controllers/items_controller_test.exs --max-failures 3`
Expected: All tests pass

**Step 4: Commit**

```bash
git add -A
git commit -m "feat: clean up old preview step, add preview/edit route tests"
```

---

## Task 9: Visual QA against Figma

**Step 1: Build assets**

Run: `mix assets.build`

**Step 2: Compare preview page with Figma**

Navigate to `localhost:4113/store/listings/new`, complete Steps 1-3 with test data, then verify the preview page at `/store/listings/:id/preview`.

Take screenshots and compare with Figma nodes:
- Desktop: `586-8083`
- Mobile: `722-9334`

**Step 3: Fix any discrepancies found**

**Step 4: Commit fixes**

```bash
git add -A
git commit -m "fix: visual QA fixes for preview page"
```
