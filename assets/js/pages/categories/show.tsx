import { useState, useCallback } from "react";
import { Link } from "@inertiajs/react";
import { ChevronLeft, Search, LayoutGrid, List, Loader2 } from "lucide-react";
import type { NavCategory, CategoryItemCard as CategoryItemCardType } from "@/ash_rpc";
import { listItems, categoryItemCardFields, buildCSRFHeaders } from "@/ash_rpc";
import type { ListItemsFields } from "@/ash_rpc";
import { CategoryItemCard, CategoryItemListCard } from "@/features/items";

type Category = NavCategory[number];
type Subcategory = Category["categories"][number];
type CategoryItemType = CategoryItemCardType[number];

type ViewMode = "grid" | "list";

const ITEMS_PER_PAGE = 20;
const VIEW_MODE_KEY = "category-view-mode";

function getInitialViewMode(): ViewMode {
  if (typeof window === "undefined") return "grid";
  const stored = localStorage.getItem(VIEW_MODE_KEY);
  return stored === "list" ? "list" : "grid";
}

interface CategoryShowProps {
  category: Category;
  subcategories: Subcategory[];
  items: CategoryItemType[];
  has_more: boolean;
  active_subcategory: string | null;
}

export default function CategoryShow({
  category,
  subcategories = [],
  items: initialItems = [],
  has_more: initialHasMore = false,
  active_subcategory,
}: CategoryShowProps) {
  const parentSlug = category.slug;
  const [viewMode, setViewMode] = useState<ViewMode>(getInitialViewMode);
  const [items, setItems] = useState<CategoryItemType[]>(initialItems);
  const [hasMore, setHasMore] = useState(initialHasMore);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  // Build the category IDs for load-more filtering
  const categoryIds = active_subcategory
    ? ([subcategories.find((s) => s.slug === active_subcategory)?.id].filter(Boolean) as string[])
    : [category.id, ...subcategories.map((s) => s.id)];

  const handleViewModeChange = (mode: ViewMode) => {
    setViewMode(mode);
    localStorage.setItem(VIEW_MODE_KEY, mode);
  };

  const loadMore = useCallback(async () => {
    setIsLoadingMore(true);
    try {
      const fields = categoryItemCardFields as ListItemsFields;
      const result = await listItems({
        fields,
        filter: {
          categoryId: { in: categoryIds },
          publicationStatus: { eq: "published" },
        },
        page: { limit: ITEMS_PER_PAGE, offset: items.length },
        headers: buildCSRFHeaders(),
      });

      if (result.success && result.data) {
        const data = result.data as { results: CategoryItemType[]; hasMore: boolean };
        setItems((prev) => [...prev, ...data.results]);
        setHasMore(data.hasMore);
      }
    } finally {
      setIsLoadingMore(false);
    }
  }, [categoryIds, items.length]);

  return (
    <div className="pb-8">
      {/* Mobile header */}
      <div className="flex items-center justify-between px-4 py-4 lg:hidden">
        <div className="flex items-center gap-3">
          <Link href="/categories" className="flex size-9 items-center justify-center">
            <ChevronLeft className="size-5 text-neutral-01" />
          </Link>
          <h1 className="text-xl font-medium text-neutral-01">{category.name}</h1>
        </div>
        <button className="flex size-9 items-center justify-center rounded-lg text-neutral-03">
          <Search className="size-5" />
        </button>
      </div>

      {/* Desktop header */}
      <div className="hidden px-10 pt-8 lg:block">
        <nav className="mb-2 text-sm text-neutral-04">
          <Link href="/" className="hover:text-neutral-01">Home</Link>
          <span className="mx-2">/</span>
          <Link href="/categories" className="hover:text-neutral-01">Categories</Link>
          <span className="mx-2">/</span>
          <span className="text-neutral-01">{category.name}</span>
        </nav>
        <h1 className="text-2xl font-semibold text-neutral-01">{category.name}</h1>
      </div>

      {/* Subcategory chips + view toggle */}
      <div className="flex items-center justify-between gap-4 px-4 py-4 lg:px-10">
        {/* Chips */}
        {subcategories.length > 0 && (
          <div className="flex min-w-0 gap-2 overflow-x-auto">
            <Link
              href={`/categories/${parentSlug}`}
              className={`shrink-0 rounded-lg px-4 py-1 text-xs transition-colors ${
                active_subcategory === null
                  ? "bg-primary-600 text-white"
                  : "border border-neutral-08 bg-neutral-09 text-neutral-03 hover:bg-neutral-08"
              }`}
            >
              All
            </Link>
            {subcategories.map((sub) => (
              <Link
                key={sub.id}
                href={`/categories/${parentSlug}/${sub.slug}`}
                className={`shrink-0 rounded-lg px-4 py-1 text-xs transition-colors ${
                  active_subcategory === sub.slug
                    ? "bg-primary-600 text-white"
                    : "border border-neutral-08 bg-neutral-09 text-neutral-03 hover:bg-neutral-08"
                }`}
              >
                {sub.name}
              </Link>
            ))}
          </div>
        )}

        {/* View toggle */}
        <div className="flex shrink-0 items-center gap-1">
          <button
            onClick={() => handleViewModeChange("grid")}
            className={`flex size-8 items-center justify-center rounded transition-colors ${
              viewMode === "grid" ? "text-primary-600" : "text-neutral-05 hover:text-neutral-03"
            }`}
          >
            <LayoutGrid className="size-4" />
          </button>
          <button
            onClick={() => handleViewModeChange("list")}
            className={`flex size-8 items-center justify-center rounded transition-colors ${
              viewMode === "list" ? "text-primary-600" : "text-neutral-05 hover:text-neutral-03"
            }`}
          >
            <List className="size-4" />
          </button>
        </div>
      </div>

      {/* Items */}
      {items.length > 0 ? (
        <>
          {viewMode === "grid" ? (
            <div className="grid grid-cols-1 gap-6 px-4 sm:grid-cols-2 lg:grid-cols-3 lg:px-10">
              {items.map((item) => (
                <CategoryItemCard key={item.id} item={item} />
              ))}
            </div>
          ) : (
            <div className="flex flex-col gap-4 px-4 lg:px-10">
              {items.map((item) => (
                <CategoryItemListCard key={item.id} item={item} />
              ))}
            </div>
          )}

          {/* Load More button */}
          {hasMore && (
            <div className="flex justify-center px-4 pt-8 lg:px-10">
              <button
                onClick={loadMore}
                disabled={isLoadingMore}
                className="flex items-center gap-2 rounded-full border border-neutral-06 px-8 py-3 text-sm font-medium text-neutral-03 transition-colors hover:bg-neutral-09 disabled:opacity-50"
              >
                {isLoadingMore ? (
                  <>
                    <Loader2 className="size-4 animate-spin" />
                    Loading...
                  </>
                ) : (
                  "Load More"
                )}
              </button>
            </div>
          )}
        </>
      ) : (
        <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
          <p className="text-lg text-neutral-04">No items in this category yet</p>
          <p className="mt-1 text-sm text-neutral-05">Check back later for new listings</p>
        </div>
      )}
    </div>
  );
}
