interface BalanceCardProps {
  label: string;
  amount: string;
}

export function BalanceCard({ label, amount }: BalanceCardProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-surface p-4">
      <p className="text-sm text-content-tertiary">{label}</p>
      <p className="mt-2 text-2xl font-semibold text-content">{amount}</p>
    </div>
  );
}
