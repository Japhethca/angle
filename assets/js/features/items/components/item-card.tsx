import { Link } from "@inertiajs/react";
import { Heart, Clock, Gavel, ArrowRight } from "lucide-react";
import type { HomepageItemCard } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { useAuthGuard, AuthLink } from "@/features/auth";
import { useWatchlistToggle } from "@/features/watchlist";

type ItemCardItem = HomepageItemCard[number] & { coverImage?: ImageData | null };

interface ItemCardProps {
  item: ItemCardItem;
  badge?: 'ending-soon' | 'hot-now';
  watchlistEntryId?: string | null;
}

export function ItemCard({ item, badge, watchlistEntryId = null }: ItemCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard, authenticated } = useAuthGuard();
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId,
  });

  return (
    <div className="w-[85vw] shrink-0 sm:w-[320px] lg:w-[432px]">
      <Link href={itemUrl} className="block">
        {/* Image area */}
        <div className="relative aspect-[9/10] overflow-hidden rounded-2xl bg-surface-muted lg:aspect-[9/10]">
          {/* Image or placeholder */}
          {item.coverImage ? (
            <ResponsiveImage
              image={item.coverImage}
              sizes="(max-width: 640px) 85vw, (max-width: 1024px) 320px, 432px"
              alt={item.title}
            />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-12 lg:size-16" />
            </div>
          )}

          {/* Watchlist heart */}
          <button
            className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-white/20 bg-black/20 backdrop-blur-sm transition-colors hover:bg-black/30"
            disabled={isPending}
            onClick={e => {
              e.preventDefault();
              e.stopPropagation();
              if (authenticated) {
                toggle();
              } else {
                guard(itemUrl);
              }
            }}
          >
            <Heart
              className={`size-4 ${isWatchlisted ? 'fill-red-500 text-red-500' : 'text-white'}`}
            />
          </button>

          {/* Ending soon badge - red left-edge strip */}
          {badge === 'ending-soon' && (
            <div className="absolute bottom-4 left-0 flex items-center gap-1.5 rounded-r-lg bg-feedback-error px-3 py-1.5 text-xs font-medium text-white">
              <Clock className="size-3" />
              Almost gone
            </div>
          )}

          {/* Hot now badge - fire emoji overlay */}
          {badge === 'hot-now' && <div className="absolute left-3 top-3 text-2xl">🔥</div>}
        </div>
      </Link>

      {/* Info below image */}
      <div className="mt-3 space-y-2">
        <div className="flex items-start justify-between gap-2">
          <Link href={itemUrl} className="min-w-0 flex-1">
            <h3 className="line-clamp-1 text-sm text-content-tertiary">{item.title}</h3>
          </Link>
          <p className="shrink-0 text-sm font-bold text-content">{formatNaira(price)}</p>
        </div>

        <div className="flex items-center gap-2 text-xs">
          {item.endTime && (
            <span className="inline-flex items-center gap-1 rounded-full bg-feedback-error-muted px-2.5 py-1 font-medium text-feedback-error">
              <Clock className="size-3" />
              <CountdownTimer endTime={item.endTime} className="text-feedback-error" />
            </span>
          )}
          {item.viewCount > 0 && (
            <>
              <span className="text-content-placeholder">·</span>
              <span className="text-content-tertiary">{item.viewCount} views</span>
            </>
          )}
        </div>

        {/* Bid button for ending-soon cards */}
        {badge === 'ending-soon' && (
          <AuthLink
            href={itemUrl}
            auth
            className="flex w-full items-center justify-center gap-2 rounded-lg bg-primary-600 px-4 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-600/90"
          >
            Bid
            <ArrowRight className="size-4" />
          </AuthLink>
        )}
      </div>
    </div>
  );
}
