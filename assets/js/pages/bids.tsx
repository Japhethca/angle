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
  | { tab: "won"; orders: WonOrderCard }
  | { tab: "history"; bids: HistoryBidCard; won_item_ids: string[] };

export default function Bids(props: BidsPageProps) {
  const tab = props.tab;

  return (
    <>
      <Head title="My Bids" />
      <BidsLayout tab={tab}>
        {tab === "active" && <ActiveBidsList bids={props.bids} />}
        {tab === "won" && <WonBidsList orders={props.orders} />}
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
