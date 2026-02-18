import { Link } from "@inertiajs/react";
import { Gavel } from "lucide-react";
import type { ActiveBidCard as ActiveBidCardType } from "@/ash_rpc";
import { ResponsiveImage } from "@/components/image-upload";
import type { ImageData } from "@/lib/image-url";
import { formatNaira } from "@/lib/format";
import { CountdownTimer } from "@/shared/components/countdown-timer";
import { OutbidBadge } from "./outbid-badge";

type BidItem = ActiveBidCardType[number];

interface ActiveBidCardProps {
  bid: BidItem;
}

export function ActiveBidCard({ bid }: ActiveBidCardProps) {
  const item = bid.item;

  if (!item) return null;

  const isOutbid = item.currentPrice
    ? parseFloat(bid.amount) < parseFloat(item.currentPrice)
    : false;
  const itemUrl = `/items/${item.slug || item.id}`;

  return (
    <>
      {/* Desktop: horizontal card */}
      <div className="hidden border-b border-default pb-6 lg:flex lg:gap-6">
        <Link href={itemUrl} className="block w-[280px] shrink-0">
          <div className="aspect-square overflow-hidden rounded-xl bg-surface-muted">
            {item.coverImage ? (
              <ResponsiveImage image={item.coverImage as ImageData} sizes="280px" alt={item.title} />
            ) : (
              <div className="flex h-full items-center justify-center text-content-placeholder">
                <Gavel className="size-10" />
              </div>
            )}
          </div>
        </Link>
        <div className="flex flex-1 flex-col gap-2">
          <Link href={itemUrl}>
            <h3 className="text-base font-semibold text-content">{item.title}</h3>
          </Link>
          <p className="text-sm text-content-tertiary">
            Your bid{" "}
            <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
          </p>
          <div className="flex items-center gap-4 text-sm text-content-tertiary">
            {item.endTime && <CountdownTimer endTime={item.endTime} />}
            <span>{item.bidCount || 0} bids</span>
            <span>{item.watcherCount || 0} watching</span>
          </div>
          <p className="text-sm text-content-tertiary">
            Highest bid:{" "}
            <span className="font-medium text-content">
              {formatNaira(item.currentPrice || item.startingPrice)}
            </span>
          </p>
          {isOutbid && <OutbidBadge />}
          <div className="mt-2">
            <Link
              href={itemUrl}
              className="inline-flex items-center rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700"
            >
              Increase Bid
            </Link>
          </div>
        </div>
      </div>

      {/* Mobile: compact card */}
      <Link href={itemUrl} className="block lg:hidden">
        <div className="aspect-square overflow-hidden rounded-xl bg-surface-muted">
          {item.coverImage ? (
            <ResponsiveImage image={item.coverImage as ImageData} sizes="(max-width: 1024px) 50vw, 280px" alt={item.title} />
          ) : (
            <div className="flex h-full items-center justify-center text-content-placeholder">
              <Gavel className="size-8" />
            </div>
          )}
        </div>
        <div className="mt-2 space-y-1">
          <h3 className="line-clamp-2 text-sm font-medium text-content">{item.title}</h3>
          <p className="text-sm text-content-tertiary">
            Your bid:{" "}
            <span className="font-bold text-content">{formatNaira(bid.amount)}</span>
          </p>
          <div className="flex items-center gap-1 text-xs text-content-tertiary">
            {isOutbid ? (
              <span className="flex items-center gap-1 text-feedback-error">
                {item.endTime && <CountdownTimer endTime={item.endTime} />}
              </span>
            ) : (
              item.endTime && (
                <span>
                  Time left: <CountdownTimer endTime={item.endTime} />
                </span>
              )
            )}
          </div>
        </div>
      </Link>
    </>
  );
}
