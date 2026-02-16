import { cn } from "@/lib/utils";
import type { SellerDashboardCard } from "@/ash_rpc";
import { ListingActionsMenu } from "./listing-actions-menu";
import { formatCurrency } from "../utils";

type Item = SellerDashboardCard[number];

function formatTimeLeft(endTime: string | null | undefined): string {
  if (!endTime) return "--";
  const end = new Date(endTime);
  const now = new Date();
  const diff = end.getTime() - now.getTime();

  if (diff <= 0) return "Ended";

  const days = Math.floor(diff / (1000 * 60 * 60 * 24));
  const hours = Math.floor((diff % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
  const minutes = Math.floor((diff % (1000 * 60 * 60)) / (1000 * 60));

  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m`;
}

type StatusKey = "active" | "ended" | "sold" | "draft" | "pending" | "scheduled" | "paused" | "cancelled";

function StatusBadge({ status }: { status: string | null | undefined }) {
  const key = (status || "draft") as StatusKey;
  const config: Record<StatusKey, { label: string; className: string }> = {
    active: { label: "Active", className: "bg-feedback-success-muted text-feedback-success" },
    ended: { label: "Ended", className: "bg-orange-100 text-orange-700" },
    sold: { label: "Sold", className: "bg-feedback-success-muted text-feedback-success" },
    draft: { label: "Draft", className: "bg-surface-secondary text-content-tertiary" },
    pending: { label: "Pending", className: "bg-yellow-100 text-yellow-700" },
    scheduled: { label: "Scheduled", className: "bg-blue-100 text-blue-700" },
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

interface ListingTableProps {
  items: Item[];
}

export function ListingTable({ items }: ListingTableProps) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-surface-muted text-left text-xs font-medium uppercase tracking-wider text-content-tertiary">
            <th className="px-4 py-3">Item</th>
            <th className="px-4 py-3">Views</th>
            <th className="px-4 py-3">Watch</th>
            <th className="px-4 py-3">Bids</th>
            <th className="px-4 py-3">Highest Bid</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody className="divide-y divide-surface-muted">
          {items.map((item) => (
            <tr key={item.id} className="transition-colors hover:bg-surface-secondary/50">
              <td className="px-4 py-3">
                <div className="flex items-center gap-3">
                  <div className="size-10 shrink-0 rounded-lg bg-surface-muted" />
                  <div className="min-w-0">
                    <p className="truncate text-sm font-medium text-content">
                      {item.title}
                    </p>
                    <p className="text-xs text-content-placeholder">
                      {formatTimeLeft(item.endTime)}
                    </p>
                  </div>
                </div>
              </td>
              <td className="px-4 py-3 text-sm text-content-secondary">
                {item.viewCount ?? 0}
              </td>
              <td className="px-4 py-3 text-sm text-content-secondary">
                {item.watcherCount ?? 0}
              </td>
              <td className="px-4 py-3 text-sm text-content-secondary">
                {item.bidCount ?? 0}
              </td>
              <td className="px-4 py-3 text-sm font-medium text-content">
                {formatCurrency(item.currentPrice || item.startingPrice)}
              </td>
              <td className="px-4 py-3">
                <StatusBadge status={item.auctionStatus} />
              </td>
              <td className="px-4 py-3">
                <ListingActionsMenu slug={item.slug || item.id} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
