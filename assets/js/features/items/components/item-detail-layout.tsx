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
  /** Mobile header (back button, share, etc.) -- consumer should apply lg:hidden */
  mobileHeader?: React.ReactNode;
  /** Desktop breadcrumb / banner -- consumer should apply hidden lg:block */
  desktopHeader?: React.ReactNode;
  /** Action area: bid section (public) or publish button (preview) -- in right column desktop, inline mobile */
  actionArea?: React.ReactNode;
  /** Content sections for desktop left column (below gallery) */
  contentSections?: React.ReactNode;
  /** Content sections for mobile (below action area). Falls back to contentSections if not provided. */
  mobileContentSections?: React.ReactNode;
  /** Footer: similar items, etc. */
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
  mobileContentSections,
  footer,
}: ItemDetailLayoutProps) {
  return (
    <>
      {/* Mobile header */}
      {mobileHeader}

      {/* Desktop header */}
      {desktopHeader}

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
              {/* Item header info */}
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

              {/* Price */}
              {price && (
                <div>
                  <p className="text-xs text-content-tertiary">{priceLabel}</p>
                  <p className="text-2xl font-bold text-content">{formatNaira(price)}</p>
                </div>
              )}

              {actionArea}
            </div>
          </div>
        </div>

        {/* Mobile: single-column stacked layout */}
        <div className="space-y-6 lg:hidden">
          <ItemImageGallery title={title} images={images} />

          {/* Item header */}
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

          {/* Price */}
          {price && (
            <div>
              <p className="text-xs text-content-tertiary">{priceLabel}</p>
              <p className="text-xl font-bold text-content">{formatNaira(price)}</p>
            </div>
          )}

          {actionArea}
          {mobileContentSections ?? contentSections}
          {footer}
        </div>
      </div>
    </>
  );
}
