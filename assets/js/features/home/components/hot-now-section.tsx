import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/features/items";

type Item = HomepageItemCard[number];

interface HotNowSectionProps {
  items: Item[];
}

export function HotNowSection({ items }: HotNowSectionProps) {
  return (
    <section className="py-10 lg:py-12">
      <h2 className="mb-6 px-4 font-heading text-2xl font-semibold text-neutral-01 lg:px-10 lg:text-[32px]">
        Hot Now
      </h2>
      {items.length === 0 ? (
        <div className="mx-4 flex h-48 items-center justify-center rounded-xl bg-neutral-08 lg:mx-10">
          <p className="text-sm text-neutral-04">No hot items right now</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} badge="hot-now" />
          ))}
        </div>
      )}
    </section>
  );
}
