import { Head, Link } from "@inertiajs/react";
import {
  ArrowLeft,
  Share2,
  Heart,
  ChevronRight,
  Eye,
} from "lucide-react";
import type { ItemDetail, HomepageItemCard } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { CountdownTimer } from "@/components/shared/countdown-timer";
import { ConditionBadge } from "@/components/items/condition-badge";
import { ItemImageGallery } from "@/components/items/item-image-gallery";
import { BidSection } from "@/components/items/bid-section";
import { ItemDetailTabs } from "@/components/items/item-detail-tabs";
import { SellerCard } from "@/components/items/seller-card";
import { SimilarItems } from "@/components/items/similar-items";

interface ShowProps {
  item: ItemDetail[number];
  similar_items: HomepageItemCard;
}

export default function Show({
  item,
  similar_items = [],
}: ShowProps) {
  const price = item.currentPrice || item.startingPrice;

  return (
    <>
      <Head title={item.title} />

      {/* Mobile header */}
      <div className="flex items-center justify-between px-4 py-3 lg:hidden">
        <button
          onClick={() => window.history.back()}
          className="flex size-9 items-center justify-center rounded-full border border-neutral-06"
        >
          <ArrowLeft className="size-4 text-neutral-02" />
        </button>
        <span className="text-sm font-medium text-neutral-02">
          {item.category?.name || "Item"}
        </span>
        <div className="flex gap-2">
          <button className="flex size-9 items-center justify-center rounded-full border border-neutral-06">
            <Share2 className="size-4 text-neutral-02" />
          </button>
          <button className="flex size-9 items-center justify-center rounded-full border border-neutral-06">
            <Heart className="size-4 text-neutral-02" />
          </button>
        </div>
      </div>

      {/* Desktop breadcrumb */}
      <div className="hidden px-10 pt-6 lg:block">
        <nav className="flex items-center gap-1.5 text-xs text-neutral-04">
          <Link href="/" className="hover:text-neutral-02">
            Home
          </Link>
          <ChevronRight className="size-3" />
          {item.category && (
            <>
              <span className="hover:text-neutral-02">
                {item.category.name}
              </span>
              <ChevronRight className="size-3" />
            </>
          )}
          <span className="text-neutral-02">{item.title}</span>
        </nav>
      </div>

      {/* Main content */}
      <div className="px-4 py-4 lg:px-10 lg:py-6">
        {/* Desktop: two-column layout */}
        <div className="hidden gap-10 lg:flex">
          {/* Left column */}
          <div className="min-w-0 flex-1 space-y-8">
            <ItemImageGallery title={item.title} />
            <SellerCard seller={item.user} />
            <ItemDetailTabs description={item.description} />
            <SimilarItems items={similar_items} />
          </div>

          {/* Right column - sticky */}
          <div className="w-[440px] shrink-0">
            <div className="sticky top-24 space-y-5">
              {/* Item header info */}
              <div className="space-y-3">
                <ConditionBadge condition={item.condition} />
                <h1 className="font-heading text-xl font-semibold text-neutral-01">
                  {item.title}
                </h1>
                <div className="flex items-center gap-3 text-xs text-neutral-04">
                  {item.endTime && (
                    <CountdownTimer endTime={item.endTime} />
                  )}
                  {item.viewCount != null && item.viewCount > 0 && (
                    <span className="inline-flex items-center gap-1">
                      <Eye className="size-3" />
                      {item.viewCount} views
                    </span>
                  )}
                </div>
              </div>

              {/* Current price */}
              <div>
                <p className="text-xs text-neutral-04">Current Price</p>
                <p className="text-2xl font-bold text-neutral-01">
                  {formatNaira(price)}
                </p>
              </div>

              <BidSection
                itemId={item.id}
                itemTitle={item.title}
                currentPrice={item.currentPrice}
                startingPrice={item.startingPrice}
                bidIncrement={item.bidIncrement}
                bidCount={item.bidCount}
              />
            </div>
          </div>
        </div>

        {/* Mobile: single-column stacked layout */}
        <div className="space-y-6 lg:hidden">
          <ItemImageGallery title={item.title} />

          {/* Item header */}
          <div className="space-y-2">
            <ConditionBadge condition={item.condition} />
            <h1 className="font-heading text-lg font-semibold text-neutral-01">
              {item.title}
            </h1>
            <div className="flex items-center gap-3 text-xs text-neutral-04">
              {item.endTime && <CountdownTimer endTime={item.endTime} />}
              {item.viewCount != null && item.viewCount > 0 && (
                <span className="inline-flex items-center gap-1">
                  <Eye className="size-3" />
                  {item.viewCount} views
                </span>
              )}
            </div>
          </div>

          {/* Current price */}
          <div>
            <p className="text-xs text-neutral-04">Current Price</p>
            <p className="text-xl font-bold text-neutral-01">
              {formatNaira(price)}
            </p>
          </div>

          <BidSection
            itemId={item.id}
            currentPrice={item.currentPrice}
            startingPrice={item.startingPrice}
            bidIncrement={item.bidIncrement}
            bidCount={item.bidCount}
          />

          <ItemDetailTabs description={item.description} />
          <SellerCard seller={item.user} />
          <SimilarItems items={similar_items} />
        </div>
      </div>
    </>
  );
}
