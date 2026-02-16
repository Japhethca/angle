import type { HomepageItemCard } from "@/ash_rpc";
import { ItemCard } from "@/features/items";
import { useAuth } from "@/features/auth";

type Item = HomepageItemCard[number];

interface RecommendedSectionProps {
  items: Item[];
  watchlistedMap?: Record<string, string>;
}

function getGreeting(): string {
  const hour = new Date().getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

export function RecommendedSection({ items, watchlistedMap = {} }: RecommendedSectionProps) {
  const { authenticated, user } = useAuth();

  const greeting = authenticated && user?.full_name
    ? `${getGreeting()}, ${user.full_name}`
    : "Recommended for You";

  return (
    <section className="py-10 lg:py-12">
      <h2 className="mb-6 px-4 font-heading text-2xl font-semibold text-content lg:px-10 lg:text-[32px]">
        {greeting}
      </h2>
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
