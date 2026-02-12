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

  const items = Array.isArray(data) ? data : data?.results ?? initialItems;

  return (
    <section className="py-10 lg:py-12">
      <h2 className="mb-6 px-4 font-heading text-2xl font-semibold text-neutral-01 lg:px-10 lg:text-[32px]">
        Ending Soon
      </h2>
      {items.length === 0 ? (
        <div className="mx-4 flex h-48 items-center justify-center rounded-xl bg-neutral-08 lg:mx-10">
          <p className="text-sm text-neutral-04">No items ending soon</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} badge="ending-soon" />
          ))}
        </div>
      )}
    </section>
  );
}
