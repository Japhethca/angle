import { Link } from "@inertiajs/react";
import { Grid3X3 } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";

type Category = HomepageCategory[number];

interface BrowseCategoriesSectionProps {
  categories: Category[];
}

export function BrowseCategoriesSection({ categories }: BrowseCategoriesSectionProps) {
  return (
    <section className="py-10 lg:py-12">
      <h2 className="mb-6 px-4 font-heading text-2xl font-semibold text-neutral-01 lg:px-10 lg:text-[32px]">
        Browse Categories
      </h2>
      {categories.length === 0 ? (
        <div className="mx-4 flex h-48 flex-col items-center justify-center rounded-xl bg-neutral-08 lg:mx-10">
          <Grid3X3 className="mb-3 size-8 text-neutral-05" />
          <p className="text-sm text-neutral-04">No categories available</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {categories.map((category) => (
            <Link
              key={category.id}
              href={`/categories/${category.slug || category.id}`}
              className="w-[70vw] shrink-0 sm:w-[260px] lg:w-[320px]"
            >
              <div className="relative aspect-[3/4] overflow-hidden rounded-2xl bg-neutral-08">
                {category.imageUrl ? (
                  <img
                    src={category.imageUrl}
                    alt={category.name}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div className="flex h-full items-center justify-center text-neutral-05">
                    <Grid3X3 className="size-10" />
                  </div>
                )}

                {/* Category name overlay at bottom-left */}
                <div className="absolute bottom-0 left-0 right-0 p-4">
                  <span className="inline-block rounded-lg bg-neutral-01/60 px-3 py-1.5 text-sm font-medium text-white backdrop-blur-sm">
                    {category.name}
                  </span>
                </div>
              </div>
            </Link>
          ))}
        </div>
      )}
    </section>
  );
}
