import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/components/items/item-card";
import { useAuth } from "@/contexts/auth-context";

type Item = HomepageItemCard[number];

interface RecommendedSectionProps {
  items: Item[];
}

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

export function RecommendedSection({ items }: RecommendedSectionProps) {
  const { authenticated, user } = useAuth();

  const greeting = authenticated && user?.full_name
    ? `${getGreeting()}, ${user.full_name}`
    : "Recommended for You";

  return (
    <section className="py-10 lg:py-12">
      <h2 className="mb-6 px-4 font-heading text-2xl font-semibold text-neutral-01 lg:px-10 lg:text-[32px]">
        {greeting}
      </h2>
      {items.length === 0 ? (
        <div className="mx-4 flex h-48 items-center justify-center rounded-xl bg-neutral-08 lg:mx-10">
          <p className="text-sm text-neutral-04">No recommendations yet</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-4 overflow-x-auto px-4 pb-4 lg:gap-6 lg:px-10">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} />
          ))}
        </div>
      )}
    </section>
  );
}
