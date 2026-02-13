import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/components/items/item-card";

interface SimilarItemsProps {
  items: HomepageItemCard;
}

export function SimilarItems({ items }: SimilarItemsProps) {
  if (items.length === 0) return null;

  return (
    <div>
      <h2 className="mb-4 font-heading text-base font-medium text-neutral-01">
        Similar Items
      </h2>
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-3 lg:gap-4">
        {items.map((item) => (
          <div key={item.id} className="w-full [&>div]:w-full">
            <ItemCard item={item} />
          </div>
        ))}
      </div>
    </div>
  );
}
