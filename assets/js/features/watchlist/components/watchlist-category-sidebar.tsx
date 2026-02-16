import { router } from "@inertiajs/react";
import { Gavel, Package, LifeBuoy } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { cn } from "@/lib/utils";

interface Category {
  id: string;
  name: string;
  slug: string;
}

interface WatchlistCategorySidebarProps {
  categories: Category[];
  activeCategory: string | null;
}

const CATEGORY_ICON_MAP: Record<string, LucideIcon> = {
  // Add known category name mappings here as needed
};

function getCategoryIcon(name: string): LucideIcon {
  const normalized = name.toLowerCase();
  return CATEGORY_ICON_MAP[normalized] ?? Package;
}

export function WatchlistCategorySidebar({
  categories,
  activeCategory,
}: WatchlistCategorySidebarProps) {
  const isAllActive = !activeCategory;

  function handleCategoryClick(categoryId: string | null) {
    if (categoryId) {
      router.visit(`/watchlist?category=${categoryId}`);
    } else {
      router.visit("/watchlist");
    }
  }

  return (
    <nav className="flex h-full flex-col rounded-xl bg-white py-6 shadow-[0px_1px_2px_rgba(0,0,0,0.08)]">
      <div className="flex flex-col gap-1 px-3">
        {/* All option */}
        <button
          type="button"
          onClick={() => handleCategoryClick(null)}
          className={cn(
            "flex items-center gap-2 rounded-lg px-4 py-2 text-left text-base font-medium transition-colors",
            isAllActive
              ? "bg-[rgba(253,224,204,0.4)] text-primary-800"
              : "text-content-tertiary hover:bg-surface-muted hover:text-content"
          )}
        >
          <Gavel className="size-5" />
          All
        </button>

        {/* Category list */}
        {categories.map((category) => {
          const isActive = activeCategory === category.id;
          const Icon = getCategoryIcon(category.name);

          return (
            <button
              key={category.id}
              type="button"
              onClick={() => handleCategoryClick(category.id)}
              className={cn(
                "flex items-center gap-2 rounded-lg px-4 py-2 text-left text-base font-medium transition-colors",
                isActive
                  ? "bg-[rgba(253,224,204,0.4)] text-primary-800"
                  : "text-content-tertiary hover:bg-surface-muted hover:text-content"
              )}
            >
              <Icon className="size-5" />
              {category.name}
            </button>
          );
        })}
      </div>

      {/* Support link */}
      <div className="mt-auto px-3 pt-8">
        <button
          type="button"
          onClick={() => router.visit("/support")}
          className="flex items-center gap-2 rounded-lg px-4 py-2 text-base font-medium text-content-tertiary transition-colors hover:bg-surface-muted hover:text-content"
        >
          <LifeBuoy className="size-5" />
          Support
        </button>
      </div>
    </nav>
  );
}
