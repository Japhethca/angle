# Phase 2 Frontend Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build UI for wallet deposits/withdrawals, phone OTP verification, ID document upload, and seller blacklist management

**Architecture:** Reuse existing Settings/Store pages, add new React components using shadcn/ui, integrate with AshTypescript RPC via TanStack Query hooks

**Tech Stack:** React 19, Inertia.js, shadcn/ui, TanStack Query, React Hook Form, Zod, AshTypescript RPC

---

## Prerequisites

**Before starting:**
1. Backend resources exist: UserWallet, UserVerification, SellerBlacklist
2. Ash TypeScript codegen completed: `mix ash_typescript.codegen`
3. Generated types available in `assets/js/ash_rpc.ts`

---

## Task 1: Wallet Balance Card Component

**Files:**
- Create: `assets/js/features/wallet/balance-card.tsx`
- Create: `assets/js/features/wallet/index.ts`

**Step 1: Create balance card component**

```tsx
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
```

**Step 2: Create barrel export**

```ts
// assets/js/features/wallet/index.ts
export { BalanceCard } from "./balance-card";
```

**Step 3: Commit**

```bash
git add assets/js/features/wallet/
git commit -m "feat: add wallet balance card component

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Deposit Dialog Component

**Files:**
- Create: `assets/js/features/wallet/deposit-dialog.tsx`
- Modify: `assets/js/features/wallet/index.ts`

**Step 1: Create deposit dialog component**

```tsx
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
```

**Step 2: Update barrel export**

```ts
// assets/js/features/wallet/index.ts
export { BalanceCard } from "./balance-card";
export { DepositDialog } from "./deposit-dialog";
```

**Step 3: Commit**

```bash
git add assets/js/features/wallet/
git commit -m "feat: add wallet deposit dialog with preset and custom amounts

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Withdraw Dialog Component

**Files:**
- Create: `assets/js/features/wallet/withdraw-dialog.tsx`
- Modify: `assets/js/features/wallet/index.ts`

**Step 1: Create withdraw dialog component**

```tsx
// assets/js/features/wallet/withdraw-dialog.tsx
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { useAshMutation } from "@/hooks/use-ash-query";
import { toast } from "sonner";

interface WithdrawDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  currentBalance: number;
  onSuccess?: () => void;
}

export function WithdrawDialog({
  open,
  onOpenChange,
  currentBalance,
  onSuccess,
}: WithdrawDialogProps) {
  const [amount, setAmount] = useState("");
  const [bankName, setBankName] = useState("");
  const [accountNumber, setAccountNumber] = useState("");
  const [accountName, setAccountName] = useState("");

  const withdrawMutation = useAshMutation({
    resource: "UserWallet",
    action: "withdraw",
    onSuccess: () => {
      toast.success("Withdrawal request submitted. Processing in 1-3 business days.");
      onOpenChange(false);
      onSuccess?.();
    },
    onError: (error) => {
      toast.error(error.message || "Failed to process withdrawal");
    },
  });

  const handleWithdraw = () => {
    const amountNum = parseFloat(amount);

    if (amountNum <= 0) {
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
```

**Step 2: Update barrel export**

```ts
// assets/js/features/wallet/index.ts
export { BalanceCard } from "./balance-card";
export { DepositDialog } from "./deposit-dialog";
export { WithdrawDialog } from "./withdraw-dialog";
```

**Step 3: Commit**

```bash
git add assets/js/features/wallet/
git commit -m "feat: add wallet withdraw dialog with bank details

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Transaction History Component

**Files:**
- Create: `assets/js/features/wallet/transaction-history.tsx`
- Modify: `assets/js/features/wallet/index.ts`

**Step 1: Create transaction history component**

```tsx
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
```

**Step 2: Update barrel export**

```ts
// assets/js/features/wallet/index.ts
export { BalanceCard } from "./balance-card";
export { DepositDialog } from "./deposit-dialog";
export { WithdrawDialog } from "./withdraw-dialog";
export { TransactionHistory } from "./transaction-history";
```

**Step 3: Commit**

```bash
git add assets/js/features/wallet/
git commit -m "feat: add wallet transaction history table

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Settings Payments Page (Wallet UI)

**Files:**
- Modify: `assets/js/pages/settings/payments.tsx`
- Modify: `lib/angle_web/controllers/settings_controller.ex`

**Step 1: Update Settings controller to load wallet data**

```elixir
# lib/angle_web/controllers/settings_controller.ex
# Add after existing payments/2 function or replace it

def payments(conn, _params) do
  user = conn.assigns.current_user

  # Load wallet and transactions
  wallet =
    Angle.Payments.UserWallet
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read_one!()

  transactions =
    Angle.Payments.WalletTransaction
    |> Ash.Query.filter(wallet_id == ^wallet.id)
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.limit(50)
    |> Ash.read!()

  conn
  |> assign_prop(:wallet, wallet)
  |> assign_prop(:transactions, transactions)
  |> render_inertia("settings/payments")
end
```

**Step 2: Update payments page component**

