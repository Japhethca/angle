import { useState } from "react";
import { Pencil } from "lucide-react";
import { toast } from "sonner";
import { updateDraftItem, publishItem, buildCSRFHeaders } from "@/ash_rpc";
import { Button } from "@/components/ui/button";
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
    .filter(([key, val]) => key !== "_customFeatures" && val)
    .map(([key, val]) => `${key}: ${val}`);

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
        throw new Error(updateResult.errors.map((e: any) => e.message).join("; "));
      }

      // Publish the item
      const publishResult = await publishItem({
        identity: draftItemId,
        headers: buildCSRFHeaders(),
      });

      if (!publishResult.success) {
        throw new Error(publishResult.errors.map((e: any) => e.message).join("; "));
      }

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
          &#x20A6;{Number(auctionInfo.startingPrice).toLocaleString()}
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
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
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
