import { Link, router } from "@inertiajs/react";
import { Gavel, Package, Headset } from "lucide-react";
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
    <nav className="space-y-1">
      {/* All option */}
      <button
        type="button"
        onClick={() => handleCategoryClick(null)}
        className={cn(
          "flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
          isAllActive
            ? "bg-primary-600/10 text-primary-600"
            : "text-content-tertiary hover:text-content"
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
              "flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
              isActive
                ? "bg-primary-600/10 text-primary-600"
                : "text-content-tertiary hover:text-content"
            )}
          >
            <Icon className="size-5" />
            {category.name}
          </button>
        );
      })}

      {/* Support link */}
      <Link
        href="/settings/support"
        className="mt-6 flex w-full items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium text-content-tertiary transition-colors hover:text-content"
      >
        <Headset className="size-5" />
        Support
      </Link>
    </nav>
  );
}
