import { Link } from "@inertiajs/react";
import { Gavel } from "lucide-react";
import type { SellerDashboardCard } from "@/ash_rpc";
import { ResponsiveImage } from "@/components/image-upload";
import type { ImageData } from "@/lib/image-url";
import { ListingActionsMenu } from "./listing-actions-menu";
import { StatusBadge } from "./status-badge";
import { formatCurrency } from "../utils";

type Item = SellerDashboardCard[number] & { coverImage?: ImageData | null };

interface ListingCardProps {
  item: Item;
}

export function ListingCard({ item }: ListingCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-surface p-4">
      <div className="flex items-start gap-3">
        <div className="size-16 shrink-0 overflow-hidden rounded-lg bg-surface-muted">
          {item.coverImage ? (
            <ResponsiveImage image={item.coverImage as ImageData} sizes="64px" alt={item.title || ""} />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-5" />
            </div>
          )}
        </div>
        <div className="flex min-w-0 flex-1 items-start justify-between">
          <div className="min-w-0 flex-1">
            <Link
              href={item.publicationStatus === "draft"
                ? `/store/listings/${item.id}/preview`
                : `/items/${item.slug || item.id}`}
              className="block truncate text-sm font-medium text-content hover:text-primary-600 hover:underline"
            >
              {item.title}
            </Link>
            <p className="mt-1 text-sm text-content-secondary">
              Highest bid: {formatCurrency(item.currentPrice || item.startingPrice)}
            </p>
            <p className="mt-1 text-xs text-content-placeholder">
              {item.viewCount ?? 0} Views {"\u2022"} {item.bidCount ?? 0} Bids {"\u2022"} {item.watcherCount ?? 0} Watchers
            </p>
          </div>
          <ListingActionsMenu id={item.id} slug={item.slug || item.id} publicationStatus={item.publicationStatus} />
        </div>
      </div>
      <div className="mt-3">
        <StatusBadge publicationStatus={item.publicationStatus} auctionStatus={item.auctionStatus} />
      </div>
    </div>
  );
}
