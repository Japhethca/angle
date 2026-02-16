import { Link, router } from "@inertiajs/react";
import { Star, Gavel, Heart } from "lucide-react";
import type { WatchlistItemCard as WatchlistItemCardType } from "@/ash_rpc";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { ConditionBadge } from "@/features/items";
import { useWatchlistToggle } from "@/features/watchlist";
import { formatNaira } from "@/lib/format";

export type WatchlistItem = WatchlistItemCardType[number];

interface WatchlistItemCardProps {
  item: WatchlistItem;
  watchlistEntryId?: string | null;
}

function isEndingSoon(endTime: string): boolean {
  const total = new Date(endTime).getTime() - Date.now();
  return total > 0 && total < 2 * 60 * 60 * 1000; // < 2 hours
}

export function WatchlistItemCard({ item, watchlistEntryId }: WatchlistItemCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const endingSoon = item.endTime ? isEndingSoon(item.endTime) : false;
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId: watchlistEntryId ?? null,
    onRemove: () => router.reload({ only: ["items", "watchlisted_map"] }),
  });

  return (
    <div className="flex flex-col lg:flex-row lg:gap-6">
      {/* Image */}
      <Link href={itemUrl} className="relative shrink-0">
        <div className="aspect-square w-full overflow-hidden rounded-2xl bg-surface-muted lg:h-[304px] lg:w-[304px]">
          <div className="flex h-full items-center justify-center text-content-placeholder">
            <Gavel className="size-12 lg:size-16" />
          </div>
        </div>
        <button
          className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-white/30 bg-white/20 backdrop-blur-sm transition-colors hover:bg-white/40"
          disabled={isPending}
          onClick={(e) => {
            e.preventDefault();
            e.stopPropagation();
            toggle();
          }}
        >
          <Heart
            className={`size-4 ${isWatchlisted ? "fill-red-500 text-red-500" : "text-white"}`}
          />
        </button>
      </Link>

      {/* Details */}
      <div className="flex flex-1 flex-col justify-between gap-3 pt-3 lg:py-2 lg:pt-0">
        <div className="space-y-2">
          {/* Title */}
          <Link href={itemUrl}>
            <h3 className="line-clamp-1 text-lg text-content lg:text-xl">
              {item.title}
            </h3>
          </Link>

          {/* Price */}
          <p className="text-lg font-bold text-content lg:text-xl">
            {formatNaira(price)}
          </p>

          {/* Time left */}
          {item.endTime && (
            endingSoon ? (
              <div className="inline-flex items-center gap-1.5 rounded-full bg-feedback-error-muted px-3 py-1 text-xs font-medium text-feedback-error">
                <span>Time left: </span>
                <CountdownTimer
                  endTime={item.endTime}
                  className="text-feedback-error"
                />
              </div>
            ) : (
              <div className="flex items-center gap-1.5 text-sm text-content-tertiary">
                <span>Time left:</span>
                <CountdownTimer
                  endTime={item.endTime}
                  className="text-sm text-content"
                />
              </div>
            )
          )}

          {/* Condition */}
          <div className="flex items-center gap-2">
            <span className="text-sm text-content-tertiary">Condition:</span>
            <ConditionBadge condition={item.condition} />
          </div>

          {/* Stats */}
          <div className="flex items-center gap-1 text-sm text-content-tertiary">
            {item.bidCount > 0 && (
              <span>
                {item.bidCount} {item.bidCount === 1 ? "bid" : "bids"}
              </span>
            )}
            {item.bidCount > 0 && item.watcherCount > 0 && (
              <span>&middot;</span>
            )}
            {item.watcherCount > 0 && (
              <span>{item.watcherCount} watching</span>
            )}
          </div>

          {/* Vendor */}
          {item.user?.fullName && (
            <div className="flex items-center gap-1 text-sm">
              <span className="text-content-tertiary">Vendor:</span>
              <span className="text-content">{item.user.fullName}</span>
              <Star className="ml-1 size-3.5 fill-amber-400 text-amber-400" />
              <span className="text-content">5</span>
            </div>
          )}
        </div>

        {/* Bid button */}
        <div>
          <Link
            href={itemUrl}
            className="inline-flex w-full items-center justify-center rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-600/90 lg:w-auto lg:min-w-[160px]"
          >
            Bid
          </Link>
        </div>
      </div>
    </div>
  );
}
