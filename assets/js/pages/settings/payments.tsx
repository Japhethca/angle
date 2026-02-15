import { Head } from "@inertiajs/react";
import { SettingsLayout } from "@/features/settings";
import { PaymentMethodsSection } from "@/features/settings/components/payment-methods-section";
import { PayoutMethodsSection } from "@/features/settings/components/payout-methods-section";
import { AutoChargeSection } from "@/features/settings/components/auto-charge-section";

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

interface SettingsPaymentsProps {
  user: PaymentsUser;
  payment_methods: PaymentMethod[];
  payout_methods: PayoutMethod[];
}

export default function SettingsPayments({ user, payment_methods, payout_methods }: SettingsPaymentsProps) {
  return (
    <>
      <Head title="Payment Settings" />
      <SettingsLayout title="Payments">
        <div className="space-y-8">
          <PaymentMethodsSection methods={payment_methods} userEmail={user.email} />
          <PayoutMethodsSection methods={payout_methods} />
          <AutoChargeSection userId={user.id} autoCharge={user.auto_charge} />
        </div>
      </SettingsLayout>
    </>
  );
}