```tsx
// assets/js/pages/settings/payments.tsx
import { useState } from "react";
import { Head } from "@inertiajs/react";
import { SettingsLayout } from "@/features/settings";
import {
  BalanceCard,
  DepositDialog,
  WithdrawDialog,
  TransactionHistory,
} from "@/features/wallet";

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
  wallet: Wallet;
  transactions: Transaction[];
}

export default function SettingsPayments({
  wallet,
  transactions,
}: SettingsPaymentsProps) {
  const [depositOpen, setDepositOpen] = useState(false);
  const [withdrawOpen, setWithdrawOpen] = useState(false);

  return (
    <>
      <Head title="Payment Settings" />
      <SettingsLayout title="Payments">
        <div className="space-y-6">
          <BalanceCard
            balance={wallet.balance}
            onDeposit={() => setDepositOpen(true)}
            onWithdraw={() => setWithdrawOpen(true)}
          />

          <div>
            <h3 className="text-lg font-semibold mb-4">Transaction History</h3>
            <TransactionHistory transactions={transactions} />
          </div>
        </div>

        <DepositDialog
          open={depositOpen}
          onOpenChange={setDepositOpen}
        />

        <WithdrawDialog
          open={withdrawOpen}
          onOpenChange={setWithdrawOpen}
          currentBalance={wallet.balance}
          onSuccess={() => window.location.reload()}
        />
      </SettingsLayout>
    </>
  );
}
```

**Step 3: Run TypeScript type check**

```bash
cd assets && npx tsc --noEmit
```

Expected: No type errors

**Step 4: Test in browser**

```bash
# Ensure server is running on port 4113
# Navigate to http://localhost:4113/settings/payments
# Verify:
# - Balance card displays
# - Deposit button opens dialog
# - Withdraw button opens dialog
# - Transaction history shows (if any)
```

**Step 5: Commit**

```bash
git add lib/angle_web/controllers/settings_controller.ex assets/js/pages/settings/payments.tsx
git commit -m "feat: integrate wallet UI into settings payments page

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Phone Verification Component

**Files:**
- Create: `assets/js/features/verification/phone-verification.tsx`
- Create: `assets/js/features/verification/index.ts`

**Step 1: Create phone verification component**

```tsx
// assets/js/features/verification/phone-verification.tsx
import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAshMutation } from "@/hooks/use-ash-query";
import { toast } from "sonner";
import { CheckCircle2 } from "lucide-react";

interface PhoneVerificationProps {
  initialPhoneNumber?: string;
  phoneVerified: boolean;
  phoneVerifiedAt?: string;
  onVerified?: () => void;
}

export function PhoneVerification({
  initialPhoneNumber = "",
  phoneVerified,
  phoneVerifiedAt,
  onVerified,
}: PhoneVerificationProps) {
  const [phoneNumber, setPhoneNumber] = useState(initialPhoneNumber);
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState("");
  const [countdown, setCountdown] = useState(0);

  useEffect(() => {
    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [countdown]);

  const requestOtpMutation = useAshMutation({
    resource: "UserVerification",
    action: "request_phone_otp",
    onSuccess: (data: { otp_code?: string }) => {
      setOtpSent(true);
      setCountdown(60);
      toast.success("OTP sent to your phone");

      // In test mode, show OTP in console
      if (data.otp_code) {
        console.log("Test OTP:", data.otp_code);
        toast.info(`Test OTP: ${data.otp_code}`);
      }
    },
    onError: (error) => {
      toast.error(error.message || "Failed to send OTP");
    },
  });

  const verifyOtpMutation = useAshMutation({
    resource: "UserVerification",
    action: "verify_phone_otp",
    onSuccess: () => {
      toast.success("Phone number verified!");
      setOtpSent(false);
      setOtpCode("");
      onVerified?.();
    },
    onError: (error) => {
      toast.error(error.message || "Invalid OTP code");
      setOtpCode("");
    },
  });

  const handleSendOtp = () => {
    if (!phoneNumber || phoneNumber.length < 10) {
      toast.error("Please enter a valid phone number");
      return;
    }

    const fullNumber = `+234${phoneNumber}`;
    requestOtpMutation.mutate({ phone_number: fullNumber });
  };

  const handleVerifyOtp = () => {
    if (otpCode.length !== 6) {
      toast.error("Please enter 6-digit OTP");
      return;
    }

    verifyOtpMutation.mutate({ otp_code: otpCode });
  };

  if (phoneVerified) {
    return (
      <div className="flex items-center gap-2 text-green-600">
        <CheckCircle2 className="size-5" />
        <span>
          Verified{" "}
          {phoneVerifiedAt &&
            new Date(phoneVerifiedAt).toLocaleDateString("en-NG")}
        </span>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div>
        <Label htmlFor="phone">Phone Number</Label>
        <div className="flex gap-2">
          <div className="flex items-center gap-1 px-3 border rounded-md bg-muted">
            <span>🇳🇬</span>
            <span className="text-sm">234</span>
          </div>
          <Input
            id="phone"
            type="tel"
            placeholder="8012345678"
            maxLength={10}
            value={phoneNumber}
            onChange={(e) => setPhoneNumber(e.target.value)}
            disabled={otpSent}
          />
          <Button
            onClick={handleSendOtp}
            disabled={
              requestOtpMutation.isPending ||
              otpSent ||
              countdown > 0 ||
              !phoneNumber
            }
          >
            {requestOtpMutation.isPending
              ? "Sending..."
              : countdown > 0
                ? `${countdown}s`
                : "Send OTP"}
          </Button>
        </div>
      </div>

      {otpSent && (
        <div className="space-y-2 p-4 bg-muted rounded-md">
          <p className="text-sm text-muted-foreground">
            OTP sent to +234{phoneNumber.slice(-4).padStart(10, "*")}
          </p>
          <div className="flex gap-2">
            <Input
              type="text"
              placeholder="Enter 6-digit code"
              maxLength={6}
              value={otpCode}
              onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ""))}
              onKeyDown={(e) => {
                if (e.key === "Enter" && otpCode.length === 6) {
                  handleVerifyOtp();
                }
              }}
              autoFocus
            />
            <Button
              onClick={handleVerifyOtp}
              disabled={verifyOtpMutation.isPending || otpCode.length !== 6}
            >
              {verifyOtpMutation.isPending ? "Verifying..." : "Verify"}
            </Button>
          </div>
          {countdown === 0 && (
            <Button
              variant="ghost"
              size="sm"
              onClick={handleSendOtp}
              disabled={requestOtpMutation.isPending}
            >
              Resend OTP
            </Button>
          )}
        </div>
      )}
    </div>
  );
}
```

**Step 2: Create barrel export**

```ts
// assets/js/features/verification/index.ts
export { PhoneVerification } from "./phone-verification";
```

**Step 3: Commit**

```bash
git add assets/js/features/verification/
git commit -m "feat: add phone OTP verification component

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 7: ID Upload Component

