import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/components/items/item-card";

type Item = HomepageItemCard[number];

interface HotNowSectionProps {
  items: Item[];
}

export function HotNowSection({ items }: HotNowSectionProps) {
  return (
    <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
      <h2 className="mb-6 font-heading text-xl font-semibold text-neutral-01">
        Hot Now
      </h2>
      {items.length === 0 ? (
        <div className="flex h-48 items-center justify-center rounded-xl bg-neutral-08">
          <p className="text-sm text-neutral-04">No hot items right now</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-6 overflow-x-auto pb-4">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} badge="hot-now" />
          ))}
        </div>
      )}
    </section>
  );
}
