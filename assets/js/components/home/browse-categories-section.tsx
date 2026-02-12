import { Link } from "@inertiajs/react";
import { Grid3X3 } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";
import { Card, CardContent } from "@/components/ui/card";

type Category = HomepageCategory[number];

interface BrowseCategoriesSectionProps {
  categories: Category[];
}

export function BrowseCategoriesSection({ categories }: BrowseCategoriesSectionProps) {
  return (
    <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
      <h2 className="mb-6 font-heading text-xl font-semibold text-neutral-01">
        Browse Categories
      </h2>
      {categories.length === 0 ? (
        <div className="flex h-48 flex-col items-center justify-center rounded-xl bg-neutral-08">
          <Grid3X3 className="mb-3 size-8 text-neutral-05" />
          <p className="text-sm text-neutral-04">No categories available</p>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4 md:grid-cols-3 lg:grid-cols-4">
          {categories.map((category) => (
            <Link
              key={category.id}
              href={`/categories/${category.slug || category.id}`}
            >
              <Card className="group overflow-hidden transition-shadow hover:shadow-md">
                <div className="aspect-[3/2] bg-neutral-08">
                  {category.imageUrl ? (
                    <img
                      src={category.imageUrl}
                      alt={category.name}
                      className="h-full w-full object-cover"
                    />
                  ) : (
                    <div className="flex h-full items-center justify-center text-neutral-05">
                      <Grid3X3 className="size-8" />
                    </div>
                  )}
                </div>
                <CardContent className="p-3">
                  <p className="text-sm font-medium text-neutral-01 group-hover:text-primary-600">
                    {category.name}
                  </p>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </section>
  );
}
