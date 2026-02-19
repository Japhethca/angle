import { Link } from "@inertiajs/react";
import { listItems, homepageItemCardFields, buildCSRFHeaders } from "@/ash_rpc";
import type { HomepageItemCard } from "@/ash_rpc";
import { useAshQuery } from "@/hooks/use-ash-query";
import { ItemCard } from "@/features/items";
import { Section } from "@/components/layouts";

type Item = HomepageItemCard[number];

interface EndingSoonSectionProps {
  initialItems: Item[];
  watchlistedMap?: Record<string, string>;
}

export function EndingSoonSection({ initialItems, watchlistedMap = {} }: EndingSoonSectionProps) {
  const { data } = useAshQuery(
    ["homepage", "ending-soon"],
    () =>
      listItems({
        fields: homepageItemCardFields,
        filter: { publicationStatus: { eq: "published" } },
        sort: "++end_time",
        page: { limit: 8 },
        headers: buildCSRFHeaders(),
      }),
    {
      refetchInterval: 60_000,
      initialData: initialItems,
    }
  );

  const items = Array.isArray(data) ? data : data?.results ?? initialItems;

  return (
    <Section className="py-10 lg:py-12">
      <div className="mb-6 flex items-center justify-between">
        <h2 className="font-heading text-2xl font-semibold text-content lg:text-[32px]">
          Ending Soon
        </h2>
        <Link
          href="/search?sort=ending_soon"
          className="text-sm font-medium text-primary-600 transition-colors hover:text-primary-700"
        >
          View All
        </Link>
      </div>
      {items.length === 0 ? (
        <div className="flex h-48 items-center justify-center rounded-xl bg-surface-muted">
          <p className="text-sm text-content-tertiary">No items ending soon</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4 lg:gap-6">
          {items.map((item) => (
            <ItemCard
              key={item.id}
              item={item}
              watchlistEntryId={watchlistedMap[item.id] ?? null}
            />
          ))}
        </div>
      )}
    </Section>
  );
}
