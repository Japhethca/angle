import type { HistoryBidCard as HistoryBidCardType } from "@/ash_rpc";
import { HistoryBidCard } from "./history-bid-card";

interface HistoryBidsListProps {
  bids: HistoryBidCardType;
  wonItemIds: string[];
}

export function HistoryBidsList({ bids, wonItemIds }: HistoryBidsListProps) {
  if (bids.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">No bid history yet.</p>
      </div>
    );
  }

  return (
    <div className="space-y-4 lg:space-y-0">
      {bids.map((bid) => (
        <HistoryBidCard
          key={bid.id}
          bid={bid}
          didWin={wonItemIds.includes(bid.itemId)}
        />
      ))}
    </div>
  );
}