**Files:**
- Create: `assets/js/features/verification/id-upload.tsx`
- Modify: `assets/js/features/verification/index.ts`

**Step 1: Create ID upload component**

```tsx
// assets/js/features/verification/id-upload.tsx
import { useState, useRef } from "react";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { useAshMutation } from "@/hooks/use-ash-query";
import { toast } from "sonner";
import { Upload, CheckCircle2, XCircle, Clock } from "lucide-react";

interface IdUploadProps {
  idDocumentUrl?: string;
  idVerificationStatus?: "pending" | "approved" | "rejected";
  idVerified: boolean;
  idVerifiedAt?: string;
  idRejectionReason?: string;
  onUploadSuccess?: () => void;
}

export function IdUpload({
  idDocumentUrl,
  idVerificationStatus = "pending",
  idVerified,
  idVerifiedAt,
  idRejectionReason,
  onUploadSuccess,
}: IdUploadProps) {
  const [uploading, setUploading] = useState(false);
  const [dragActive, setDragActive] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const uploadMutation = useAshMutation({
    resource: "UserVerification",
    action: "upload_id_document",
    onSuccess: () => {
      setUploading(false);
      toast.success("ID document uploaded for review");
      onUploadSuccess?.();
    },
    onError: (error) => {
      setUploading(false);
      toast.error(error.message || "Failed to upload ID document");
    },
  });

  const resubmitMutation = useAshMutation({
    resource: "UserVerification",
    action: "resubmit_id_document",
    onSuccess: () => {
      setUploading(false);
      toast.success("ID document resubmitted for review");
      onUploadSuccess?.();
    },
    onError: (error) => {
      setUploading(false);
      toast.error(error.message || "Failed to resubmit ID document");
    },
  });

  const handleFile = async (file: File) => {
    // Validate file
    const validTypes = ["image/jpeg", "image/png", "application/pdf"];
    if (!validTypes.includes(file.type)) {
      toast.error("Please upload JPG, PNG, or PDF only");
      return;
    }

    const maxSize = 5 * 1024 * 1024; // 5MB
    if (file.size > maxSize) {
      toast.error("File must be under 5MB. Try compressing it.");
      return;
    }

    setUploading(true);

    // Convert to base64 for upload
    const reader = new FileReader();
    reader.onload = async (e) => {
      const base64 = e.target?.result as string;

      const mutation =
        idVerificationStatus === "rejected" ? resubmitMutation : uploadMutation;

      mutation.mutate({
        file_data: base64,
        filename: file.name,
      });
    };
    reader.readAsDataURL(file);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragActive(false);

    const file = e.dataTransfer.files[0];
    if (file) handleFile(file);
  };

  const handleFileInput = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleFile(file);
  };

  // Status badges
  const getStatusBadge = () => {
    if (idVerified) {
      return (
        <Badge variant="default" className="bg-green-600">
          <CheckCircle2 className="size-3 mr-1" />
          Approved
        </Badge>
      );
    }

    if (idVerificationStatus === "pending") {
      return (
        <Badge variant="secondary">
          <Clock className="size-3 mr-1" />
          Pending Review
        </Badge>
      );
    }

    if (idVerificationStatus === "rejected") {
      return (
        <Badge variant="destructive">
          <XCircle className="size-3 mr-1" />
          Rejected
        </Badge>
      );
    }

    return null;
  };

  // If document uploaded
  if (idDocumentUrl) {
    return (
      <div className="space-y-2">
        <div className="flex items-center justify-between p-4 border rounded-md">
          <div className="flex-1">
            <p className="font-medium">{idDocumentUrl.split("/").pop()}</p>
            <div className="flex items-center gap-2 mt-1">
              {getStatusBadge()}
              {idVerifiedAt && (
                <span className="text-sm text-muted-foreground">
                  {new Date(idVerifiedAt).toLocaleDateString("en-NG")}
                </span>
              )}
            </div>
            {idVerificationStatus === "rejected" && idRejectionReason && (
              <p className="text-sm text-destructive mt-2">
                Reason: {idRejectionReason}
              </p>
            )}
          </div>

          {idVerificationStatus === "rejected" && (
            <Button
              variant="outline"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading}
            >
              {uploading ? "Uploading..." : "Resubmit"}
            </Button>
          )}
        </div>

        <input
          ref={fileInputRef}
          type="file"
          accept="image/jpeg,image/png,application/pdf"
          className="hidden"
          onChange={handleFileInput}
        />
      </div>
    );
  }

  // Upload UI
  return (
    <div>
      <Label>Government ID</Label>
      <div
        className={`
          mt-2 border-2 border-dashed rounded-lg p-8 text-center cursor-pointer
          transition-colors
          ${dragActive ? "border-primary bg-primary/5" : "border-border"}
          ${uploading ? "opacity-50 pointer-events-none" : ""}
        `}
        onDragEnter={() => setDragActive(true)}
        onDragLeave={() => setDragActive(false)}
        onDragOver={(e) => e.preventDefault()}
        onDrop={handleDrop}
        onClick={() => fileInputRef.current?.click()}
      >
        <Upload className="size-12 mx-auto mb-4 text-muted-foreground" />
        <p className="font-medium mb-1">
          {uploading ? "Uploading..." : "Drag & drop or click to upload"}
        </p>
        <p className="text-sm text-muted-foreground">
          Accepted: JPG, PNG, PDF (max 5MB)
        </p>
      </div>

      <input
        ref={fileInputRef}
        type="file"
        accept="image/jpeg,image/png,application/pdf"
        className="hidden"
        onChange={handleFileInput}
      />
    </div>
  );
}
```

