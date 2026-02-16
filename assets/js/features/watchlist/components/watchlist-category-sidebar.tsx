import { router } from "@inertiajs/react";
import { LifeBuoy } from "lucide-react";
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
    <nav className="flex flex-col gap-1">
      {/* All option */}
      <button
        type="button"
        onClick={() => handleCategoryClick(null)}
        className={cn(
          "rounded-lg px-3 py-2 text-left text-sm font-medium transition-colors",
          isAllActive
            ? "border-l-2 border-primary-600 bg-primary-600/5 text-primary-600"
            : "text-content-tertiary hover:bg-surface-muted hover:text-content"
        )}
      >
        All
      </button>

      {/* Category list */}
      {categories.map((category) => {
        const isActive = activeCategory === category.id;

        return (
          <button
            key={category.id}
            type="button"
            onClick={() => handleCategoryClick(category.id)}
            className={cn(
              "rounded-lg px-3 py-2 text-left text-sm font-medium transition-colors",
              isActive
                ? "border-l-2 border-primary-600 bg-primary-600/5 text-primary-600"
                : "text-content-tertiary hover:bg-surface-muted hover:text-content"
            )}
          >
            {category.name}
          </button>
        );
      })}

      {/* Support link */}
      <div className="mt-auto pt-8">
        <button
          type="button"
          onClick={() => router.visit("/support")}
          className="flex items-center gap-2 rounded-lg px-3 py-2 text-sm font-medium text-content-tertiary transition-colors hover:bg-surface-muted hover:text-content"
        >
          <LifeBuoy className="size-4" />
          Support
        </button>
      </div>
    </nav>
  );
}
