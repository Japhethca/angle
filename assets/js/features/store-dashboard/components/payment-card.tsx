import { cn } from "@/lib/utils";
import type { SellerPaymentCard } from "@/ash_rpc";

type Order = SellerPaymentCard[number];

function formatCurrency(value: string | number | null | undefined): string {
  if (value == null) return "\u20A60";
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "\u20A60";
  return "\u20A6" + num.toLocaleString("en-NG", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function formatDate(dateStr: string | null | undefined): string {
  if (!dateStr) return "--";
  const date = new Date(dateStr);
  const day = String(date.getDate()).padStart(2, "0");
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const year = String(date.getFullYear()).slice(2);
  return `${day}/${month}/${year}`;
}

function PaymentStatusBadge({ status }: { status: string | null | undefined }) {
  const paidStatuses = ["paid", "completed", "dispatched"];
  const isPaid = paidStatuses.includes(status || "");
  const isPending = status === "payment_pending";

  const label = isPaid ? "Paid" : isPending ? "Pending" : (status || "Unknown");
  const className = isPaid
    ? "bg-feedback-success-muted text-feedback-success"
    : isPending
      ? "bg-orange-100 text-orange-700"
      : "bg-surface-secondary text-content-tertiary";

  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium capitalize", className)}>
      {label}
    </span>
  );
}

interface PaymentCardProps {
  order: Order;
}

export function PaymentCard({ order }: PaymentCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-white p-4">
      <div className="flex items-start justify-between">
        <div className="min-w-0 flex-1">
          <h3 className="truncate text-sm font-medium text-content">
            {order.item?.title || "Untitled"}
          </h3>
          <p className="mt-1 text-lg font-semibold text-content">
            {formatCurrency(order.amount)}
          </p>
        </div>
        <PaymentStatusBadge status={order.status} />
      </div>
      <div className="mt-3 flex items-center gap-3 text-xs text-content-placeholder">
        <span>#{order.paymentReference || "--"}</span>
        <span>&bull;</span>
        <span>{formatDate(order.createdAt)}</span>
      </div>
    </div>
  );
}
