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
} from "@/features/items";
import { BidSection } from "@/features/bidding";
import { useWatchlistToggle } from "@/features/watchlist/hooks/use-watchlist-toggle";
import { toast } from "sonner";

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
    onAdd: () => toast.success("Added to your watchlist"),
    onRemove: () => toast.success("Removed from your watchlist"),
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
              <button
                onClick={toggleWatch}
                disabled={isWatchPending}
                className="flex size-9 items-center justify-center rounded-full border border-strong"
              >
                <Heart
                  className={`size-4 ${isWatchlisted ? "fill-red-500 text-red-500" : "text-content"}`}
                />
              </button>
            </div>
          </div>
        }
        desktopHeader={
          <div className="hidden px-8 pt-5 lg:block">
            <nav className="flex items-center gap-1.5 text-xs text-content-tertiary">
              <Link href="/" className="hover:text-content">
                Home
              </Link>
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
        mobileContentSections={
          <>
            <ItemDetailTabs description={item.description} />
            <SellerCard seller={item.user} />
          </>
        }
        footer={<SimilarItems items={similar_items} />}
      />
    </>
  );
}
