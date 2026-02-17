import { useState } from 'react';
import { Link } from '@inertiajs/react';
import { ChevronLeft, ChevronRight, Gavel, Eye, Heart } from 'lucide-react';
import type { HomepageItemCard } from '@/ash_rpc';
import { CountdownTimer } from '@/shared/components/countdown-timer';
import { formatNaira } from '@/lib/format';
import { useAuthGuard } from '@/features/auth';
import { useWatchlistToggle } from '@/features/watchlist';

type Item = HomepageItemCard[number];

interface FeaturedItemCarouselProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

function WatchButton({
  itemId,
  watchlistEntryId,
}: {
  itemId: string;
  watchlistEntryId: string | null;
}) {
  const { guard, authenticated } = useAuthGuard();
  const { isWatchlisted, isPending, toggle } = useWatchlistToggle({ itemId, watchlistEntryId });

  return (
    <button
      disabled={isPending}
      onClick={() => {
        if (authenticated) {
          toggle();
        } else {
          guard(`/items/${itemId}`);
        }
      }}
      className={`flex items-center gap-2 rounded-full border px-6 py-2.5 text-sm font-medium transition-colors ${
        isWatchlisted
          ? 'border-red-200 bg-red-50 text-red-600'
          : 'border-strong bg-surface text-content hover:bg-surface-muted'
      }`}
    >
      <Heart className={`size-4 ${isWatchlisted ? 'fill-red-500' : ''}`} />
      {isWatchlisted ? 'Watching' : 'Watch'}
    </button>
  );
}

export function FeaturedItemCarousel({ items, watchlistedMap = {} }: FeaturedItemCarouselProps) {
  const [currentIndex, setCurrentIndex] = useState(0);

  if (items.length === 0) {
    return (
      <section className="bg-surface-muted px-4 py-10 lg:px-10 lg:py-12">
        <div className="flex aspect-[4/3] flex-col items-center justify-center rounded-2xl bg-surface-secondary lg:aspect-[21/9]">
          <Gavel className="mb-3 size-12 text-content-placeholder" />
          <p className="text-sm text-content-tertiary">No featured items yet</p>
        </div>
      </section>
    );
  }

  const activeItem = items[currentIndex];
  const itemUrl = `/items/${activeItem.slug || activeItem.id}`;
  const price = activeItem.currentPrice || activeItem.startingPrice;

  const goPrev = () => setCurrentIndex(i => (i === 0 ? items.length - 1 : i - 1));
  const goNext = () => setCurrentIndex(i => (i === items.length - 1 ? 0 : i + 1));

  return (
    <section className="bg-surface-muted">
      <div className="px-4 py-8 lg:px-10 lg:py-12">
        {/* Desktop layout */}
        <div className="hidden lg:block">
          <div className="relative">
            {/* Large product image area */}
            <div className="relative mx-auto aspect-[16/7] max-w-full overflow-hidden rounded-2xl bg-surface-secondary">
              <div className="flex h-full items-center justify-center text-content-placeholder">
                <Gavel className="size-24" />
              </div>

              {/* Navigation arrows */}
              <button
                onClick={goPrev}
                className="absolute left-4 top-1/2 flex size-10 -translate-y-1/2 items-center justify-center rounded-full bg-surface-emphasis shadow-md transition-colors hover:bg-surface-muted"
              >
                <ChevronLeft className="size-5 text-content" />
              </button>
              <button
                onClick={goNext}
                className="absolute right-4 top-1/2 flex size-10 -translate-y-1/2 items-center justify-center rounded-full bg-surface-emphasis shadow-md transition-colors hover:bg-surface-muted"
              >
                <ChevronRight className="size-5 text-content" />
              </button>
            </div>

            {/* Item details below image */}
            <div className="mt-6 flex items-end justify-between">
              <div className="space-y-2">
                <Link href={itemUrl}>
                  <h2 className="font-heading text-[28px] font-semibold text-content">
                    {activeItem.title}
                  </h2>
                </Link>
                <div className="flex items-center gap-3 text-sm text-content-tertiary">
                  <span>Uploaded 346</span>
                  <span>•</span>
                  <span className="font-semibold text-content">{formatNaira(price)}</span>
                </div>
                {activeItem.endTime && (
                  <div className="flex items-center gap-2 text-sm text-content-tertiary">
                    <Eye className="size-4" />
                    <span>{activeItem.viewCount || 0} views</span>
                    <span>•</span>
                    <CountdownTimer endTime={activeItem.endTime} />
                  </div>
                )}
              </div>

              {/* CTA buttons */}
              <div className="flex items-center gap-3">
                <WatchButton
                  key={activeItem.id}
                  itemId={activeItem.id}
                  watchlistEntryId={watchlistedMap[activeItem.id] ?? null}
                />
                <Link
                  href={itemUrl}
                  className="flex items-center gap-2 rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white transition-colors hover:bg-primary-600/90"
                >
                  Bid
                  <ChevronRight className="size-4" />
                </Link>
              </div>
            </div>
          </div>
        </div>

        {/* Mobile layout */}
        <div className="lg:hidden">
          <div className="relative aspect-[4/3] overflow-hidden rounded-2xl bg-surface-secondary">
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-16" />
            </div>

            {/* Arrows at bottom */}
            <div className="absolute bottom-4 right-4 flex gap-2">
              <button
                onClick={goPrev}
                className="flex size-8 items-center justify-center rounded-full bg-surface/80 shadow-md backdrop-blur-sm"
              >
                <ChevronLeft className="size-4 text-content" />
              </button>
              <button
                onClick={goNext}
                className="flex size-8 items-center justify-center rounded-full bg-surface/80 shadow-md backdrop-blur-sm"
              >
                <ChevronRight className="size-4 text-content" />
              </button>
            </div>
          </div>

          {/* Item details below */}
          <div className="mt-4 space-y-3">
            <Link href={itemUrl}>
              <h2 className="font-heading text-xl font-semibold text-content">
                {activeItem.title}
              </h2>
            </Link>
            <div className="flex items-center gap-2 text-sm text-content-tertiary">
              <span className="font-semibold text-content">{formatNaira(price)}</span>
              {activeItem.endTime && (
                <>
                  <span>•</span>
                  <CountdownTimer endTime={activeItem.endTime} />
                </>
              )}
            </div>

            <div className="flex gap-3">
              <div className="flex-1">
                <WatchButton
                  key={activeItem.id}
                  itemId={activeItem.id}
                  watchlistEntryId={watchlistedMap[activeItem.id] ?? null}
                />
              </div>
              <Link
                href={itemUrl}
                className="flex flex-1 items-center justify-center gap-2 rounded-full bg-primary-600 py-2.5 text-sm font-medium text-white"
              >
                Bid
                <ChevronRight className="size-4" />
              </Link>
            </div>
          </div>
        </div>

        {/* Dot indicators */}
        {items.length > 1 && (
          <div className="mt-4 flex justify-center gap-1.5">
            {items.map((_, idx) => (
              <button
                key={idx}
                onClick={() => setCurrentIndex(idx)}
                className={`size-2 rounded-full transition-colors ${
                  idx === currentIndex ? 'bg-primary-600' : 'bg-surface-emphasis'
                }`}
              />
            ))}
          </div>
        )}
      </div>
    </section>
  );
}