**Step 2: Update barrel export**

```ts
// assets/js/features/verification/index.ts
export { PhoneVerification } from "./phone-verification";
export { IdUpload } from "./id-upload";
```

**Step 3: Commit**

```bash
git add assets/js/features/verification/
git commit -m "feat: add ID document upload component with drag-drop

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 8: Integrate Verification into Account Settings

**Files:**
- Modify: `assets/js/pages/settings/account.tsx`
- Modify: `lib/angle_web/controllers/settings_controller.ex`

**Step 1: Update controller to load verification data**

```elixir
# lib/angle_web/controllers/settings_controller.ex
# Modify account/2 function

def account(conn, _params) do
  user = conn.assigns.current_user

  # Load verification status
  verification =
    Angle.Accounts.UserVerification
    |> Ash.Query.filter(user_id == ^user.id)
    |> Ash.read_one()

  conn
  |> assign_prop(:user, user)
  |> assign_prop(:verification, verification)
  |> assign_prop(:avatar_images, load_avatar_images(user))
  |> render_inertia("settings/account")
end
```

**Step 2: Update account page to include verification**

```tsx
// assets/js/pages/settings/account.tsx
import { Head } from "@inertiajs/react";
import { SettingsLayout, AccountForm } from "@/features/settings";
import { PhoneVerification, IdUpload } from "@/features/verification";
import type { SettingsUser } from "@/features/settings";
import type { ImageData } from "@/lib/image-url";

interface UserVerification {
  phone_number?: string;
  phone_verified: boolean;
  phone_verified_at?: string;
  id_document_url?: string;
  id_verification_status?: "pending" | "approved" | "rejected";
  id_verified: boolean;
  id_verified_at?: string;
  id_rejection_reason?: string;
}

interface SettingsAccountProps {
  user: SettingsUser;
  avatar_images: ImageData[];
  verification?: UserVerification;
}

