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
