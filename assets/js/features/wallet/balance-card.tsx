// assets/js/features/wallet/balance-card.tsx
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { formatCurrency } from "@/lib/utils";

interface BalanceCardProps {
  balance: number;
  onDeposit: () => void;
  onWithdraw: () => void;
}

export function BalanceCard({ balance, onDeposit, onWithdraw }: BalanceCardProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Wallet Balance</CardTitle>
      </CardHeader>
      <CardContent>
        <p className="text-3xl font-bold mb-4">
          {formatCurrency(balance, "NGN")}
        </p>
        <div className="flex gap-2">
          <Button onClick={onDeposit}>Deposit</Button>
          <Button variant="outline" onClick={onWithdraw}>
            Withdraw
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
