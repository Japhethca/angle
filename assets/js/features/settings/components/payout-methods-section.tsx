import { useState, useEffect } from "react";
import { router } from "@inertiajs/react";
import { Building2 } from "lucide-react";
import { toast } from "sonner";
import { Separator } from "@/components/ui/separator";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { getPhoenixCSRFToken } from "@/ash_rpc";

interface PayoutMethod {
  id: string;
  bank_name: string;
  account_number: string;
  account_name: string;
  is_default: boolean;
  inserted_at: string;
}

interface PayoutMethodsSectionProps {
  methods: PayoutMethod[];
}

interface Bank {
  name: string;
  code: string;
}

export function PayoutMethodsSection({ methods }: PayoutMethodsSectionProps) {
  const [dialogOpen, setDialogOpen] = useState(false);
  const [banks, setBanks] = useState<Bank[]>([]);
  const [banksLoading, setBanksLoading] = useState(false);
  const [selectedBankCode, setSelectedBankCode] = useState("");
  const [accountNumber, setAccountNumber] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    if (!dialogOpen) return;

    const fetchBanks = async () => {
      setBanksLoading(true);
      try {
        const csrfToken = getPhoenixCSRFToken();
        const res = await fetch("/api/payments/banks", {
          headers: {
            ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
          },
        });
        if (res.ok) {
          const data = await res.json();
          setBanks(data.banks || []);
        }
      } catch {
        toast.error("Failed to load banks");
      } finally {
        setBanksLoading(false);
      }
    };

    fetchBanks();
  }, [dialogOpen]);

  const handleRemove = async (id: string) => {
    const csrfToken = getPhoenixCSRFToken();

    try {
      const res = await fetch(`/api/payments/payout-methods/${id}`, {
        method: "DELETE",
        headers: {
          ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
        },
      });

      if (!res.ok) {
        toast.error("Failed to remove payout method");
        return;
      }

      toast.success("Payout method removed");
      router.reload();
    } catch {
      toast.error("Failed to remove payout method");
    }
  };

  const handleAddPayout = async () => {
    if (!selectedBankCode || accountNumber.length !== 10) {
      toast.error("Please select a bank and enter a 10-digit account number");
      return;
    }

    const csrfToken = getPhoenixCSRFToken();
    setIsSubmitting(true);

    try {
      const res = await fetch("/api/payments/add-payout", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
        },
        body: JSON.stringify({
          bank_code: selectedBankCode,
          bank_name: banks.find((b) => b.code === selectedBankCode)?.name || "Unknown Bank",
          account_number: accountNumber,
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        toast.error(data?.error || "Failed to add payout method");
        return;
      }

      toast.success("Payout method added successfully");
      setDialogOpen(false);
      setSelectedBankCode("");
      setAccountNumber("");
      router.reload();
    } catch {
      toast.error("Failed to add payout method");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div>
      <Separator className="mb-5" />
      <h2 className="mb-4 text-base font-semibold text-content">Payouts</h2>

      {methods.length === 0 && (
        <p className="mb-3 text-sm text-content-tertiary">No payout methods added yet.</p>
      )}

      <div className="space-y-3">
        {methods.map((method) => (
          <div
            key={method.id}
            className="flex items-center justify-between rounded-xl border border-subtle p-4"
          >
            <div className="flex items-center gap-3">
              <div className="flex size-10 items-center justify-center rounded-full bg-surface-muted">
                <Building2 className="size-5 text-content-tertiary" />
              </div>
              <div>
                <p className="text-sm font-medium text-content">{method.bank_name}</p>
                <p className="text-xs text-content-tertiary">
                  {method.account_number}
                  {method.is_default && (
                    <span className="text-feedback-success"> · default</span>
                  )}
                </p>
              </div>
            </div>
            <button
              onClick={() => handleRemove(method.id)}
              className="text-sm font-medium text-primary-600"
            >
              Remove
            </button>
          </div>
        ))}
      </div>

      <button
        onClick={() => setDialogOpen(true)}
        className="mt-3 flex items-center gap-1 text-sm font-medium text-primary-600"
      >
        <span>+</span> New Payout Method
      </button>

      <Dialog open={dialogOpen} onOpenChange={setDialogOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>Add Payout Method</DialogTitle>
            <DialogDescription>
              Add a bank account to receive payouts from your sales.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="bank">Bank</Label>
              <Select value={selectedBankCode} onValueChange={setSelectedBankCode}>
                <SelectTrigger id="bank">
                  <SelectValue
                    placeholder={banksLoading ? "Loading banks..." : "Select a bank"}
                  />
                </SelectTrigger>
                <SelectContent>
                  {banks.map((bank) => (
                    <SelectItem key={bank.code} value={bank.code}>
                      {bank.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-2">
              <Label htmlFor="account_number">Account Number</Label>
              <Input
                id="account_number"
                type="text"
                inputMode="numeric"
                maxLength={10}
                placeholder="Enter 10-digit account number"
                value={accountNumber}
                onChange={(e) => {
                  const value = e.target.value.replace(/\D/g, "");
                  setAccountNumber(value);
                }}
              />
            </div>

            <Button
              onClick={handleAddPayout}
              disabled={isSubmitting || !selectedBankCode || accountNumber.length !== 10}
              className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
            >
              {isSubmitting ? "Adding..." : "Add Payout Method"}
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </div>
  );
}
