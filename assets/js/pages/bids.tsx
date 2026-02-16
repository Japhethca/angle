import { Head } from "@inertiajs/react";
import type { ActiveBidCard, WonOrderCard, HistoryBidCard } from "@/ash_rpc";
import {
  BidsLayout,
  ActiveBidsList,
  WonBidsList,
  HistoryBidsList,
} from "@/features/bidding";

type BidsPageProps =
  | { tab: "active"; bids: ActiveBidCard }
  | {
      tab: "won";
      orders: WonOrderCard;
      reviews_by_order?: Record<string, any>;
    }
  | { tab: "history"; bids: HistoryBidCard; won_item_ids: string[] };

export default function Bids(props: BidsPageProps) {
  const tab = props.tab;

  return (
    <>
      <Head title="My Bids" />
      <BidsLayout tab={tab}>
        {tab === "active" && <ActiveBidsList bids={props.bids} />}
        {tab === "won" && (
          <WonBidsList
            orders={props.orders}
            reviewsByOrder={props.reviews_by_order}
          />
        )}
        {tab === "history" && (
          <HistoryBidsList
            bids={props.bids}
            wonItemIds={props.won_item_ids}
          />
        )}
      </BidsLayout>
    </>
  );
}