export default function SettingsAccount({
  user,
  avatar_images,
  verification,
}: SettingsAccountProps) {
  return (
    <>
      <Head title="Account Settings" />
      <SettingsLayout title="Account">
        <div className="space-y-8">
          <AccountForm user={user} avatarImages={avatar_images} />

          {/* Verification Section */}
          <div className="border-t pt-8">
            <h3 className="text-lg font-semibold mb-4">Verification</h3>
            <div className="space-y-6">
              <div>
                <PhoneVerification
                  initialPhoneNumber={verification?.phone_number}
                  phoneVerified={verification?.phone_verified || false}
                  phoneVerifiedAt={verification?.phone_verified_at}
                  onVerified={() => window.location.reload()}
                />
              </div>

              <div>
                <IdUpload
                  idDocumentUrl={verification?.id_document_url}
                  idVerificationStatus={verification?.id_verification_status}
                  idVerified={verification?.id_verified || false}
                  idVerifiedAt={verification?.id_verified_at}
                  idRejectionReason={verification?.id_rejection_reason}
                  onUploadSuccess={() => window.location.reload()}
                />
              </div>
            </div>
          </div>
        </div>
      </SettingsLayout>
    </>
  );
}
```

**Step 3: Test in browser**

```bash
# Navigate to http://localhost:4113/settings/account
# Verify:
# - Phone verification section appears
# - Can send OTP
# - Can verify OTP
# - ID upload section appears
# - Can drag-drop or click to upload
```

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/settings_controller.ex assets/js/pages/settings/account.tsx
git commit -m "feat: integrate phone and ID verification into account settings

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 9: Bid Requirement Validation Modal

**Files:**
- Create: `assets/js/features/bidding/requirement-modal.tsx`
- Create: `assets/js/features/bidding/index.ts`

**Step 1: Create requirement modal component**

```tsx
// assets/js/features/bidding/requirement-modal.tsx
import { router } from "@inertiajs/react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";
import { CheckCircle2, XCircle, AlertTriangle } from "lucide-react";
import { DepositDialog } from "@/features/wallet";
import { useState } from "react";

interface BidRequirement {
  met: boolean;
  description: string;
  action?: () => void;
  actionLabel?: string;
}

interface RequirementModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  itemValue: number;
  requirements: {
    walletBalance?: {
      current: number;
      required: number;
      met: boolean;
    };
    phoneVerified: boolean;
    idVerified: boolean;
    idRequired: boolean;
  };
}

export function RequirementModal({
  open,
  onOpenChange,
  itemValue,
  requirements,
}: RequirementModalProps) {
  const [depositOpen, setDepositOpen] = useState(false);

  const needsDeposit =
    requirements.walletBalance &&
    !requirements.walletBalance.met;

  const depositAmount = needsDeposit
    ? requirements.walletBalance.required - requirements.walletBalance.current
    : 0;

  const allRequirementsMet =
    requirements.walletBalance?.met &&
    requirements.phoneVerified &&
    (!requirements.idRequired || requirements.idVerified);

  return (
    <>
      <Dialog open={open} onOpenChange={onOpenChange}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Requirements to Bid on This Item</DialogTitle>
            <DialogDescription>
              This ₦{itemValue.toLocaleString()} item requires:
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            {/* Wallet Balance */}
            {requirements.walletBalance && (
              <div className="flex items-start gap-3">
                {requirements.walletBalance.met ? (
                  <CheckCircle2 className="size-5 text-green-600 shrink-0 mt-0.5" />
                ) : (
                  <XCircle className="size-5 text-destructive shrink-0 mt-0.5" />
                )}
                <div className="flex-1">
                  <p className="font-medium">
                    Wallet Balance: ₦{requirements.walletBalance.required.toLocaleString()} minimum
                  </p>
                  {!requirements.walletBalance.met && (
                    <>
                      <p className="text-sm text-muted-foreground">
                        Current: ₦{requirements.walletBalance.current.toLocaleString()}
                        (Need ₦{depositAmount.toLocaleString()} more)
                      </p>
                      <Button
                        size="sm"
                        className="mt-2"
                        onClick={() => {
                          setDepositOpen(true);
                          onOpenChange(false);
                        }}
                      >
                        Deposit ₦{depositAmount.toLocaleString()} Now
                      </Button>
                    </>
                  )}
                </div>
              </div>
            )}

            {/* Phone Verification */}
            <div className="flex items-start gap-3">
              {requirements.phoneVerified ? (
                <CheckCircle2 className="size-5 text-green-600 shrink-0 mt-0.5" />
              ) : (
                <XCircle className="size-5 text-destructive shrink-0 mt-0.5" />
              )}
              <div className="flex-1">
                <p className="font-medium">Phone Verification</p>
                {!requirements.phoneVerified && (
                  <Button
                    size="sm"
                    variant="outline"
                    className="mt-2"
                    onClick={() => {
                      router.visit("/settings/account");
                    }}
                  >
                    Verify Phone Number
                  </Button>
                )}
              </div>
            </div>

            {/* ID Verification (only for high-value items) */}
            {requirements.idRequired && (
              <div className="flex items-start gap-3">
                {requirements.idVerified ? (
                  <CheckCircle2 className="size-5 text-green-600 shrink-0 mt-0.5" />
                ) : (
                  <XCircle className="size-5 text-destructive shrink-0 mt-0.5" />
                )}
                <div className="flex-1">
                  <p className="font-medium">ID Verification</p>
                  {!requirements.idVerified && (
                    <>
                      <p className="text-sm text-muted-foreground">
                        Required for items ≥₦50,000
                      </p>
                      <Button
                        size="sm"
                        variant="outline"
                        className="mt-2"
                        onClick={() => {
                          router.visit("/settings/account");
                        }}
                      >
                        Upload Government ID
                      </Button>
                    </>
                  )}
                </div>
              </div>
            )}

            {allRequirementsMet && (
              <Alert>
                <CheckCircle2 className="size-4" />
                <AlertDescription>
                  All requirements met! You can place your bid.
                </AlertDescription>
              </Alert>
            )}
          </div>
        </DialogContent>
      </Dialog>

      <DepositDialog
        open={depositOpen}
        onOpenChange={setDepositOpen}
        suggestedAmount={depositAmount}
      />
    </>
  );
}
```

**Step 2: Create barrel export**

```ts
// assets/js/features/bidding/index.ts
export { RequirementModal } from "./requirement-modal";
```

**Step 3: Commit**

```bash
git add assets/js/features/bidding/
git commit -m "feat: add bid requirement validation modal

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 10: Integrate Validation into Bid Dialog

