import { Link } from "@inertiajs/react";
import { MessageCircle } from "lucide-react";
import type { WonOrderCard as WonOrderCardType } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { cn } from "@/lib/utils";

type OrderItem = WonOrderCardType[number];

interface WonBidCardProps {
  order: OrderItem;
  onPay?: (orderId: string) => void;
  onConfirmReceipt?: (orderId: string) => void;
  payPending?: boolean;
  confirmPending?: boolean;
}

const statusConfig: Record<string, { label: string; className: string }> = {
  payment_pending: {
    label: "Payment pending",
    className: "bg-amber-50 text-amber-700 border-amber-200",
  },
  paid: {
    label: "Awaiting delivery",
    className: "bg-green-50 text-green-700 border-green-200",
  },
  dispatched: {
    label: "Awaiting delivery",
    className: "bg-green-50 text-green-700 border-green-200",
  },
  completed: {
    label: "Completed",
    className: "bg-green-50 text-green-700 border-green-200",
  },
};

function getWhatsAppUrl(
  phone: string | null,
  itemTitle: string,
): string | null {
  if (!phone) return null;
  const cleanPhone = phone.replace(/[^0-9+]/g, "");
  const message = encodeURIComponent(
    `Hi, I won the auction for "${itemTitle}" on Angle. I'd like to arrange delivery.`,
  );
  return `https://wa.me/${cleanPhone}?text=${message}`;
}

export function WonBidCard({
  order,
  onPay,
  onConfirmReceipt,
  payPending,
  confirmPending,
}: WonBidCardProps) {
  const status = statusConfig[order.status] || statusConfig.payment_pending;
  const whatsAppUrl = getWhatsAppUrl(
    order.seller?.whatsappNumber || null,
    order.item?.title || "",
  );

  return (
    <>
      {/* Desktop */}
      <div className="hidden items-center gap-4 border-b border-default py-4 lg:flex">
        <Link
          href={`/items/${order.item?.slug || order.item?.id}`}
          className="block size-20 shrink-0"
        >
          <div className="size-full rounded-lg bg-surface-muted" />
        </Link>

        <div className="min-w-0 flex-1">
          <div className="flex items-center gap-3">
            <Link href={`/items/${order.item?.slug || order.item?.id}`}>
              <h3 className="text-sm font-medium text-content">
                {order.item?.title}
              </h3>
            </Link>
            <span
              className={cn(
                "rounded-full border px-2.5 py-0.5 text-xs font-medium",
                status.className,
              )}
            >
              {status.label}
            </span>
          </div>
          <div className="mt-1 flex items-center gap-2 text-sm">
            <span className="font-bold text-content">
              {formatNaira(order.amount)}
            </span>
            <span className="text-content-tertiary">&middot;</span>
            <span className="text-content-tertiary">
              {order.seller?.username || order.seller?.fullName}
            </span>
          </div>
        </div>

        <div className="flex items-center gap-3">
          {whatsAppUrl && order.status !== "payment_pending" && (
            <a
              href={whatsAppUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="flex size-10 items-center justify-center rounded-full border border-default hover:bg-surface-muted"
            >
              <MessageCircle className="size-5 text-content-tertiary" />
            </a>
          )}
          {order.status === "payment_pending" && onPay && (
            <button
              onClick={() => onPay(order.id)}
              disabled={payPending}
              className="rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {payPending ? "Processing..." : "Pay"}
            </button>
          )}
          {order.status === "dispatched" && onConfirmReceipt && (
            <button
              onClick={() => onConfirmReceipt(order.id)}
              disabled={confirmPending}
              className="rounded-full bg-primary-600 px-6 py-2.5 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {confirmPending ? "Confirming..." : "Confirm Receipt"}
            </button>
          )}
        </div>
      </div>

      {/* Mobile */}
      <div className="space-y-3 rounded-xl border border-default p-4 lg:hidden">
        <div className="flex items-start gap-3">
          <Link
            href={`/items/${order.item?.slug || order.item?.id}`}
            className="block size-20 shrink-0"
          >
            <div className="size-full rounded-lg bg-surface-muted" />
          </Link>
          <div className="min-w-0 flex-1">
            <span
              className={cn(
                "mb-1 inline-block rounded-full border px-2 py-0.5 text-xs font-medium",
                status.className,
              )}
            >
              {status.label}
            </span>
            <Link href={`/items/${order.item?.slug || order.item?.id}`}>
              <h3 className="line-clamp-2 text-sm font-medium text-content">
                {order.item?.title}
              </h3>
            </Link>
            <div className="mt-1 flex items-center gap-2 text-sm">
              <span className="font-bold text-content">
                {formatNaira(order.amount)}
              </span>
              <span className="text-content-tertiary">&middot;</span>
              <span className="text-content-tertiary">
                {order.seller?.username || order.seller?.fullName}
              </span>
            </div>
          </div>
        </div>

        {order.status === "payment_pending" && onPay && (
          <button
            onClick={() => onPay(order.id)}
            disabled={payPending}
            className="w-full rounded-full bg-primary-600 py-3 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
          >
            {payPending ? "Processing..." : "Pay"}
          </button>
        )}
        {order.status === "dispatched" && onConfirmReceipt && (
          <div className="flex items-center gap-3">
            {whatsAppUrl && (
              <a
                href={whatsAppUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="flex size-12 items-center justify-center rounded-full border border-default"
              >
                <MessageCircle className="size-5 text-content-tertiary" />
              </a>
            )}
            <button
              onClick={() => onConfirmReceipt(order.id)}
              disabled={confirmPending}
              className="flex-1 rounded-full bg-primary-600 py-3 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
            >
              {confirmPending ? "Confirming..." : "Confirm Receipt"}
            </button>
          </div>
        )}
      </div>
    </>
  );
}
