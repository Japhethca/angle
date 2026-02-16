import type { ActiveBidCard as ActiveBidCardType } from "@/ash_rpc";
import { ActiveBidCard } from "./active-bid-card";

interface ActiveBidsListProps {
  bids: ActiveBidCardType;
}

export function ActiveBidsList({ bids }: ActiveBidsListProps) {
  if (bids.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">
          You haven't placed any bids on active auctions yet.
        </p>
      </div>
    );
  }

  return (
    <>
      {/* Desktop: vertical list */}
      <div className="hidden space-y-6 lg:block">
        {bids.map((bid) => (
          <ActiveBidCard key={bid.id} bid={bid} />
        ))}
      </div>

      {/* Mobile: 2-column grid */}
      <div className="grid grid-cols-2 gap-4 lg:hidden">
        {bids.map((bid) => (
          <ActiveBidCard key={bid.id} bid={bid} />
        ))}
      </div>
    </>
  );
}
