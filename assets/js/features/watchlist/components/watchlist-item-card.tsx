import { Link, router } from "@inertiajs/react";
import { Clock, Gavel, Eye, Heart } from "lucide-react";
import type { WatchlistItemCard as WatchlistItemCardType } from "@/ash_rpc";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { ConditionBadge } from "@/features/items";
import { formatNaira } from "@/lib/format";
import { useWatchlistToggle } from "@/features/watchlist";

export type WatchlistItem = WatchlistItemCardType[number];

interface WatchlistItemCardProps {
  item: WatchlistItem;
  watchlistEntryId?: string | null;
}

export function WatchlistItemCard({ item, watchlistEntryId = null }: WatchlistItemCardProps) {
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId,
    onRemove: () => router.reload(),
  });
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;

  return (
    <div className="flex flex-col overflow-hidden rounded-2xl border border-subtle bg-white lg:flex-row">
      {/* Image */}
      <div className="relative shrink-0">
        <Link href={itemUrl}>
          <div className="aspect-[4/3] w-full overflow-hidden bg-surface-muted lg:aspect-auto lg:h-[200px] lg:w-[300px]">
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-12 lg:size-16" />
            </div>
          </div>
        </Link>
        <button
          className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-white/30 bg-white/20 backdrop-blur-sm transition-colors hover:bg-white/40"
          disabled={isPending}
          onClick={toggle}
          aria-label={isWatchlisted ? "Remove from watchlist" : "Add to watchlist"}
        >
          <Heart
            className={`size-4 ${isWatchlisted ? "fill-red-500 text-red-500" : "text-content-tertiary"}`}
          />
        </button>
      </div>

      {/* Details */}
      <div className="flex flex-1 flex-col justify-between gap-3 p-4 lg:p-5">
        <div className="space-y-2">
          {/* Title */}
          <Link href={itemUrl}>
            <h3 className="line-clamp-1 text-base font-semibold text-content lg:text-lg">
              {item.title}
            </h3>
          </Link>

          {/* Price */}
          <p className="text-lg font-bold text-content lg:text-xl">
            {formatNaira(price)}
          </p>

          {/* Time left */}
          {item.endTime && (
            <div className="inline-flex items-center gap-1.5 rounded-full bg-feedback-error-muted px-3 py-1 text-xs font-medium text-feedback-error">
              <Clock className="size-3" />
              <span>Time left: </span>
              <CountdownTimer
                endTime={item.endTime}
                className="text-feedback-error"
              />
            </div>
          )}

          {/* Condition badge */}
          <div>
            <ConditionBadge condition={item.condition} />
          </div>

          {/* Stats */}
          <div className="flex items-center gap-2 text-xs text-content-tertiary">
            {item.bidCount > 0 && (
              <span className="inline-flex items-center gap-1">
                <Gavel className="size-3" />
                {item.bidCount} {item.bidCount === 1 ? "bid" : "bids"}
              </span>
            )}
            {item.bidCount > 0 && item.watcherCount > 0 && (
              <span className="text-content-placeholder">&middot;</span>
            )}
            {item.watcherCount > 0 && (
              <span className="inline-flex items-center gap-1">
                <Eye className="size-3" />
                {item.watcherCount} watching
              </span>
            )}
          </div>

          {/* Vendor */}
          {item.user?.fullName && (
            <p className="text-xs text-content-tertiary">
              Vendor: {item.user.fullName}
            </p>
          )}
        </div>

        {/* Bid button */}
        <div>
          <Link
            href={itemUrl}
            className="inline-flex items-center justify-center gap-2 rounded-lg bg-primary-600 px-6 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-600/90"
          >
            <Gavel className="size-4" />
            Bid
          </Link>
        </div>
      </div>
    </div>
  );
}
