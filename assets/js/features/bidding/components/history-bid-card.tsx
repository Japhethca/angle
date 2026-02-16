import { Link } from "@inertiajs/react";
import type { HistoryBidCard as HistoryBidCardType } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type BidItem = HistoryBidCardType[number];

interface HistoryBidCardProps {
  bid: BidItem;
  didWin: boolean;
}

export function HistoryBidCard({ bid, didWin }: HistoryBidCardProps) {
  const item = bid.item;
  const itemUrl = `/items/${item?.slug || item?.id}`;
  const status = didWin
    ? {
        label: "Completed",
        className: "bg-green-50 text-green-700 border-green-200",
      }
    : {
        label: "Didn't win",
        className: "bg-gray-50 text-gray-500 border-gray-200",
      };

  const bidDate = bid.bidTime
    ? new Date(bid.bidTime).toLocaleDateString("en-GB", {
        day: "2-digit",
        month: "2-digit",
        year: "2-digit",
      })
    : "";

  return (
    <>
      {/* Desktop */}
      <div className="hidden items-center gap-4 border-b border-default py-4 lg:flex">
        <Link href={itemUrl} className="block size-16 shrink-0">
          <div className="size-full rounded-lg bg-surface-muted" />
        </Link>
        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-3">
            <Link href={itemUrl}>
              <h3 className="text-sm font-medium text-content">
                {item?.title}
              </h3>
            </Link>
            <span
              className={cn(
                "rounded-full border px-2.5 py-0.5 text-xs font-medium",
                status.className,
              )}
            >
              {status.label}
            </span>
          </div>
          <div className="mt-1 flex items-center gap-2 text-sm">
            <span className="text-content-tertiary">Your bid:</span>
            <span className="font-bold text-content">
              {formatNaira(bid.amount)}
            </span>
          </div>
        </div>
        <span className="shrink-0 text-sm text-content-tertiary">
          {bidDate}
        </span>
      </div>

      {/* Mobile */}
      <div className="space-y-2 rounded-xl border border-default p-4 lg:hidden">
        <div className="flex items-start gap-3">
          <Link href={itemUrl} className="block size-14 shrink-0">
            <div className="size-full rounded-lg bg-surface-muted" />
          </Link>
          <div className="min-w-0 flex-1">
            <span
              className={cn(
                "mb-1 inline-block rounded-full border px-2 py-0.5 text-xs font-medium",
                status.className,
              )}
            >
              {status.label}
            </span>
            <Link href={itemUrl}>
              <h3 className="line-clamp-2 text-sm font-medium text-content">
                {item?.title}
              </h3>
            </Link>
            <div className="mt-1 flex items-center gap-2 text-sm">
              <span className="font-bold text-content">
                {formatNaira(bid.amount)}
              </span>
            </div>
            <span className="text-xs text-content-tertiary">{bidDate}</span>
          </div>
        </div>
      </div>
    </>
  );
}
