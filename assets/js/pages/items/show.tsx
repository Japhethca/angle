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
import { CountdownTimer } from "@/shared/components/countdown-timer";
import {
  ConditionBadge,
  ItemImageGallery,
  ItemDetailTabs,
  SellerCard,
  SimilarItems,
} from "@/features/items";
import { BidSection } from "@/features/bidding";

interface Seller {
  id: string;
  fullName: string | null;
  username?: string | null;
  publishedItemCount?: number | null;
}

interface ShowProps {
  item: ItemDetail[number] & { user: Seller | null };
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
          className="flex size-9 items-center justify-center rounded-full border border-strong"
        >
          <ArrowLeft className="size-4 text-content" />
        </button>
        <span className="text-sm font-medium text-content">
          {item.category?.name || "Item"}
        </span>
        <div className="flex gap-2">
          <button className="flex size-9 items-center justify-center rounded-full border border-strong">
            <Share2 className="size-4 text-content" />
          </button>
          <button className="flex size-9 items-center justify-center rounded-full border border-strong">
            <Heart className="size-4 text-content" />
          </button>
        </div>
      </div>

      {/* Desktop breadcrumb */}
      <div className="hidden px-10 pt-6 lg:block">
        <nav className="flex items-center gap-1.5 text-xs text-content-tertiary">
          <Link href="/" className="hover:text-content">
            Home
          </Link>
          <ChevronRight className="size-3" />
          {item.category && (
            <>
              <span className="hover:text-content">
                {item.category.name}
              </span>
              <ChevronRight className="size-3" />
            </>
          )}
          <span className="text-content">{item.title}</span>
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
                <h1 className="font-heading text-xl font-semibold text-content">
                  {item.title}
                </h1>
                <div className="flex items-center gap-3 text-xs text-content-tertiary">
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
                <p className="text-xs text-content-tertiary">Current Price</p>
                <p className="text-2xl font-bold text-content">
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
            <h1 className="font-heading text-lg font-semibold text-content">
              {item.title}
            </h1>
            <div className="flex items-center gap-3 text-xs text-content-tertiary">
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
            <p className="text-xs text-content-tertiary">Current Price</p>
            <p className="text-xl font-bold text-content">
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
