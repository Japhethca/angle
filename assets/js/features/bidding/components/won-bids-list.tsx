import { useEffect, useState } from "react";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import type { WonOrderCard as WonOrderCardType } from "@/ash_rpc";
import { confirmReceipt, buildCSRFHeaders, getPhoenixCSRFToken } from "@/ash_rpc";
import { useAshMutation } from "@/hooks/use-ash-query";
import { WonBidCard } from "./won-bid-card";

interface WonBidsListProps {
  orders: WonOrderCardType;
}

export function WonBidsList({ orders }: WonBidsListProps) {
  const [payPendingId, setPayPendingId] = useState<string | null>(null);
  const [paystackReady, setPaystackReady] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    if ((window as any).PaystackPop) {
      setPaystackReady(true);
      return;
    }
    const script = document.createElement("script");
    script.src = "https://js.paystack.co/v2/inline.js";
    script.async = true;
    script.onload = () => setPaystackReady(true);
    document.body.appendChild(script);
    return () => {
      document.body.removeChild(script);
    };
  }, []);

  const handlePay = async (orderId: string) => {
    if (!paystackReady) {
      toast.error("Payment system is loading, please try again");
      return;
    }
    const csrfToken = getPhoenixCSRFToken();
    setPayPendingId(orderId);

    try {
      const res = await fetch("/api/payments/pay-order", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
        },
        body: JSON.stringify({ order_id: orderId }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        toast.error(data?.error || "Failed to initialize payment");
        return;
      }

      const data = await res.json();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const paystack = new (window as any).PaystackPop();
      paystack.resumeTransaction(data.access_code, {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        onSuccess: async (transaction: any) => {
          try {
            const verifyRes = await fetch("/api/payments/verify-order-payment", {
              method: "POST",
              headers: {
                "content-type": "application/json",
                ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
              },
              body: JSON.stringify({
                reference: transaction.reference,
                order_id: orderId,
              }),
            });

            if (!verifyRes.ok) {
              const errData = await verifyRes.json().catch(() => null);
              toast.error(errData?.error || "Payment verification failed");
              return;
            }

            toast.success("Payment processed!");
            router.reload();
          } catch {
            toast.error("Payment verification failed");
          }
        },
        onCancel: () => {
          toast.error("Payment was cancelled");
        },
      });
    } catch {
      toast.error("Failed to initialize payment");
    } finally {
      setPayPendingId(null);
    }
  };

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
            payPending={payPendingId === order.id}
            confirmPending={confirmPending}
          />
        ))}
      </div>
    </div>
  );
}