**Files:**
- Modify: `assets/js/features/item/bid-dialog.tsx` (or wherever bid dialog exists)

**Step 1: Add requirement validation to existing bid dialog**

```tsx
// Find the existing bid dialog component and add validation

import { RequirementModal } from "@/features/bidding";

// Add state
const [requirementModalOpen, setRequirementModalOpen] = useState(false);
const [requirements, setRequirements] = useState<any>(null);

// Modify the bid mutation to handle validation errors
const bidMutation = useAshMutation({
  resource: "Bid",
  action: "make_bid",
  onSuccess: () => {
    toast.success("Bid placed successfully!");
    onOpenChange(false);
    router.reload();
  },
  onError: (error: any) => {
    // Check if error contains requirement information
    if (error.requirements) {
      setRequirements(error.requirements);
      setRequirementModalOpen(true);
    } else {
      toast.error(error.message || "Failed to place bid");
    }
  },
});

// Add the RequirementModal to the component JSX
<RequirementModal
  open={requirementModalOpen}
  onOpenChange={setRequirementModalOpen}
  itemValue={item.current_price}
  requirements={requirements}
/>
```

**Step 2: Test bid validation flow**

```bash
# Navigate to an item page
# Try to bid without meeting requirements
# Verify requirement modal appears
# Verify action buttons work
```

**Step 3: Commit**

```bash
git add assets/js/features/item/
git commit -m "feat: integrate requirement validation into bid dialog

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 11: Store Item Analytics Page

**Files:**
- Create: `assets/js/pages/store/listings/[id]/analytics.tsx`
- Create: `lib/angle_web/controllers/store_analytics_controller.ex`
- Modify: `lib/angle_web/router.ex`

**Step 1: Create analytics controller**

```elixir
# lib/angle_web/controllers/store_analytics_controller.ex
defmodule AngleWeb.StoreAnalyticsController do
  use AngleWeb, :controller

  def show(conn, %{"id" => item_id}) do
    user = conn.assigns.current_user

    # Load item with stats
    item =
      Angle.Inventory.Item
      |> Ash.Query.filter(id == ^item_id and created_by_id == ^user.id)
      |> Ash.Query.load([:category, :cover_image])
      |> Ash.read_one!()

    # Load bid history with bidder details
    bids =
      Angle.Bidding.Bid
      |> Ash.Query.filter(item_id == ^item_id)
      |> Ash.Query.load([:user])
      |> Ash.Query.sort(bid_time: :desc)
      |> Ash.read!()

    # Load blacklist for this seller
    blacklist =
      Angle.Bidding.SellerBlacklist
      |> Ash.Query.filter(seller_id == ^user.id)
      |> Ash.read!()

    conn
    |> assign_prop(:item, item)
    |> assign_prop(:bids, bids)
    |> assign_prop(:blacklist, blacklist)
    |> render_inertia("store/listings/[id]/analytics")
  end
end
```

**Step 2: Add route**

```elixir
# lib/angle_web/router.ex
# Add to the store scope

scope "/store", AngleWeb do
  pipe_through [:browser, :require_authenticated_user]

  get "/listings/:id/analytics", StoreAnalyticsController, :show
end
```

**Step 3: Create analytics page**

```tsx
// assets/js/pages/store/listings/[id]/analytics.tsx
import { Head, Link } from "@inertiajs/react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { ArrowLeft, MoreVertical } from "lucide-react";
import { useState } from "react";
import { BlockBidderDialog } from "@/features/blacklist";

interface Item {
  id: string;
  title: string;
  current_price: number;
  auction_status: string;
  end_time: string;
  view_count: number;
  // ... other fields
}

interface Bid {
  id: string;
  amount: number;
  bid_time: string;
  user: {
    id: string;
    username: string;
  };
}

interface Blacklist {
  id: string;
  blocked_user_id: string;
}

interface StoreAnalyticsProps {
  item: Item;
  bids: Bid[];
  blacklist: Blacklist[];
}

