import { useState } from "react";
import { router } from "@inertiajs/react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useAshMutation } from "@/hooks/use-ash-query";
import { withdrawFromWallet, buildCSRFHeaders } from "@/ash_rpc";
import { toast } from "sonner";

interface WithdrawDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  currentBalance: number;
  walletId: string;
  onSuccess?: () => void;
}

export function WithdrawDialog({
  open,
  onOpenChange,
  currentBalance,
  walletId,
  onSuccess,
}: WithdrawDialogProps) {
  const [amount, setAmount] = useState("");
  const [bankName, setBankName] = useState("");
  const [accountNumber, setAccountNumber] = useState("");
  const [accountName, setAccountName] = useState("");

  const withdrawMutation = useAshMutation(
    async (input: { amount: number; bank_details: { bank_name: string; account_number: string; account_name: string } }) => {
      return withdrawFromWallet({
        identity: walletId,
        input: {
          amount: input.amount.toString(),
          bank_details: input.bank_details,
        },
        fields: ["id", "balance", "totalWithdrawn"],
        headers: buildCSRFHeaders(),
      });
    },
    {
      onSuccess: () => {
        toast.success("Withdrawal request submitted. Processing in 1-3 business days.");
        onOpenChange(false);
        onSuccess?.();
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to process withdrawal");
      },
    }
  );

  const handleWithdraw = () => {
    const amountNum = parseFloat(amount);

    if (isNaN(amountNum) || amountNum <= 0) {
      toast.error("Amount must be greater than zero");
      return;
    }

    if (amountNum > currentBalance) {
      toast.error(
        `Insufficient balance (available: ₦${currentBalance.toLocaleString()})`
      );
      return;
    }

    if (!bankName || !accountNumber || !accountName) {
      toast.error("Please fill in all bank details");
      return;
    }

    withdrawMutation.mutate({
      amount: amountNum,
      bank_details: {
        bank_name: bankName,
        account_number: accountNumber,
        account_name: accountName,
      },
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Withdraw from Wallet</DialogTitle>
          <DialogDescription>
            Available balance: ₦{currentBalance.toLocaleString()}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <Label htmlFor="withdraw-amount">Amount</Label>
            <Input
              id="withdraw-amount"
              type="number"
              min="1"
              max={currentBalance}
              placeholder="Enter amount"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
          </div>

          <div>
            <Label htmlFor="bank-name">Bank Name</Label>
            <Select value={bankName} onValueChange={setBankName}>
              <SelectTrigger id="bank-name">
                <SelectValue placeholder="Select bank" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="access">Access Bank</SelectItem>
                <SelectItem value="gtbank">GTBank</SelectItem>
                <SelectItem value="zenith">Zenith Bank</SelectItem>
                <SelectItem value="firstbank">First Bank</SelectItem>
                <SelectItem value="uba">UBA</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div>
            <Label htmlFor="account-number">Account Number</Label>
            <Input
              id="account-number"
              type="text"
              maxLength={10}
              placeholder="0123456789"
              value={accountNumber}
              onChange={(e) => setAccountNumber(e.target.value)}
            />
          </div>

          <div>
            <Label htmlFor="account-name">Account Name</Label>
            <Input
              id="account-name"
              type="text"
              placeholder="John Doe"
              value={accountName}
              onChange={(e) => setAccountName(e.target.value)}
            />
          </div>

          <Button
            className="w-full"
            onClick={handleWithdraw}
            disabled={withdrawMutation.isPending}
          >
            {withdrawMutation.isPending ? "Processing..." : "Withdraw"}
          </Button>

          <p className="text-sm text-muted-foreground">
            Processing time: 1-3 business days
          </p>
        </div>
      </DialogContent>
    </Dialog>
  );
}
