import { listItems, homepageItemCardFields, buildCSRFHeaders } from "@/ash_rpc";
import type { HomepageItemCard } from "@/ash_rpc";
import { useAshQuery } from "@/hooks/use-ash-query";
import { ItemCard } from "@/components/items/item-card";

type Item = HomepageItemCard[number];

interface EndingSoonSectionProps {
  initialItems: Item[];
}

export function EndingSoonSection({ initialItems }: EndingSoonSectionProps) {
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

  const items = data ?? initialItems;

  return (
    <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
      <h2 className="mb-6 font-heading text-xl font-semibold text-neutral-01">
        Ending Soon
      </h2>
      {items.length === 0 ? (
        <div className="flex h-48 items-center justify-center rounded-xl bg-neutral-08">
          <p className="text-sm text-neutral-04">No items ending soon</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-6 overflow-x-auto pb-4">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} badge="ending-soon" />
          ))}
        </div>
      )}
    </section>
  );
}
