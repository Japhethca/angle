import { useState } from "react";
import { Head } from "@inertiajs/react";
import { SettingsLayout } from "@/features/settings";
import { PaymentMethodsSection } from "@/features/settings/components/payment-methods-section";
import { PayoutMethodsSection } from "@/features/settings/components/payout-methods-section";
import { AutoChargeSection } from "@/features/settings/components/auto-charge-section";
import {
  BalanceCard,
  DepositDialog,
  WithdrawDialog,
  TransactionHistory,
} from "@/features/wallet";

interface PaymentMethod {
  id: string;
  card_type: string;
  last_four: string;
  exp_month: string;
  exp_year: string;
  bank: string | null;
  is_default: boolean;
  inserted_at: string;
}

interface PayoutMethod {
  id: string;
  bank_name: string;
  account_number: string;
  account_name: string;
  is_default: boolean;
  inserted_at: string;
}

interface PaymentsUser {
  id: string;
  email: string;
  auto_charge: boolean;
}

interface Wallet {
  id: string;
  balance: number;
  total_deposited: number;
  total_withdrawn: number;
}

interface Transaction {
  id: string;
  type: "deposit" | "withdrawal" | "purchase" | "sale_credit" | "refund";
  amount: number;
  balance_after: number;
  inserted_at: string;
}

interface SettingsPaymentsProps {
  user: PaymentsUser;
  payment_methods: PaymentMethod[];
  payout_methods: PayoutMethod[];
  wallet: Wallet;
  transactions: Transaction[];
}

export default function SettingsPayments({
  user,
  payment_methods,
  payout_methods,
  wallet,
  transactions,
}: SettingsPaymentsProps) {
  const [depositOpen, setDepositOpen] = useState(false);
  const [withdrawOpen, setWithdrawOpen] = useState(false);

  return (
    <>
      <Head title="Payment Settings" />
      <SettingsLayout title="Payments">
        <div className="space-y-8">
          <BalanceCard
            balance={wallet.balance}
            onDeposit={() => setDepositOpen(true)}
            onWithdraw={() => setWithdrawOpen(true)}
          />

          <div>
            <h3 className="text-lg font-semibold mb-4">Transaction History</h3>
            <TransactionHistory transactions={transactions} />
          </div>

          <PaymentMethodsSection methods={payment_methods} userEmail={user.email} />
          <PayoutMethodsSection methods={payout_methods} />
          <AutoChargeSection userId={user.id} autoCharge={user.auto_charge} />
        </div>

        <DepositDialog
          open={depositOpen}
          onOpenChange={setDepositOpen}
          walletId={wallet.id}
        />

        <WithdrawDialog
          open={withdrawOpen}
          onOpenChange={setWithdrawOpen}
          currentBalance={wallet.balance}
          walletId={wallet.id}
          onSuccess={() => window.location.reload()}
        />
      </SettingsLayout>
    </>
  );
}
