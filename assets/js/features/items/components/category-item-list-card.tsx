import { Link } from "@inertiajs/react";
import { Heart, Clock, Gavel } from "lucide-react";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { formatNaira } from "@/lib/format";
import { useAuthGuard } from "@/features/auth";
import type { CategoryItem } from "./category-item-card";

interface CategoryItemListCardProps {
  item: CategoryItem;
}

export function CategoryItemListCard({ item }: CategoryItemListCardProps) {
  const itemUrl = `/items/${item.slug || item.id}`;
  const price = item.currentPrice || item.startingPrice;
  const { guard } = useAuthGuard();

  return (
    <div className="flex gap-3 border-b border-neutral-08 pb-4">
      {/* Thumbnail */}
      <Link href={itemUrl} className="shrink-0">
        <div className="relative size-[100px] overflow-hidden rounded-lg bg-neutral-08">
          <div className="flex h-full items-center justify-center text-neutral-05">
            <Gavel className="size-8" />
          </div>
        </div>
      </Link>

      {/* Details */}
      <div className="flex min-w-0 flex-1 flex-col justify-between">
        <div>
          <Link href={itemUrl}>
            <h3 className="line-clamp-1 text-base text-neutral-04">{item.title}</h3>
          </Link>
          <p className="mt-0.5 text-base font-bold text-neutral-01">
            {formatNaira(price)}
          </p>
        </div>

        <div className="flex items-center gap-2 text-xs">
          {item.endTime && (
            <span className="inline-flex items-center gap-1 rounded-full bg-[#F7F2F5] px-2 py-0.5 font-medium text-feedback-error">
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
      </div>

      {/* Actions */}
      <div className="flex shrink-0 flex-col items-end justify-between">
        <button
          className="flex size-8 items-center justify-center rounded-full border border-neutral-07 text-neutral-04 transition-colors hover:bg-neutral-08"
          onClick={() => guard(itemUrl)}
        >
          <Heart className="size-3.5" />
        </button>
        <Link
          href={itemUrl}
          className="flex items-center gap-1.5 rounded-full bg-primary-600 px-3 py-1.5 text-xs font-medium text-white transition-colors hover:bg-primary-600/90"
        >
          <Gavel className="size-3" />
          Bid
        </Link>
      </div>
    </div>
  );
}
