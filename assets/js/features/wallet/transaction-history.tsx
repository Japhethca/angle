// assets/js/features/wallet/transaction-history.tsx
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { formatCurrency } from "@/lib/utils";

interface Transaction {
  id: string;
  type: "deposit" | "withdrawal" | "purchase" | "sale_credit" | "refund";
  amount: number;
  balance_after: number;
  inserted_at: string;
}

interface TransactionHistoryProps {
  transactions: Transaction[];
}

const TYPE_LABELS: Record<Transaction["type"], string> = {
  deposit: "Deposit",
  withdrawal: "Withdrawal",
  purchase: "Purchase",
  sale_credit: "Sale Credit",
  refund: "Refund",
};

const TYPE_VARIANTS: Record<
  Transaction["type"],
  "default" | "secondary" | "destructive"
> = {
  deposit: "default",
  withdrawal: "secondary",
  purchase: "destructive",
  sale_credit: "default",
  refund: "default",
};

export function TransactionHistory({ transactions }: TransactionHistoryProps) {
  if (transactions.length === 0) {
    return (
      <div className="text-center py-8 text-muted-foreground">
        No transactions yet
      </div>
    );
  }

  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>Date</TableHead>
          <TableHead>Type</TableHead>
          <TableHead className="text-right">Amount</TableHead>
          <TableHead className="text-right">Balance After</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {transactions.map((transaction) => (
          <TableRow key={transaction.id}>
            <TableCell>
              {new Date(transaction.inserted_at).toLocaleDateString("en-NG", {
                year: "numeric",
                month: "short",
                day: "numeric",
                hour: "2-digit",
                minute: "2-digit",
              })}
            </TableCell>
            <TableCell>
              <Badge variant={TYPE_VARIANTS[transaction.type]}>
                {TYPE_LABELS[transaction.type]}
              </Badge>
            </TableCell>
            <TableCell className="text-right font-medium">
              {transaction.type === "withdrawal" ||
              transaction.type === "purchase"
                ? "-"
                : "+"}
              {formatCurrency(transaction.amount, "NGN")}
            </TableCell>
            <TableCell className="text-right">
              {formatCurrency(transaction.balance_after, "NGN")}
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
