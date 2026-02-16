import { cn } from "@/lib/utils";
import type { SellerDashboardCard } from "@/ash_rpc";
import { ListingActionsMenu } from "./listing-actions-menu";
import { formatCurrency } from "../utils";

type Item = SellerDashboardCard[number];

type StatusKey = "active" | "ended" | "sold" | "draft" | "pending" | "scheduled" | "paused" | "cancelled";

function StatusBadge({ status }: { status: string | null | undefined }) {
  const key = (status || "draft") as StatusKey;
  const config: Record<StatusKey, { label: string; className: string }> = {
    active: { label: "Active", className: "bg-feedback-success-muted text-feedback-success" },
    ended: { label: "Ended", className: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400" },
    sold: { label: "Sold", className: "bg-feedback-success-muted text-feedback-success" },
    draft: { label: "Draft", className: "bg-surface-secondary text-content-tertiary" },
    pending: { label: "Pending", className: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400" },
    scheduled: { label: "Scheduled", className: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400" },
    paused: { label: "Paused", className: "bg-surface-secondary text-content-tertiary" },
    cancelled: { label: "Cancelled", className: "bg-surface-secondary text-content-tertiary" },
  };

  const { label, className } = config[key] || config.draft;

  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium", className)}>
      {label}
    </span>
  );
}

interface ListingCardProps {
  item: Item;
}

export function ListingCard({ item }: ListingCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-surface p-4">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-medium text-content">
            {item.title}
          </h3>
          <p className="mt-1 text-sm text-content-secondary">
            Highest bid: {formatCurrency(item.currentPrice || item.startingPrice)}
          </p>
          <p className="mt-1 text-xs text-content-placeholder">
            {item.viewCount ?? 0} Views {"\u2022"} {item.bidCount ?? 0} Bids {"\u2022"} {item.watcherCount ?? 0} Watchers
          </p>
        </div>
        <ListingActionsMenu slug={item.slug || item.id} />
      </div>
      <div className="mt-3">
        <StatusBadge status={item.auctionStatus} />
      </div>
    </div>
  );
}
