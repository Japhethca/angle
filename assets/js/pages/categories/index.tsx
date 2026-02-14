import { Link } from "@inertiajs/react";
import { ChevronLeft } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";

type CategoryItem = HomepageCategory[number];

interface CategoriesIndexProps {
  categories: CategoryItem[];
}

export default function CategoriesIndex({ categories = [] }: CategoriesIndexProps) {
  return (
    <div className="pb-8">
      {/* Mobile header */}
      <div className="flex items-center gap-3 px-4 py-4 lg:hidden">
        <Link href="/" className="flex size-9 items-center justify-center">
          <ChevronLeft className="size-5 text-neutral-01" />
        </Link>
        <h1 className="text-xl font-medium text-neutral-01">Categories</h1>
      </div>

      {/* Desktop header */}
      <div className="hidden px-10 pt-8 lg:block">
        <h1 className="text-2xl font-semibold text-neutral-01">Categories</h1>
      </div>

      {/* Grid */}
      {categories.length > 0 ? (
        <div className="grid grid-cols-2 gap-4 px-4 pt-4 lg:grid-cols-4 lg:gap-6 lg:px-10">
          {categories.map((cat) => (
            <Link
              key={cat.id}
              href={`/categories/${cat.slug}`}
              className="flex flex-col items-center rounded-lg bg-neutral-08 p-4 transition-colors hover:bg-neutral-07"
            >
              {cat.imageUrl ? (
                <img
                  src={cat.imageUrl}
                  alt={cat.name}
                  className="size-[104px] object-contain"
                />
              ) : (
                <div className="flex size-[104px] items-center justify-center text-neutral-05">
                  <span className="text-4xl">{cat.name.charAt(0)}</span>
                </div>
              )}
              <span className="mt-3 text-base text-neutral-03">{cat.name}</span>
            </Link>
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center px-4 py-16 text-center">
          <p className="text-lg text-neutral-04">No categories available</p>
          <p className="mt-1 text-sm text-neutral-05">Check back later</p>
        </div>
      )}
    </div>
  );
}
