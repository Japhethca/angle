import { Link } from "@inertiajs/react";
import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/features/items";
import { useAuth } from "@/features/auth";

type Item = HomepageItemCard[number];

interface RecommendedSectionProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

export function RecommendedSection({ items, watchlistedMap = {} }: RecommendedSectionProps) {
  const { authenticated } = useAuth();

  const heading = authenticated ? "Recommended for You" : "Popular Items";

  return (
    <section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between px-4 lg:px-10">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          {heading}
        </h2>
        <Link
          href="/categories"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All
        </Link>
      </div>
      {items.length === 0 ? (
        <div className="mx-4 flex h-48 items-center justify-center rounded-xl bg-surface-muted lg:mx-10">
          <p className="text-sm text-content-tertiary">No recommendations yet</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} watchlistEntryId={watchlistedMap[item.id] ?? null} />
          ))}
        </div>
      )}
    </section>
  );
}
