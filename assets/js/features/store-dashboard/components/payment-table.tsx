import { cn } from "@/lib/utils";
import type { SellerPaymentCard } from "@/ash_rpc";
import { formatCurrency, formatDate } from "../utils";

type Order = SellerPaymentCard[number];

function PaymentStatusBadge({ status }: { status: string | null | undefined }) {
  const paidStatuses = ["paid", "completed", "dispatched"];
  const isPaid = paidStatuses.includes(status || "");
  const isPending = status === "payment_pending";

  const label = isPaid ? "Paid" : isPending ? "Pending" : (status || "Unknown");
  const className = isPaid
    ? "bg-feedback-success-muted text-feedback-success"
    : isPending
      ? "bg-orange-100 text-orange-700 dark:bg-orange-900/30 dark:text-orange-400"
      : "bg-surface-secondary text-content-tertiary";

  return (
    <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-medium capitalize", className)}>
      {label}
    </span>
  );
}

interface PaymentTableProps {
  orders: Order[];
}

export function PaymentTable({ orders }: PaymentTableProps) {
  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b border-surface-muted text-left text-xs font-medium uppercase tracking-wider text-content-tertiary">
            <th className="px-4 py-3">Item</th>
            <th className="px-4 py-3">Amount</th>
            <th className="px-4 py-3">Ref ID</th>
            <th className="px-4 py-3">Status</th>
            <th className="px-4 py-3">Date</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-surface-muted">
          {orders.map((order) => (
            <tr key={order.id} className="transition-colors hover:bg-surface-secondary/50">
              <td className="px-4 py-3 text-sm font-medium text-content">
                {order.item?.title || "Untitled"}
              </td>
              <td className="px-4 py-3 text-sm text-content-secondary">
                {formatCurrency(order.amount)}
              </td>
              <td className="px-4 py-3 text-sm text-content-placeholder">
                #{order.paymentReference || "--"}
              </td>
              <td className="px-4 py-3">
                <PaymentStatusBadge status={order.status} />
              </td>
              <td className="px-4 py-3 text-sm text-content-placeholder">
                {formatDate(order.createdAt)}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
