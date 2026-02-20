// assets/js/features/wallet/deposit-dialog.tsx
import { useState } from "react";
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
import { useAshMutation } from "@/hooks/use-ash-query";
import { toast } from "sonner";

interface DepositDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  suggestedAmount?: number;
}

const PRESET_AMOUNTS = [1000, 5000, 10000];

export function DepositDialog({
  open,
  onOpenChange,
  suggestedAmount,
}: DepositDialogProps) {
  const [amount, setAmount] = useState(suggestedAmount || PRESET_AMOUNTS[0]);
  const [customAmount, setCustomAmount] = useState("");
  const [useCustom, setUseCustom] = useState(false);

  const depositMutation = useAshMutation({
    resource: "UserWallet",
    action: "deposit",
    onSuccess: (data: { payment_url: string }) => {
      window.location.href = data.payment_url;
    },
    onError: (error) => {
      toast.error(error.message || "Failed to initiate deposit");
    },
  });

  const handleDeposit = () => {
    const finalAmount = useCustom ? parseFloat(customAmount) : amount;

    if (finalAmount < 100) {
      toast.error("Minimum deposit is ₦100");
      return;
    }

    depositMutation.mutate({ amount: finalAmount });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Deposit to Wallet</DialogTitle>
          <DialogDescription>
            {suggestedAmount
              ? `Deposit ₦${suggestedAmount.toLocaleString()} to place this bid`
              : "Add funds to your wallet to bid on items"}
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          {!useCustom && (
            <div className="grid grid-cols-3 gap-2">
              {PRESET_AMOUNTS.map((preset) => (
                <Button
                  key={preset}
                  variant={amount === preset ? "default" : "outline"}
                  onClick={() => setAmount(preset)}
                >
                  ₦{preset.toLocaleString()}
                </Button>
              ))}
            </div>
          )}

          <div>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => setUseCustom(!useCustom)}
            >
              {useCustom ? "Use preset amounts" : "Enter custom amount"}
            </Button>
          </div>

          {useCustom && (
            <div>
              <Label htmlFor="custom-amount">Custom Amount</Label>
              <Input
                id="custom-amount"
                type="number"
                min="100"
                placeholder="Enter amount"
                value={customAmount}
                onChange={(e) => setCustomAmount(e.target.value)}
              />
              <p className="text-sm text-muted-foreground mt-1">
                Minimum: ₦100
              </p>
            </div>
          )}

          <Button
            className="w-full"
            onClick={handleDeposit}
            disabled={
              depositMutation.isPending ||
              (useCustom && (!customAmount || parseFloat(customAmount) < 100))
            }
          >
            {depositMutation.isPending ? "Processing..." : "Deposit"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
