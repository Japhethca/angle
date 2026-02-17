import { Link } from "@inertiajs/react";
import { Heart, Clock, Gavel } from "lucide-react";
import { ResponsiveImage } from "@/components/image-upload";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { useAuthGuard } from "@/features/auth";
import { useWatchlistToggle } from "@/features/watchlist";
import type { CategoryItem } from "./category-item-card";

interface CategoryItemListCardProps {
  item: CategoryItem;
  watchlistEntryId?: string | null;
}

export function CategoryItemListCard({ item, watchlistEntryId = null }: CategoryItemListCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard, authenticated } = useAuthGuard();
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId,
  });

  return (
    <div className="flex gap-3 border-b border-subtle pb-4">
      {/* Thumbnail */}
      <Link href={itemUrl} className="shrink-0">
        <div className="relative size-[100px] overflow-hidden rounded-lg bg-surface-muted">
          {item.coverImage ? (
            <ResponsiveImage
              image={item.coverImage}
              sizes="100px"
              alt={item.title}
            />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-8" />
            </div>
          )}
        </div>
      </Link>

      {/* Details */}
      <div className="flex min-w-0 flex-1 flex-col justify-between">
        <div>
          <Link href={itemUrl}>
            <h3 className="line-clamp-1 text-base text-content-tertiary">{item.title}</h3>
          </Link>
          <p className="mt-0.5 text-base font-bold text-content">
            {formatNaira(price)}
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs">
          {item.endTime && (
            <span className="inline-flex items-center gap-1 rounded-full bg-feedback-error-muted px-2 py-0.5 font-medium text-feedback-error">
              <Clock className="size-3" />
              <CountdownTimer endTime={item.endTime} className="text-feedback-error" />
            </span>
          )}
          {item.bidCount > 0 && (
            <>
              <span className="text-content-placeholder">&middot;</span>
              <span className="text-content-tertiary">{item.bidCount} bids</span>
            </>
          )}
        </div>
      </div>

      {/* Actions */}
      <div className="flex shrink-0 flex-col items-end justify-between">
        <button
          className="flex size-8 items-center justify-center rounded-full border border-subtle text-content-tertiary transition-colors hover:bg-surface-muted"
          disabled={isPending}
          onClick={() => {
            if (authenticated) {
              toggle();
            } else {
              guard(itemUrl);
            }
          }}
        >
          <Heart className={`size-3.5 ${isWatchlisted ? "fill-red-500 text-red-500" : ""}`} />
        </button>
        <Link
          href={itemUrl}
          className="flex items-center gap-1.5 rounded-full bg-primary-600 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-primary-600/90"
        >
          <Gavel className="size-3" />
          Bid
        </Link>
      </div>
    </div>
  );
}
