import { Head, router } from "@inertiajs/react";
import { Search } from "lucide-react";
import type { WatchlistItemCard as WatchlistItemCardType } from "@/ash_rpc";
import {
  EmptyWatchlist,
  WatchlistItemCard,
  WatchlistCategorySidebar,
} from "@/features/watchlist";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

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

  function handleMobileCategoryChange(value: string) {
    if (value === "all") {
      router.visit("/watchlist");
    } else {
      router.visit(`/watchlist?category=${value}`);
    }
  }

  return (
    <>
      <Head title="Watchlist" />

      <div className="mx-auto max-w-7xl px-4 py-6 lg:py-8">
        {/* Desktop layout: sidebar + content */}
        <div className="flex gap-8">
          {/* Sidebar - desktop only */}
          <aside className="hidden w-60 shrink-0 lg:block">
            <WatchlistCategorySidebar
              categories={categories}
              activeCategory={active_category}
            />
          </aside>

          {/* Main content */}
          <div className="min-w-0 flex-1">
            {/* Header */}
            <div className="mb-6 flex items-center justify-between">
              <h1 className="text-2xl font-bold text-content">
                Watchlist{" "}
                {items.length > 0 && (
                  <span className="text-content-tertiary">
                    ({items.length})
                  </span>
                )}
              </h1>
            </div>

            {/* Mobile category filter */}
            <div className="mb-4 lg:hidden">
              <Select
                value={active_category ?? "all"}
                onValueChange={handleMobileCategoryChange}
              >
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Filter by category" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">All Categories</SelectItem>
                  {categories.map((category) => (
                    <SelectItem key={category.id} value={category.id}>
                      {category.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            {/* Items list or filtered empty state */}
            {isEmpty && isFiltered ? (
              <div className="flex min-h-[40vh] flex-col items-center justify-center rounded-2xl border border-subtle bg-white px-4 py-16">
                <Search className="mb-4 size-12 text-content-placeholder" />
                <p className="text-base font-medium text-content">
                  No items found in this category
                </p>
                <p className="mt-1 text-sm text-content-tertiary">
                  Try selecting a different category or browse all items.
                </p>
                <button
                  type="button"
                  onClick={() => router.visit("/watchlist")}
                  className="mt-4 rounded-lg border border-strong px-5 py-2 text-sm font-medium text-content transition-colors hover:bg-surface-muted"
                >
                  View All
                </button>
              </div>
            ) : (
              <div className="flex flex-col gap-4">
                {items.map((item) => (
                  <WatchlistItemCard key={item.id} item={item} watchlistEntryId={watchlisted_map[item.id] ?? null} />
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
