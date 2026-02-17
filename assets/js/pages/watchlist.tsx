import { Head, router } from '@inertiajs/react';
import { ChevronDown, Search, SlidersHorizontal } from 'lucide-react';
import type { WatchlistItemCard as WatchlistItemCardType } from '@/ash_rpc';
import { EmptyWatchlist, WatchlistItemCard, WatchlistCategorySidebar } from '@/features/watchlist';

interface Category {
  id: string;
  name: string;
  slug: string;
}

interface WatchlistProps {
  items: WatchlistItemCardType;
  categories: Category[];
  active_category: string | null;
  watchlisted_map: Record<string, string>;
}

export default function Watchlist({
  items = [],
  categories = [],
  active_category = null,
  watchlisted_map = {},
}: WatchlistProps) {
  const isEmpty = items.length === 0;
  const isFiltered = active_category !== null;

  // Empty state: no items and no active filter
  if (isEmpty && !isFiltered) {
    return (
      <>
        <Head title="Watchlist" />
        <EmptyWatchlist />
      </>
    );
  }

  const activeCategoryName = categories.find(c => c.id === active_category)?.name ?? 'All';

  const itemsContent =
    isEmpty && isFiltered ? (
      <div className="flex min-h-[40vh] flex-col items-center justify-center rounded-2xl border border-subtle bg-surface px-4 py-16">
        <Search className="mb-4 size-12 text-content-placeholder" />
        <p className="text-base font-medium text-content">No items found in this category</p>
        <p className="mt-1 text-sm text-content-tertiary">
          Try selecting a different category or browse all items.
        </p>
        <button
          type="button"
          onClick={() => router.visit('/watchlist')}
          className="mt-4 rounded-full border-[1.2px] border-content px-5 py-2 text-sm font-medium text-content transition-colors hover:bg-surface-muted"
        >
          View All
        </button>
      </div>
    ) : (
      <div className="flex flex-col gap-10">
        {items.map(item => (
          <WatchlistItemCard
            key={item.id}
            item={item}
            watchlistEntryId={watchlisted_map[item.id] ?? null}
          />
        ))}
      </div>
    );

  return (
    <>
      <Head title="Watchlist" />

      {/* Desktop: sidebar + content */}
      <div className="hidden lg:flex lg:gap-10 lg:px-10 lg:py-6">
        <aside className="w-[240px] shrink-0">
          <WatchlistCategorySidebar categories={categories} activeCategory={active_category} />
        </aside>

        <div className="min-w-0 flex-1">
          <div className="mb-6 flex items-center">
            <h1 className="text-xl font-bold text-content">Watchlist</h1>
          </div>

          {itemsContent}
        </div>
      </div>

      {/* Mobile: content */}
      <div className="px-4 pb-6 pt-4 lg:hidden">
        <div className="mb-4 flex items-center gap-3">
          <h1 className="text-2xl font-bold text-content">Watchlist</h1>
          <div className="ml-auto flex items-center gap-2">
            <button
              type="button"
              aria-label="Search watchlist"
              className="flex size-10 items-center justify-center rounded-full bg-surface-muted"
            >
              <Search className="size-5 text-content-tertiary" />
            </button>
            <button
              type="button"
              onClick={() => {
                // Cycle through: All -> first category -> ... -> All
                if (!active_category) {
                  if (categories.length > 0) {
                    router.visit(`/watchlist?category=${categories[0].id}`);
                  }
                } else {
                  const currentIndex = categories.findIndex(c => c.id === active_category);
                  const nextIndex = currentIndex + 1;
                  if (nextIndex < categories.length) {
                    router.visit(`/watchlist?category=${categories[nextIndex].id}`);
                  } else {
                    router.visit('/watchlist');
                  }
                }
              }}
              className="flex items-center gap-2 rounded-full border border-subtle bg-surface px-4 py-2 text-sm font-medium text-content"
            >
              <SlidersHorizontal className="size-4" />
              {activeCategoryName}
              <ChevronDown className="size-4 text-content-tertiary" />
            </button>
          </div>
        </div>

        {itemsContent}
      </div>
    </>
  );
}
