import { Head } from "@inertiajs/react";
import { Wallet } from "lucide-react";
import { toast } from "sonner";
import type { SellerPaymentCard } from "@/ash_rpc";
import {
  StoreLayout,
  BalanceCard,
  PaymentTable,
  PaymentCard,
} from "@/features/store-dashboard";

type Order = SellerPaymentCard[number];

interface Balance {
  balance: string;
  pending: string;
}

interface StorePaymentsProps {
  orders: Order[];
  balance: Balance;
}

function formatCurrency(value: string | number | null | undefined): string {
  if (value == null) return "\u20A60";
  const num = typeof value === "string" ? parseFloat(value) : value;
  if (isNaN(num)) return "\u20A60";
  return "\u20A6" + num.toLocaleString("en-NG", { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

export default function StorePayments({ orders = [], balance }: StorePaymentsProps) {
  const defaultBalance: Balance = { balance: "0", pending: "0" };
  const b = balance || defaultBalance;

  const handleWithdraw = () => {
    toast.info("Coming soon");
  };

  return (
    <>
      <Head title="Store - Payments" />
      <StoreLayout title="Payments">
        {/* Balance cards */}
        <div className="grid grid-cols-2 gap-4">
          <BalanceCard label="Balance" amount={formatCurrency(b.balance)} />
          <BalanceCard label="Pending" amount={formatCurrency(b.pending)} />
        </div>

        {/* Payout info + withdraw */}
        <div className="mt-4 flex items-center justify-between">
          <p className="text-sm text-content-placeholder">Next Payout: --</p>
          <button
            onClick={handleWithdraw}
            className="rounded-full border border-primary-600 px-5 py-2 text-sm font-medium text-primary-600 transition-colors hover:bg-primary-600/5"
          >
            Withdraw
          </button>
        </div>

        {/* Payments section */}
        <div className="mt-8">
          <h2 className="mb-4 text-lg font-semibold text-content">Payments</h2>

          {orders.length > 0 ? (
            <>
              {/* Desktop table */}
              <div className="hidden lg:block">
                <div className="rounded-xl border border-surface-muted bg-white">
                  <PaymentTable orders={orders} />
                </div>
              </div>

              {/* Mobile cards */}
              <div className="flex flex-col gap-3 lg:hidden">
                {orders.map((order) => (
                  <PaymentCard key={order.id} order={order} />
                ))}
              </div>
            </>
          ) : (
            <div className="flex flex-col items-center justify-center rounded-xl border border-surface-muted bg-white py-16 text-center">
              <Wallet className="mb-3 size-12 text-surface-emphasis" />
              <p className="text-lg text-content-tertiary">No payments yet</p>
              <p className="mt-1 text-sm text-content-placeholder">
                Payments will appear here when orders are placed
              </p>
            </div>
          )}
        </div>
      </StoreLayout>
    </>
  );
}
