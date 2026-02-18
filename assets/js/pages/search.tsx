import { useState, useCallback, useRef, useEffect } from "react";
import { router, Head } from "@inertiajs/react";
import { Search, SlidersHorizontal, X } from "lucide-react";
import { CategoryItemCard, type CategoryItem } from "@/features/items";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Input } from "@/components/ui/input";
import type { SearchItemCard } from "@/ash_rpc";
import type { ImageData } from "@/lib/image-url";

type SearchItem = SearchItemCard[number] & { coverImage?: ImageData | null };

const ALL = "__all__";

interface SearchFilters {
  category: string | null;
  condition: string | null;
  sale_type: string | null;
  auction_status: string | null;
  min_price: string | null;
  max_price: string | null;
  sort: string;
}

interface SearchCategory {
  id: string;
  name: string;
  slug: string;
}

interface Pagination {
  page: number;
  per_page: number;
  total: number;
  total_pages: number;
}

interface SearchPageProps {
  items: SearchItem[];
  query: string;
  pagination: Pagination;
  filters: SearchFilters;
  categories: SearchCategory[];
  watchlisted_map?: Record<string, string>;
}

export default function SearchPage({
  items,
  query,
  pagination,
  filters,
  categories,
  watchlisted_map = {},
}: SearchPageProps) {
  const [searchInput, setSearchInput] = useState(query);
  const [showFilters, setShowFilters] = useState(false);
  const [localMinPrice, setLocalMinPrice] = useState(filters.min_price || "");
  const [localMaxPrice, setLocalMaxPrice] = useState(filters.max_price || "");
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(null);

  // Sync local price state when filters change from server
  useEffect(() => {
    setLocalMinPrice(filters.min_price || "");
    setLocalMaxPrice(filters.max_price || "");
  }, [filters.min_price, filters.max_price]);

  const navigate = useCallback(
    (newParams: Record<string, string | undefined>) => {
      const params: Record<string, string> = {};
      const merged = { ...filters, ...newParams };

      if (newParams.q !== undefined) {
        params.q = newParams.q;
      } else if (query) {
        params.q = query;
      }

      if (merged.category) params.category = merged.category;
      if (merged.condition) params.condition = merged.condition;
      if (merged.sale_type) params.sale_type = merged.sale_type;
      if (merged.auction_status) params.auction_status = merged.auction_status;
      if (merged.min_price) params.min_price = merged.min_price;
      if (merged.max_price) params.max_price = merged.max_price;
      if (merged.sort && merged.sort !== "relevance") params.sort = merged.sort;
      if (newParams.page && newParams.page !== "1") params.page = newParams.page;

      router.get("/search", params, { preserveState: true });
    },
    [filters, query]
  );

  const debouncedNavigate = useCallback(
    (newParams: Record<string, string | undefined>) => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      debounceRef.current = setTimeout(() => navigate(newParams), 400);
    },
    [navigate]
  );

  const clearFilters = () => {
    router.get("/search", query ? { q: query } : {});
  };

  const hasActiveFilters =
    filters.category ||
    filters.condition ||
    filters.sale_type ||
    filters.auction_status ||
    filters.min_price ||
    filters.max_price;

  const handleSearch = (e: React.FormEvent) => {
    e.preventDefault();
    const q = searchInput.trim();
    if (q) navigate({ q, page: undefined });
  };

  /** Convert a select value to a filter param, treating ALL sentinel as undefined */
  const selectToParam = (v: string): string | undefined =>
    v === ALL ? undefined : v;

  return (
    <>
      <Head title={query ? `Search: ${query}` : "Search"} />
      <div className="mx-auto max-w-7xl px-4 py-6 lg:px-10">
        {/* Search bar */}
        <form onSubmit={handleSearch} className="relative mb-6">
          <Search className="absolute left-4 top-1/2 size-5 -translate-y-1/2 text-content-placeholder" />
          <input
            value={searchInput}
            onChange={(e) => setSearchInput(e.target.value)}
            placeholder="Search for items..."
            className="h-12 w-full rounded-xl bg-surface-muted pl-12 pr-4 text-base text-content placeholder:text-content-placeholder outline-none"
          />
        </form>

        {/* Filter bar */}
        <div className="mb-6 flex flex-wrap items-center gap-3">
          <Button
            variant="outline"
            size="sm"
            onClick={() => setShowFilters(!showFilters)}
            className={
              showFilters ? "border-primary-600 text-primary-600" : ""
            }
          >
            <SlidersHorizontal className="mr-2 size-4" />
            Filters
          </Button>

          <Select
            value={filters.sort}
            onValueChange={(v) => navigate({ sort: v, page: undefined })}
          >
            <SelectTrigger className="h-9 w-[160px]">
              <SelectValue placeholder="Sort by" />
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="relevance">Relevance</SelectItem>
              <SelectItem value="price_asc">Price: Low to High</SelectItem>
              <SelectItem value="price_desc">Price: High to Low</SelectItem>
              <SelectItem value="newest">Newest</SelectItem>
              <SelectItem value="ending_soon">Ending Soon</SelectItem>
            </SelectContent>
          </Select>

          {hasActiveFilters && (
            <Button variant="ghost" size="sm" onClick={clearFilters}>
              <X className="mr-1 size-3" />
              Clear filters
            </Button>
          )}

          {pagination.total > 0 && (
            <span className="ml-auto text-sm text-content-secondary">
              {pagination.total} {pagination.total === 1 ? "result" : "results"}
            </span>
          )}
        </div>

        {/* Filter panel (collapsible) */}
        {showFilters && (
          <div className="mb-6 grid grid-cols-2 gap-4 rounded-xl border border-subtle bg-surface p-4 lg:grid-cols-6">
            {/* Category */}
            <Select
              value={filters.category || ALL}
              onValueChange={(v) =>
                navigate({ category: selectToParam(v), page: undefined })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Category" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>All Categories</SelectItem>
                {categories.map((cat) => (
                  <SelectItem key={cat.id} value={cat.id}>
                    {cat.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>

            {/* Condition */}
            <Select
              value={filters.condition || ALL}
              onValueChange={(v) =>
                navigate({ condition: selectToParam(v), page: undefined })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Condition" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>Any Condition</SelectItem>
                <SelectItem value="new">New</SelectItem>
                <SelectItem value="used">Used</SelectItem>
                <SelectItem value="refurbished">Refurbished</SelectItem>
              </SelectContent>
            </Select>

            {/* Sale Type */}
            <Select
              value={filters.sale_type || ALL}
              onValueChange={(v) =>
                navigate({ sale_type: selectToParam(v), page: undefined })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Sale Type" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>Any Type</SelectItem>
                <SelectItem value="auction">Auction</SelectItem>
                <SelectItem value="buy_now">Buy Now</SelectItem>
                <SelectItem value="hybrid">Hybrid</SelectItem>
              </SelectContent>
            </Select>

            {/* Min Price */}
            <Input
              type="number"
              placeholder="Min price"
              value={localMinPrice}
              onChange={(e) => {
                setLocalMinPrice(e.target.value);
                debouncedNavigate({
                  min_price: e.target.value || undefined,
                  page: undefined,
                });
              }}
            />

            {/* Max Price */}
            <Input
              type="number"
              placeholder="Max price"
              value={localMaxPrice}
              onChange={(e) => {
                setLocalMaxPrice(e.target.value);
                debouncedNavigate({
                  max_price: e.target.value || undefined,
                  page: undefined,
                });
              }}
            />

            {/* Auction Status */}
            <Select
              value={filters.auction_status || ALL}
              onValueChange={(v) =>
                navigate({
                  auction_status: selectToParam(v),
                  page: undefined,
                })
              }
            >
              <SelectTrigger>
                <SelectValue placeholder="Auction Status" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value={ALL}>Any Status</SelectItem>
                <SelectItem value="active">Active</SelectItem>
                <SelectItem value="scheduled">Scheduled</SelectItem>
                <SelectItem value="ended">Ended</SelectItem>
              </SelectContent>
            </Select>
          </div>
        )}

        {/* Results grid */}
        {query === "" ? (
          <div className="py-20 text-center text-content-secondary">
            <Search className="mx-auto mb-4 size-12 text-content-placeholder" />
            <p className="text-lg font-medium">Search for items</p>
            <p className="text-sm">Enter a keyword to find auction items</p>
          </div>
        ) : items.length === 0 ? (
          <div className="py-20 text-center text-content-secondary">
            <Search className="mx-auto mb-4 size-12 text-content-placeholder" />
            <p className="text-lg font-medium">
              No items found for &quot;{query}&quot;
            </p>
            <p className="text-sm">
              Try different keywords or adjust your filters
            </p>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
              {items.map((item) => (
                <CategoryItemCard
                  key={item.id}
                  item={item as CategoryItem}
                  watchlistEntryId={watchlisted_map[item.id]}
                />
              ))}
            </div>

            {/* Pagination */}
            {pagination.total_pages > 1 && (
              <div className="mt-8 flex items-center justify-center gap-2">
                <Button
                  variant="outline"
                  size="sm"
                  disabled={pagination.page <= 1}
                  onClick={() =>
                    navigate({ page: String(pagination.page - 1) })
                  }
                >
                  Previous
                </Button>
                <span className="px-4 text-sm text-content-secondary">
                  Page {pagination.page} of {pagination.total_pages}
                </span>
                <Button
                  variant="outline"
                  size="sm"
                  disabled={pagination.page >= pagination.total_pages}
                  onClick={() =>
                    navigate({ page: String(pagination.page + 1) })
                  }
                >
                  Next
                </Button>
              </div>
            )}
          </>
        )}
      </div>
    </>
  );
}
