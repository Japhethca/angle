import { router } from "@inertiajs/react";
import { toast } from "sonner";
import type { WonOrderCard as WonOrderCardType } from "@/ash_rpc";
import { payOrder, confirmReceipt, buildCSRFHeaders } from "@/ash_rpc";
import { useAshMutation } from "@/hooks/use-ash-query";
import { WonBidCard } from "./won-bid-card";

interface WonBidsListProps {
  orders: WonOrderCardType;
}

export function WonBidsList({ orders }: WonBidsListProps) {
  const { mutate: handlePay, isPending: payPending } = useAshMutation(
    (orderId: string) =>
      payOrder({
        identity: orderId,
        input: { paymentReference: `PSK_${Date.now()}` }, // TODO: integrate real Paystack flow
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Payment processed!");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Payment failed");
      },
    },
  );

  const { mutate: handleConfirmReceipt, isPending: confirmPending } =
    useAshMutation(
      (orderId: string) =>
        confirmReceipt({
          identity: orderId,
          headers: buildCSRFHeaders(),
        }),
      {
        onSuccess: () => {
          toast.success("Receipt confirmed!");
          router.reload();
        },
        onError: (error) => {
          toast.error(error.message || "Failed to confirm receipt");
        },
      },
    );

  if (orders.length === 0) {
    return (
      <div className="py-12 text-center">
        <p className="text-sm text-content-tertiary">
          You haven't won any auctions yet.
        </p>
      </div>
    );
  }

  return (
    <div>
      <p className="mb-4 text-sm text-content-tertiary">
        Congrats, you've won these bids!
      </p>
      <div className="space-y-4 lg:space-y-0">
        {orders.map((order) => (
          <WonBidCard
            key={order.id}
            order={order}
            onPay={handlePay}
            onConfirmReceipt={handleConfirmReceipt}
            payPending={payPending}
            confirmPending={confirmPending}
          />
        ))}
      </div>
    </div>
  );
}
