import { cn } from "@/lib/utils";

type StatusKey = "active" | "ended" | "sold" | "draft" | "pending" | "scheduled" | "paused" | "cancelled";

const STATUS_CONFIG: Record<StatusKey, { label: string; className: string }> = {
  active: { label: "Active", className: "bg-feedback-success-muted text-feedback-success" },
  ended: { label: "Ended", className: "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400" },
  sold: { label: "Sold", className: "bg-feedback-success-muted text-feedback-success" },
  draft: { label: "Draft", className: "bg-surface-secondary text-content-tertiary" },
  pending: { label: "Pending", className: "bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400" },
  scheduled: { label: "Scheduled", className: "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-400" },
  paused: { label: "Paused", className: "bg-surface-secondary text-content-tertiary" },
  cancelled: { label: "Cancelled", className: "bg-surface-secondary text-content-tertiary" },
};

interface StatusBadgeProps {
  publicationStatus: string | null | undefined;
  auctionStatus: string | null | undefined;
}

export function StatusBadge({ publicationStatus, auctionStatus }: StatusBadgeProps) {
  const key: StatusKey = publicationStatus === "draft"
    ? "draft"
    : (auctionStatus || "draft") as StatusKey;

  const { label, className } = STATUS_CONFIG[key] || STATUS_CONFIG.draft;

  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium", className)}>
      {label}
    </span>
  );
}
