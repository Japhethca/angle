// assets/js/features/wallet/deposit-dialog.tsx
import { useState, useEffect } from "react";
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
import { depositToWallet, buildCSRFHeaders } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { toast } from "sonner";

interface DepositDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  suggestedAmount?: number;
}

const PRESET_AMOUNTS = [1000, 5000, 10000];
const MIN_DEPOSIT = 100;
const MAX_DEPOSIT = 10000000; // 10 million

export function DepositDialog({
  open,
  onOpenChange,
  suggestedAmount,
}: DepositDialogProps) {
  const [amount, setAmount] = useState(suggestedAmount || PRESET_AMOUNTS[0]);
  const [customAmount, setCustomAmount] = useState("");
  const [useCustom, setUseCustom] = useState(false);

  // Sync state with suggestedAmount prop when dialog opens
  useEffect(() => {
    if (open && suggestedAmount) {
      setAmount(suggestedAmount);
      setUseCustom(false);
      setCustomAmount("");
    }
  }, [open, suggestedAmount]);

  // Reset state when dialog closes
  useEffect(() => {
    if (!open) {
      setAmount(PRESET_AMOUNTS[0]);
      setCustomAmount("");
      setUseCustom(false);
    }
  }, [open]);

  const depositMutation = useAshMutation(
    async (depositAmount: number) => {
      return depositToWallet({
        input: { amount: depositAmount.toString() },
        fields: ["id", "balance", "totalDeposited"],
        headers: buildCSRFHeaders(),
      });
    },
    {
      onSuccess: () => {
        toast.success("Deposit successful! Your wallet has been updated.");
        onOpenChange(false);
        // Reload page to reflect new wallet balance
        window.location.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to process deposit");
      },
    }
  );

  const handleDeposit = () => {
    const finalAmount = useCustom ? parseFloat(customAmount) : amount;

    // Validate amount is a valid number
    if (isNaN(finalAmount)) {
      toast.error("Please enter a valid amount");
      return;
    }

    // Validate minimum deposit
    if (finalAmount < MIN_DEPOSIT) {
      toast.error(`Minimum deposit is ${formatNaira(MIN_DEPOSIT)}`);
      return;
    }

    // Validate maximum deposit
    if (finalAmount > MAX_DEPOSIT) {
      toast.error(`Maximum deposit is ${formatNaira(MAX_DEPOSIT)}`);
      return;
    }

    depositMutation.mutate(finalAmount);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Deposit to Wallet</DialogTitle>
          <DialogDescription>
            {suggestedAmount
              ? `Deposit ${formatNaira(suggestedAmount)} to place this bid`
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
                  {formatNaira(preset)}
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
                min={MIN_DEPOSIT}
                max={MAX_DEPOSIT}
                placeholder="Enter amount"
                value={customAmount}
                onChange={(e) => setCustomAmount(e.target.value)}
              />
              <p className="text-sm text-muted-foreground mt-1">
                Minimum: {formatNaira(MIN_DEPOSIT)} | Maximum: {formatNaira(MAX_DEPOSIT)}
              </p>
            </div>
          )}

          <Button
            className="w-full"
            onClick={handleDeposit}
            disabled={
              depositMutation.isPending ||
              (useCustom && (!customAmount || parseFloat(customAmount) < MIN_DEPOSIT))
            }
          >
            {depositMutation.isPending ? "Processing..." : "Deposit"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
