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
    <section className="mx-auto max-w-7xl px-4 py-8 lg:px-8">
      <h2 className="mb-6 font-heading text-xl font-semibold text-neutral-01">
        {greeting}
      </h2>
      {items.length === 0 ? (
        <div className="flex h-48 items-center justify-center rounded-xl bg-neutral-08">
          <p className="text-sm text-neutral-04">No recommendations yet</p>
        </div>
      ) : (
        <div className="scrollbar-hide flex gap-6 overflow-x-auto pb-4">
          {items.map((item) => (
            <ItemCard key={item.id} item={item} />
          ))}
        </div>
      )}
    </section>
  );
}
