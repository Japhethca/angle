import { useState } from "react";
import { AlertCircle, CheckCircle2, Wallet, Phone, IdCard } from "lucide-react";
import { router } from "@inertiajs/react";
import { formatNaira } from "@/lib/format";
import { DepositDialog } from "@/features/wallet";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";

interface RequirementModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  errorMessage: string;
  walletId?: string;
  currentBalance?: number;
}

interface Requirement {
  type: "wallet" | "phone" | "id";
  met: boolean;
  label: string;
  description: string;
  actionLabel?: string;
  actionUrl?: string;
}

function parseRequirements(errorMessage: string, currentBalance?: number): {
  requirements: Requirement[];
  hasWalletIssue: boolean;
  requiredAmount?: number;
} {
  const requirements: Requirement[] = [];
  let hasWalletIssue = false;
  let requiredAmount: number | undefined;

  // Check for wallet balance requirement
  const walletMatch = errorMessage.match(/Minimum wallet balance of ₦([\d,]+) required/);
  if (walletMatch) {
    hasWalletIssue = true;
    requiredAmount = parseFloat(walletMatch[1].replace(/,/g, ""));
    requirements.push({
      type: "wallet",
      met: false,
      label: "Wallet Balance",
      description: `Minimum balance of ${formatNaira(requiredAmount)} required${
        currentBalance !== undefined ? ` (Current: ${formatNaira(currentBalance)})` : ""
      }`,
      actionLabel: "Deposit Funds",
    });
  } else if (errorMessage.includes("create a wallet")) {
    hasWalletIssue = true;
    requirements.push({
      type: "wallet",
      met: false,
      label: "Wallet Setup",
      description: "You need to set up your wallet before bidding",
      actionLabel: "Go to Settings",
      actionUrl: "/settings/payments",
    });
  }

  // Check for phone verification
  if (errorMessage.includes("verify your phone number")) {
    requirements.push({
      type: "phone",
      met: false,
      label: "Phone Verification",
      description: "Verify your phone number to place bids",
      actionLabel: "Verify Phone",
      actionUrl: "/settings/account",
    });
  }

  // Check for ID verification
  if (errorMessage.includes("ID verification") || errorMessage.includes("upload your ID")) {
    requirements.push({
      type: "id",
      met: false,
      label: "ID Verification",
      description: "Items ≥₦50,000 require ID verification",
      actionLabel: "Upload ID",
      actionUrl: "/settings/account",
    });
  }

  return { requirements, hasWalletIssue, requiredAmount };
}

function RequirementIcon({ type }: { type: "wallet" | "phone" | "id" }) {
  const Icon = type === "wallet" ? Wallet : type === "phone" ? Phone : IdCard;
  return <Icon className="size-5 text-content-tertiary" />;
}

function RequirementItem({
  requirement,
  onAction,
}: {
  requirement: Requirement;
  onAction: () => void;
}) {
  return (
    <div className="flex items-start gap-3 rounded-lg border border-strong bg-surface-muted p-4">
      <div className="mt-0.5">
        {requirement.met ? (
          <CheckCircle2 className="size-5 text-feedback-success" />
        ) : (
          <RequirementIcon type={requirement.type} />
        )}
      </div>
      <div className="flex-1 space-y-1">
        <p className="text-sm font-medium text-content">{requirement.label}</p>
        <p className="text-xs text-content-secondary">{requirement.description}</p>
        {!requirement.met && requirement.actionLabel && (
          <Button variant="link" size="sm" className="h-auto p-0 text-xs" onClick={onAction}>
            {requirement.actionLabel}
          </Button>
        )}
      </div>
      {!requirement.met && (
        <AlertCircle className="size-5 shrink-0 text-feedback-warning" />
      )}
    </div>
  );
}

export function RequirementModal({
  open,
  onOpenChange,
  errorMessage,
  walletId,
  currentBalance,
}: RequirementModalProps) {
  const [depositOpen, setDepositOpen] = useState(false);
  const { requirements, hasWalletIssue, requiredAmount } = parseRequirements(
    errorMessage,
    currentBalance
  );

  const handleAction = (requirement: Requirement) => {
    if (requirement.type === "wallet" && requirement.actionLabel === "Deposit Funds" && walletId) {
      // Open deposit dialog with suggested amount
      const depositAmount = requiredAmount
        ? Math.ceil((requiredAmount - (currentBalance || 0)) / 1000) * 1000
        : undefined;
      setDepositOpen(true);
    } else if (requirement.actionUrl) {
      // Navigate to settings page
      router.visit(requirement.actionUrl);
      onOpenChange(false);
    }
  };

  const allRequirementsMet = requirements.every((r) => r.met);

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent className="max-w-md">
          <DialogHeader>
            <DialogTitle>Bidding Requirements</DialogTitle>
            <DialogDescription>
              {allRequirementsMet
                ? "All requirements met! You can now place your bid."
                : "Complete the following requirements to place your bid"}
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-3">
            {requirements.length === 0 ? (
              <Alert>
                <AlertCircle className="size-4" />
                <AlertDescription>{errorMessage}</AlertDescription>
              </Alert>
            ) : (
              requirements.map((requirement, index) => (
                <RequirementItem
                  key={index}
                  requirement={requirement}
                  onAction={() => handleAction(requirement)}
                />
              ))
            )}
          </div>

          {allRequirementsMet && (
            <Button className="w-full" onClick={() => onOpenChange(false)}>
              Continue to Bid
            </Button>
          )}
        </DialogContent>
      </Dialog>

      {hasWalletIssue && walletId && (
        <DepositDialog
          open={depositOpen}
          onOpenChange={setDepositOpen}
          suggestedAmount={
            requiredAmount && currentBalance !== undefined
              ? Math.max(0, Math.ceil((requiredAmount - currentBalance) / 1000) * 1000)
              : requiredAmount
          }
          walletId={walletId}
        />
      )}
    </>
  );
}
