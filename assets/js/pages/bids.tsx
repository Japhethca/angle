import { Head } from "@inertiajs/react";
import type { ActiveBidCard, WonOrderCard, HistoryBidCard } from "@/ash_rpc";
import {
  BidsLayout,
  ActiveBidsList,
  WonBidsList,
  HistoryBidsList,
} from "@/features/bidding";

interface BidsPageProps {
  tab: string;
  bids?: ActiveBidCard | HistoryBidCard;
  orders?: WonOrderCard;
  won_item_ids?: string[];
}

export default function Bids({
  tab = "active",
  bids = [],
  orders = [],
  won_item_ids = [],
}: BidsPageProps) {
  return (
    <>
      <Head title="My Bids" />
      <BidsLayout tab={tab}>
        {tab === "active" && (
          <ActiveBidsList bids={bids as ActiveBidCard} />
        )}
        {tab === "won" && (
          <WonBidsList orders={orders as WonOrderCard} />
        )}
        {tab === "history" && (
          <HistoryBidsList
            bids={bids as HistoryBidCard}
            wonItemIds={won_item_ids}
          />
        )}
      </BidsLayout>
    </>
  );
}
