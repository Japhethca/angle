import { useState, type FormEvent } from "react";
import { Link, router } from "@inertiajs/react";
import { Search } from "lucide-react";
import type { HomepageCategory } from "@/ash_rpc";
import { Section } from "@/components/layouts";

type Category = HomepageCategory[number];

interface SearchSectionProps {
  categories: Category[];
}

export function SearchSection({ categories }: SearchSectionProps) {
  const [query, setQuery] = useState("");

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    if (query.trim()) {
      router.visit(`/search?q=${encodeURIComponent(query.trim())}`);
    }
  };

  const trendingCategories = categories.slice(0, 6);

  return (
    <Section id="search-section" maxWidth="max-w-2xl" className="py-10 lg:py-12">
      <form onSubmit={handleSubmit} className="relative">
        <Search className="absolute left-4 top-1/2 size-5 -translate-y-1/2 text-content-placeholder" />
        <input
          type="text"
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder="Search for items, categories, or sellers..."
          className="h-14 w-full rounded-xl bg-surface-muted pl-12 pr-4 text-base text-content placeholder:text-content-placeholder outline-none ring-1 ring-transparent transition-shadow focus:ring-2 focus:ring-primary-600"
        />
      </form>

      {trendingCategories.length > 0 && (
        <div className="mt-4 flex flex-wrap items-center gap-2">
          <span className="text-sm text-content-tertiary">Trending:</span>
          {trendingCategories.map(category => (
            <Link
              key={category.id}
              href={`/categories/${category.slug || category.id}`}
              className="rounded-full bg-surface-muted px-3 py-1.5 text-sm text-content-secondary transition-colors hover:bg-surface-emphasis hover:text-content"
            >
              {category.name}
            </Link>
          ))}
        </div>
      )}
    </Section>
  );
}
