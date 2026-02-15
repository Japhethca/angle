import { useEffect, useState } from "react";
import { router } from "@inertiajs/react";
import { CreditCard, MoreVertical, Trash2 } from "lucide-react";
import { toast } from "sonner";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import { Button } from "@/components/ui/button";
import { getPhoenixCSRFToken } from "@/ash_rpc";

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

interface PaymentMethodsSectionProps {
  methods: PaymentMethod[];
  userEmail: string;
}

function getCardLabel(cardType: string): string {
  const labels: Record<string, string> = {
    visa: "Visa",
    mastercard: "Mastercard",
    verve: "Verve",
    "american express": "Amex",
  };
  return labels[cardType.toLowerCase()] || cardType;
}

export function PaymentMethodsSection({ methods, userEmail: _userEmail }: PaymentMethodsSectionProps) {
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    const script = document.createElement("script");
    script.src = "https://js.paystack.co/v2/inline.js";
    script.async = true;
    document.body.appendChild(script);
    return () => {
      document.body.removeChild(script);
    };
  }, []);

  const handleAddCard = async () => {
    const csrfToken = getPhoenixCSRFToken();
    setIsLoading(true);

    try {
      const res = await fetch("/api/payments/initialize-card", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
        },
      });

      if (!res.ok) {
        toast.error("Failed to initialize card setup");
        return;
      }

      const data = await res.json();

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const paystack = new (window as any).PaystackPop();
      paystack.resumeTransaction(data.access_code, {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        onSuccess: async (transaction: any) => {
          try {
            const verifyRes = await fetch("/api/payments/verify-card", {
              method: "POST",
              headers: {
                "content-type": "application/json",
                ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
              },
              body: JSON.stringify({ reference: transaction.reference }),
            });

            if (!verifyRes.ok) {
              const data = await verifyRes.json().catch(() => null);
              toast.error(data?.error || "Failed to verify card");
              return;
            }

            toast.success("Card added successfully");
            router.reload();
          } catch {
            toast.error("Failed to verify card");
          }
        },
        onCancel: () => {
          toast.info("Card addition cancelled");
        },
      });
    } catch {
      toast.error("Failed to initialize card setup");
    } finally {
      setIsLoading(false);
    }
  };

  const handleRemove = async (id: string) => {
    const csrfToken = getPhoenixCSRFToken();

    try {
      const res = await fetch(`/api/payments/payment-methods/${id}`, {
        method: "DELETE",
        headers: {
          ...(csrfToken ? { "x-csrf-token": csrfToken } : {}),
        },
      });

      if (!res.ok) {
        toast.error("Failed to remove payment method");
        return;
      }

      toast.success("Payment method removed");
      router.reload();
    } catch {
      toast.error("Failed to remove payment method");
    }
  };

  return (
    <div>
      <h2 className="mb-4 text-base font-semibold text-content">Payment Methods</h2>

      {methods.length === 0 && (
        <p className="mb-3 text-sm text-content-tertiary">No payment methods added yet.</p>
      )}

      <div className="space-y-3">
        {methods.map((method) => (
          <div
            key={method.id}
            className="flex items-center justify-between rounded-xl border border-subtle p-4"
          >
            <div className="flex items-center gap-3">
              <div className="flex size-10 items-center justify-center rounded-full bg-surface-muted">
                <CreditCard className="size-5 text-content-tertiary" />
              </div>
              <div>
                <p className="text-sm font-medium text-content">
                  {getCardLabel(method.card_type)} ••••{method.last_four}
                </p>
                <p className="text-xs text-content-tertiary">
                  {method.exp_month}/{method.exp_year}
                </p>
              </div>
            </div>

            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon" className="size-8">
                  <MoreVertical className="size-4 text-content-tertiary" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem
                  variant="destructive"
                  onClick={() => handleRemove(method.id)}
                >
                  <Trash2 className="size-4" />
                  Remove
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        ))}
      </div>

      <button
        onClick={handleAddCard}
        disabled={isLoading}
        className="mt-3 flex items-center gap-1 text-sm font-medium text-primary-600 disabled:opacity-50"
      >
        <span>+</span> New Payment Method
      </button>
    </div>
  );
}
