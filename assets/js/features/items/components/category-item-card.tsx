import { Link } from "@inertiajs/react";
import { Heart, Clock, Gavel } from "lucide-react";
import type { CategoryItemCard as CategoryItemCardType } from "@/ash_rpc";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { useAuthGuard } from "@/features/auth";

export type CategoryItem = CategoryItemCardType[number];

interface CategoryItemCardProps {
  item: CategoryItem;
}

export function CategoryItemCard({ item }: CategoryItemCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard } = useAuthGuard();

  return (
    <div className="w-full">
      <Link href={itemUrl} className="block">
        {/* Image */}
        <div className="relative aspect-square overflow-hidden rounded-2xl bg-neutral-08 sm:aspect-[9/10]">
          <div className="flex h-full items-center justify-center text-neutral-05">
            <Gavel className="size-16" />
          </div>

          {/* Watchlist heart */}
          <button
            className="absolute right-3 top-3 flex size-9 items-center justify-center rounded-full border border-neutral-06 bg-white/80 backdrop-blur-sm transition-colors hover:bg-white"
            onClick={(e) => {
              e.preventDefault();
              e.stopPropagation();
              guard(itemUrl);
            }}
          >
            <Heart className="size-4 text-neutral-03" />
          </button>

          {/* Almost gone badge */}
          {item.endTime && isEndingSoon(item.endTime) && (
            <div className="absolute bottom-4 left-0 flex items-center gap-1.5 rounded-r-lg bg-[#C1170B] px-3 py-1.5 text-xs font-medium text-white">
              <Clock className="size-3" />
              Almost gone
            </div>
          )}
        </div>
      </Link>

      {/* Info below image */}
      <div className="mt-3 space-y-2">
        <div className="flex items-start justify-between gap-2">
          <Link href={itemUrl} className="min-w-0 flex-1">
            <h3 className="line-clamp-1 text-xl text-neutral-04">{item.title}</h3>
          </Link>
          <p className="shrink-0 text-xl font-bold text-neutral-01">
            {formatNaira(price)}
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs">
          {item.endTime && (
            <span className="inline-flex items-center gap-1 rounded-full bg-[#F7F2F5] px-2.5 py-1 font-medium text-feedback-error">
              <Clock className="size-3" />
              <CountdownTimer endTime={item.endTime} className="text-feedback-error" />
            </span>
          )}
          {item.bidCount > 0 && (
            <>
              <span className="text-neutral-05">&middot;</span>
              <span className="text-neutral-04">{item.bidCount} bids</span>
            </>
          )}
        </div>

        {/* Bid button */}
        <Link
          href={itemUrl}
          className="flex w-full items-center justify-center gap-2 rounded-full bg-primary-600 px-4 py-3 text-base font-medium text-white transition-colors hover:bg-primary-600/90"
        >
          <Gavel className="size-4" />
          Bid
        </Link>
      </div>
    </div>
  );
}

function isEndingSoon(endTime: string): boolean {
  const end = new Date(endTime);
  const now = new Date();
  const hoursLeft = (end.getTime() - now.getTime()) / (1000 * 60 * 60);
  return hoursLeft > 0 && hoursLeft <= 24;
}
