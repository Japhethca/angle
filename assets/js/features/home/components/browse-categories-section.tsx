import { Link } from "@inertiajs/react";
import { Grid3X3 } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";
import { Section } from "@/components/layouts";

type Category = HomepageCategory[number];

interface BrowseCategoriesSectionProps {
  categories: Category[];
}

// Rotating gradient backgrounds for categories without images
const gradients = [
  "from-blue-500/20 to-blue-600/30 dark:from-blue-500/10 dark:to-blue-600/20",
  "from-emerald-500/20 to-emerald-600/30 dark:from-emerald-500/10 dark:to-emerald-600/20",
  "from-purple-500/20 to-purple-600/30 dark:from-purple-500/10 dark:to-purple-600/20",
  "from-amber-500/20 to-amber-600/30 dark:from-amber-500/10 dark:to-amber-600/20",
  "from-rose-500/20 to-rose-600/30 dark:from-rose-500/10 dark:to-rose-600/20",
  "from-cyan-500/20 to-cyan-600/30 dark:from-cyan-500/10 dark:to-cyan-600/20",
];

export function BrowseCategoriesSection({ categories }: BrowseCategoriesSectionProps) {
  const displayCategories = categories.slice(0, 8);

  return (
    <Section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Browse Categories
        </h2>
        <Link
          href="/categories"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All Categories
        </Link>
      </div>
      {displayCategories.length === 0 ? (
        <div className="flex h-48 flex-col items-center justify-center rounded-xl bg-surface-muted">
          <Grid3X3 className="mb-3 size-8 text-content-placeholder" />
          <p className="text-sm text-content-tertiary">No categories available</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4 lg:gap-6">
          {displayCategories.map((category, index) => (
            <Link
              key={category.id}
              href={`/categories/${category.slug || category.id}`}
              className="group"
            >
              <div className="relative aspect-[3/4] overflow-hidden rounded-2xl">
                {category.imageUrl ? (
                  <img
                    src={category.imageUrl}
                    alt={category.name}
                    className="h-full w-full object-cover transition-transform duration-300 group-hover:scale-105"
                  />
                ) : (
                  <div className={`flex h-full items-center justify-center bg-gradient-to-br ${gradients[index % gradients.length]}`}>
                    <Grid3X3 className="size-10 text-content-placeholder" />
                  </div>
                )}

                {/* Dark gradient overlay from bottom */}
                <div className="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />

                {/* Category name */}
                <div className="absolute bottom-0 left-0 right-0 p-4">
                  <span className="text-sm font-semibold text-white lg:text-base">
                    {category.name}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </Section>
  );
}
