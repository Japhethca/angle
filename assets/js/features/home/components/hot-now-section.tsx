import { Link } from "@inertiajs/react";
import { Heart, Gavel } from "lucide-react";
import type { HomepageItemCard } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";
import { ResponsiveImage } from "@/components/image-upload";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { ItemCard } from "@/features/items";
import { useAuthGuard } from "@/features/auth";
import { useWatchlistToggle } from "@/features/watchlist";

type Item = HomepageItemCard[number] & { coverImage?: ImageData | null };

interface HotNowSectionProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

function LargeTile({ item, watchlistEntryId }: { item: Item; watchlistEntryId: string | null }) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard, authenticated } = useAuthGuard();
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({
    itemId: item.id,
    watchlistEntryId,
  });

  return (
    <div className="relative overflow-hidden rounded-2xl bg-surface-muted">
      <Link href={itemUrl} className="block">
        <div className="relative aspect-[4/5]">
          {item.coverImage ? (
            <ResponsiveImage
              image={item.coverImage}
              sizes="(max-width: 1024px) 100vw, 50vw"
              alt={item.title}
            />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-16" />
            </div>
          )}

          {/* Gradient overlay */}
          <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent" />

          {/* Fire badge */}
          <div className="absolute left-3 top-3 text-2xl">🔥</div>

          {/* Watchlist heart */}
          <button
            aria-label={isWatchlisted ? 'Remove from watchlist' : 'Add to watchlist'}
            className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-white/20 bg-black/20 backdrop-blur-sm transition-colors hover:bg-black/30"
            disabled={isPending}
            onClick={e => {
              e.preventDefault();
              e.stopPropagation();
              if (authenticated) toggle();
              else guard(itemUrl);
            }}
          >
            <Heart className={`size-4 ${isWatchlisted ? 'fill-red-500 text-red-500' : 'text-white'}`} />
          </button>

          {/* Item details overlay at bottom */}
          <div className="absolute bottom-0 left-0 right-0 p-4 lg:p-6">
            <h3 className="line-clamp-2 text-lg font-semibold text-white lg:text-xl">{item.title}</h3>
            <div className="mt-2 flex items-center gap-3">
              <span className="text-base font-bold text-white">{formatNaira(price)}</span>
              {item.endTime && (
                <CountdownTimer endTime={item.endTime} className="text-white/80" />
              )}
            </div>
          </div>
        </div>
      </Link>
    </div>
  );
}

export function HotNowSection({ items, watchlistedMap = {} }: HotNowSectionProps) {
  if (items.length === 0) {
    return (
      <section className="px-4 py-10 lg:px-10 lg:py-12">
        <h2 className="mb-6 font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Hot Now
        </h2>
        <div className="flex h-48 items-center justify-center rounded-xl bg-surface-muted">
          <p className="text-sm text-content-tertiary">No hot items right now</p>
        </div>
      </section>
    );
  }

  const [featured, ...rest] = items;
  const smallItems = rest.slice(0, 4);

  return (
    <section className="px-4 py-10 lg:px-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Hot Now
        </h2>
        <Link
          href="/search?sort=view_count_desc"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All
        </Link>
      </div>

      {/* Desktop mosaic: hidden on mobile */}
      <div className="hidden lg:grid lg:grid-cols-2 lg:gap-6">
        <LargeTile
          item={featured}
          watchlistEntryId={watchlistedMap[featured.id] ?? null}
        />
        <div className="grid grid-cols-2 gap-6">
          {smallItems.map((item) => (
            <ItemCard
              key={item.id}
              item={item}
              badge="hot-now"
              watchlistEntryId={watchlistedMap[item.id] ?? null}
            />
          ))}
        </div>
      </div>

      {/* Mobile: horizontal scroll */}
      <div className="scrollbar-hide flex gap-4 overflow-x-auto pb-4 lg:hidden">
        {items.map((item) => (
          <ItemCard
            key={item.id}
            item={item}
            badge="hot-now"
            watchlistEntryId={watchlistedMap[item.id] ?? null}
          />
        ))}
      </div>
    </section>
  );
}
