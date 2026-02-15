import { Link } from '@inertiajs/react';

export interface NavSubcategory {
  id: string;
  name: string;
  slug: string;
}

export interface NavCategory {
  id: string;
  name: string;
  slug: string;
  categories: NavSubcategory[];
}

interface CategoryMegaMenuProps {
  categories: NavCategory[];
}

export function CategoryMegaMenu({ categories }: CategoryMegaMenuProps) {
  return (
    <div className="grid grid-cols-3 gap-x-[104px] gap-y-10 p-6">
      {categories.map(category => (
        <div key={category.id} className="flex flex-col gap-2">
          <Link
            href={`/categories/${category.slug}`}
            className="text-base font-medium text-content hover:underline"
          >
            {category.name}
          </Link>
          {category.categories.length > 0 && (
            <div className="flex flex-col gap-2">
              {category.categories.map(sub => (
                <Link
                  key={sub.id}
                  href={`/categories/${category.slug}/${sub.slug}`}
                  className="text-sm text-content-secondary transition-colors hover:text-content"
                >
                  {sub.name}
                </Link>
              ))}
            </div>
          )}
        </div>
      ))}
    </div>
  );
}