export default function StoreAnalytics({
  item,
  bids,
  blacklist,
}: StoreAnalyticsProps) {
  const [blockDialogOpen, setBlockDialogOpen] = useState(false);
  const [selectedBidder, setSelectedBidder] = useState<Bid["user"] | null>(
    null
  );

  const blockedUserIds = blacklist.map((b) => b.blocked_user_id);

  return (
    <>
      <Head title={`Analytics - ${item.title}`} />

      <div className="container max-w-5xl py-8">
        <div className="mb-6">
          <Link href="/store/listings">
            <Button variant="ghost" size="sm">
              <ArrowLeft className="size-4 mr-2" />
              Back to Listings
            </Button>
          </Link>
        </div>

        <div className="space-y-6">
          <div>
            <h1 className="text-3xl font-bold">{item.title}</h1>
            <p className="text-muted-foreground">
              Status: {item.auction_status} • Ends{" "}
              {new Date(item.end_time).toLocaleString("en-NG")}
            </p>
          </div>

          {/* Stats Grid */}
          <div className="grid grid-cols-4 gap-4">
            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Views</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">{item.view_count}</p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Watch</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">12</p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Bids</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">{bids.length}</p>
              </CardContent>
            </Card>

            <Card>
              <CardHeader className="pb-2">
                <CardTitle className="text-sm font-medium">Price</CardTitle>
              </CardHeader>
              <CardContent>
                <p className="text-2xl font-bold">
                  ₦{item.current_price.toLocaleString()}
                </p>
              </CardContent>
            </Card>
          </div>

          {/* Bid History */}
          <Card>
            <CardHeader>
              <CardTitle>Bid History</CardTitle>
            </CardHeader>
            <CardContent>
              {bids.length === 0 ? (
                <p className="text-center py-8 text-muted-foreground">
                  No bids yet
                </p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>User</TableHead>
                      <TableHead>Amount</TableHead>
                      <TableHead>Time</TableHead>
                      <TableHead className="w-[50px]"></TableHead>
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {bids.map((bid) => {
                      const isBlocked = blockedUserIds.includes(bid.user.id);

                      return (
                        <TableRow key={bid.id}>
                          <TableCell>
                            @{bid.user.username}
                            {isBlocked && (
                              <span className="ml-2 text-xs text-destructive">
                                (Blocked)
                              </span>
                            )}
                          </TableCell>
                          <TableCell>
                            ₦{bid.amount.toLocaleString()}
                          </TableCell>
                          <TableCell>
                            {new Date(bid.bid_time).toLocaleString("en-NG", {
                              month: "short",
                              day: "numeric",
                              hour: "2-digit",
                              minute: "2-digit",
                            })}
                          </TableCell>
                          <TableCell>
                            <DropdownMenu>
                              <DropdownMenuTrigger asChild>
                                <Button variant="ghost" size="sm">
                                  <MoreVertical className="size-4" />
                                </Button>
                              </DropdownMenuTrigger>
                              <DropdownMenuContent align="end">
                                <DropdownMenuItem>
                                  View Profile
                                </DropdownMenuItem>
                                {!isBlocked && (
                                  <DropdownMenuItem
                                    onClick={() => {
                                      setSelectedBidder(bid.user);
                                      setBlockDialogOpen(true);
                                    }}
                                  >
                                    Block from my items
                                  </DropdownMenuItem>
                                )}
                              </DropdownMenuContent>
                            </DropdownMenu>
                          </TableCell>
                        </TableRow>
                      );
                    })}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {selectedBidder && (
        <BlockBidderDialog
          open={blockDialogOpen}
          onOpenChange={setBlockDialogOpen}
          bidder={selectedBidder}
          onSuccess={() => window.location.reload()}
        />
      )}
    </>
  );
}
```

**Step 4: Commit**

```bash
git add lib/angle_web/controllers/store_analytics_controller.ex lib/angle_web/router.ex assets/js/pages/store/
git commit -m "feat: add store item analytics page with bid history

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 12: Block Bidder Dialog Component

**Files:**
- Create: `assets/js/features/blacklist/block-bidder-dialog.tsx`
- Create: `assets/js/features/blacklist/index.ts`

**Step 1: Create block bidder dialog**

```tsx
// assets/js/features/blacklist/block-bidder-dialog.tsx
import { useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Textarea } from "@/components/ui/textarea";
import { useAshMutation } from "@/hooks/use-ash-query";
import { toast } from "sonner";

interface BlockBidderDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  bidder: {
    id: string;
    username: string;
  };
  onSuccess?: () => void;
}

const BLOCK_REASONS = [
  { value: "non_payment", label: "Non-payment" },
  { value: "rude", label: "Rude behavior" },
  { value: "suspicious", label: "Suspicious activity" },
  { value: "other", label: "Other" },
];

export function BlockBidderDialog({
  open,
  onOpenChange,
  bidder,
  onSuccess,
}: BlockBidderDialogProps) {
  const [reason, setReason] = useState("");
  const [customReason, setCustomReason] = useState("");

  const blockMutation = useAshMutation({
    resource: "SellerBlacklist",
    action: "create",
    onSuccess: () => {
      toast.success(`@${bidder.username} blocked from your items`);
      onOpenChange(false);
      setReason("");
      setCustomReason("");
      onSuccess?.();
    },
    onError: (error) => {
      toast.error(error.message || "Failed to block bidder");
    },
  });

  const handleBlock = () => {
    const finalReason =
      reason === "other" ? customReason : BLOCK_REASONS.find((r) => r.value === reason)?.label;

    blockMutation.mutate({
      blocked_user_id: bidder.id,
      reason: finalReason || "No reason provided",
    });
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Block @{bidder.username} from your items?</DialogTitle>
          <DialogDescription>
            @{bidder.username} won't be able to bid on any of your future items.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4">
          <div>
            <Label htmlFor="reason">Reason (optional)</Label>
            <Select value={reason} onValueChange={setReason}>
              <SelectTrigger id="reason">
                <SelectValue placeholder="Select a reason" />
              </SelectTrigger>
              <SelectContent>
                {BLOCK_REASONS.map((r) => (
                  <SelectItem key={r.value} value={r.value}>
                    {r.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </div>

          {reason === "other" && (
            <div>
              <Label htmlFor="custom-reason">Specify reason</Label>
              <Textarea
                id="custom-reason"
                placeholder="Enter reason..."
                value={customReason}
                onChange={(e) => setCustomReason(e.target.value)}
                rows={3}
              />
            </div>
          )}

          <div className="flex gap-2">
            <Button
              variant="outline"
              className="flex-1"
              onClick={() => onOpenChange(false)}
            >
              Cancel
            </Button>
            <Button
              variant="destructive"
              className="flex-1"
              onClick={handleBlock}
              disabled={blockMutation.isPending}
            >
              {blockMutation.isPending ? "Blocking..." : "Block Bidder"}
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
```

**Step 2: Create barrel export**

```ts
// assets/js/features/blacklist/index.ts
export { BlockBidderDialog } from "./block-bidder-dialog";
```

**Step 3: Commit**

```bash
git add assets/js/features/blacklist/
git commit -m "feat: add block bidder dialog with reason selection

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 13: Testing & Integration

**Files:**
- All modified files

**Step 1: Run TypeScript type check**

```bash
cd assets && npx tsc --noEmit
```

Expected: No type errors

**Step 2: Run full test suite**

```bash
mix test
```

Expected: All tests pass (including existing Phase 2 backend tests)

**Step 3: Manual testing checklist**

Test each feature in the browser:

**Wallet:**
- [ ] Navigate to Settings > Payments
- [ ] Balance card displays
- [ ] Click Deposit → dialog opens
- [ ] Select preset amount → deposit button works
- [ ] Custom amount validation works
- [ ] Click Withdraw → dialog opens
- [ ] Fill bank details → withdraw button works
- [ ] Transaction history displays

**Verification:**
- [ ] Navigate to Settings > Account
- [ ] Phone verification section visible
- [ ] Enter phone → Send OTP works
- [ ] OTP input expands inline
- [ ] Enter OTP → Verify works
- [ ] Verified status shows
- [ ] ID upload section visible
- [ ] Drag-drop file works
- [ ] Click to upload works
- [ ] File validation works (size, type)
- [ ] Upload success shows pending status

**Blacklist:**
- [ ] Navigate to Store > Listings
- [ ] Click item row → analytics page opens
- [ ] Bid history table displays
- [ ] Click bidder menu (⋮) → Block option shows
- [ ] Click Block → dialog opens
- [ ] Select reason → Block works
- [ ] Blocked bidder marked in list

**Bid Validation:**
- [ ] Navigate to item page
- [ ] Click Place Bid (without requirements)
- [ ] Requirement modal appears
- [ ] Shows missing requirements
- [ ] Deposit button opens deposit dialog
- [ ] Verify phone button navigates to settings
- [ ] Upload ID button navigates to settings

**Step 4: Fix any issues found**

Document and fix any bugs discovered during manual testing.

**Step 5: Commit**

```bash
git add -A
git commit -m "test: verify Phase 2 frontend integration

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 14: Final Cleanup & Documentation

**Files:**
- Create: `docs/phase2-frontend-testing.md`

**Step 1: Document testing results**

```markdown
# Phase 2 Frontend Testing Results

## Features Tested

### Wallet UI
- ✅ Balance card displays correctly
- ✅ Deposit dialog with preset/custom amounts
- ✅ Paystack integration (redirects to payment)
- ✅ Withdraw dialog with bank details
- ✅ Transaction history table

### Verification UI
- ✅ Phone OTP inline expansion
- ✅ OTP send/verify flow
- ✅ Rate limiting (60s countdown)
- ✅ ID upload drag-drop (desktop)
- ✅ ID upload file picker (mobile)
- ✅ Verification status badges

### Blacklist UI
- ✅ Item analytics page
- ✅ Bid history table
- ✅ Block bidder dialog
- ✅ Block reason selection
- ✅ Blocked status indication

### Bid Validation
- ✅ Requirement modal
- ✅ Shows missing requirements
- ✅ Action buttons (deposit/verify)
- ✅ Redirects to settings

## Known Issues
(List any issues found during testing)

## Next Steps
- Deploy to staging
- Test with real Paystack account
- Monitor for errors
```

**Step 2: Update main README if needed**

**Step 3: Final commit**

```bash
git add docs/phase2-frontend-testing.md
git commit -m "docs: add Phase 2 frontend testing results

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Execution Options

Plan complete and saved to `docs/plans/2026-02-20-phase2-frontend-implementation.md`.

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans, batch execution with checkpoints

**Which approach?**
