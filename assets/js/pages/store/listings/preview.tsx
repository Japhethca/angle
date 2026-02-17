import { useState } from "react";
import { Head, router } from "@inertiajs/react";
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
  "24h": { label: "24 hours", ms: 24 * 60 * 60 * 1000 },
  "3d": { label: "3 days", ms: 3 * 24 * 60 * 60 * 1000 },
  "7d": { label: "7 days", ms: 7 * 24 * 60 * 60 * 1000 },
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

export default function PreviewPage({ item, images }: PreviewPageProps) {
  const [isPublishing, setIsPublishing] = useState(false);
  const [isPublished, setIsPublished] = useState(false);

  const attrs = (item.attributes || {}) as Record<string, string>;
  const durationKey = attrs._auctionDuration || "7d";
  const duration = DURATION_MAP[durationKey] || DURATION_MAP["7d"];
  const deliveryPref = attrs._deliveryPreference || "buyer_arranges";
  const price = item.startingPrice;

  // Build custom features from _customFeatures
  const customFeatures = attrs._customFeatures
    ? attrs._customFeatures.split("|||").filter(Boolean)
    : [];

  // Build category-specific attributes (non-underscore-prefixed, non-empty)
  const categoryAttrs = Object.entries(attrs)
    .filter(([key, val]) => !key.startsWith("_") && val)
    .map(([key, val]) => ({ key, value: val }));

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

              {/* Key Features (custom + category-specific) */}
              {(customFeatures.length > 0 || categoryAttrs.length > 0) && (
                <PreviewSection title="Key Features" onEdit={() => handleEdit(1)}>
                  <ul className="list-inside list-disc space-y-1 text-sm text-content-secondary">
                    {customFeatures.map((f, i) => (
                      <li key={`custom-${i}`}>{f}</li>
                    ))}
                    {categoryAttrs.map(({ key, value }) => (
                      <li key={key}>{key}: {value}</li>
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
