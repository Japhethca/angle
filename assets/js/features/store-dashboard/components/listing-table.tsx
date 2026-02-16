import { useRef, useState } from "react";
import { ArrowDown, ArrowUp, ArrowUpDown, ChevronDown, Check } from "lucide-react";
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

// --- Sortable column header ---

interface SortHeaderProps {
  label: string;
  field: string;
  currentSort: string;
  currentDir: string;
  onSort: (field: string, dir: string) => void;
}

function SortHeader({ label, field, currentSort, currentDir, onSort }: SortHeaderProps) {
  const isActive = currentSort === field;

  function handleClick() {
    if (isActive) {
      onSort(field, currentDir === "asc" ? "desc" : "asc");
    } else {
      onSort(field, "desc");
    }
  }

  return (
    <th className="px-4 py-3">
      <button
        type="button"
        onClick={handleClick}
        className="inline-flex items-center gap-1 text-xs font-medium uppercase tracking-wider transition-colors hover:text-content"
      >
        {label}
        {isActive ? (
          currentDir === "asc" ? (
            <ArrowUp className="size-3.5" />
          ) : (
            <ArrowDown className="size-3.5" />
          )
        ) : (
          <ArrowUpDown className="size-3.5 opacity-40" />
        )}
      </button>
    </th>
  );
}

// --- Status filter column header ---

const STATUS_OPTIONS = [
  { key: "all", label: "All" },
  { key: "active", label: "Active" },
  { key: "ended", label: "Ended" },
  { key: "draft", label: "Draft" },
] as const;

interface StatusFilterHeaderProps {
  currentStatus: string;
  onFilter: (status: string) => void;
}

function StatusFilterHeader({ currentStatus, onFilter }: StatusFilterHeaderProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  const activeLabel = STATUS_OPTIONS.find((o) => o.key === currentStatus)?.label ?? "Status";

  return (
    <th className="relative px-4 py-3">
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        onBlur={() => setTimeout(() => setOpen(false), 150)}
        className="inline-flex items-center gap-1 text-xs font-medium uppercase tracking-wider transition-colors hover:text-content"
      >
        {currentStatus === "all" ? "Status" : activeLabel}
        <ChevronDown className={cn("size-3.5 transition-transform", open && "rotate-180")} />
      </button>
      {open && (
        <div
          ref={ref}
          className="absolute left-0 top-full z-10 mt-1 w-36 rounded-lg border border-surface-muted bg-white py-1 shadow-lg"
        >
          {STATUS_OPTIONS.map((opt) => (
            <button
              key={opt.key}
              type="button"
              onMouseDown={(e) => e.preventDefault()}
              onClick={() => {
                onFilter(opt.key);
                setOpen(false);
              }}
              className="flex w-full items-center justify-between px-3 py-1.5 text-left text-sm text-content-secondary transition-colors hover:bg-surface-secondary"
            >
              {opt.label}
              {currentStatus === opt.key && <Check className="size-3.5 text-primary-600" />}
            </button>
          ))}
        </div>
      )}
    </th>
  );
}

// --- Main table ---

interface ListingTableProps {
  items: Item[];
  sort: string;
  dir: string;
  status: string;
  onNavigate: (params: Record<string, string | number>) => void;
}

export function ListingTable({ items, sort, dir, status, onNavigate }: ListingTableProps) {
  function handleSort(field: string, direction: string) {
    onNavigate({ status, sort: field, dir: direction, page: 1, per_page: items.length || 10 });
  }

  function handleFilter(newStatus: string) {
    onNavigate({ status: newStatus, sort, dir, page: 1, per_page: items.length || 10 });
  }

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-surface-muted text-left text-content-tertiary">
            <SortHeader label="Item" field="inserted_at" currentSort={sort} currentDir={dir} onSort={handleSort} />
            <SortHeader label="Views" field="view_count" currentSort={sort} currentDir={dir} onSort={handleSort} />
            <SortHeader label="Watch" field="watcher_count" currentSort={sort} currentDir={dir} onSort={handleSort} />
            <SortHeader label="Bids" field="bid_count" currentSort={sort} currentDir={dir} onSort={handleSort} />
            <SortHeader label="Highest Bid" field="current_price" currentSort={sort} currentDir={dir} onSort={handleSort} />
            <StatusFilterHeader currentStatus={status} onFilter={handleFilter} />
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
