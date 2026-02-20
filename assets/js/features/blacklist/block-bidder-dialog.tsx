import { useState } from "react";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { createBlacklist, buildCSRFHeaders } from "@/ash_rpc";

interface BlockBidderDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  user: {
    id: string;
    username: string | null;
    fullName: string | null;
  };
}

const BLOCK_REASONS = [
  { value: "non_payment", label: "Non-payment or payment issues" },
  { value: "rude", label: "Rude or abusive behavior" },
  { value: "suspicious", label: "Suspicious activity" },
  { value: "other", label: "Other (please specify)" },
] as const;

export function BlockBidderDialog({ open, onOpenChange, user }: BlockBidderDialogProps) {
  const [reason, setReason] = useState<string>("non_payment");
  const [customReason, setCustomReason] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);

  const displayName = user.fullName || user.username || "this user";

  const handleSubmit = async () => {
    const finalReason = reason === "other" ? customReason : reason;

    if (!finalReason.trim()) {
      toast.error("Please provide a reason for blocking");
      return;
    }

    setIsSubmitting(true);

    try {
      const result = await createBlacklist({
        blockedUserId: user.id,
        reason: finalReason,
      }, {
        headers: buildCSRFHeaders(),
      });

      if (result.success) {
        toast.success(`${displayName} has been blocked from bidding on your items`);
        onOpenChange(false);
        // Reload the page to reflect the updated blacklist
        router.reload({ only: ["bids", "blacklisted_user_ids"] });
      } else {
        const errorMsg = result.errors?.[0]?.message || "Failed to block user";
        toast.error(errorMsg);
      }
    } catch (error) {
      console.error("Failed to block user:", error);
      toast.error("An error occurred while blocking the user");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>Block Bidder</DialogTitle>
          <DialogDescription>
            Block <span className="font-medium">{displayName}</span> from bidding on your
            items. They will not be able to place bids on any of your listings.
          </DialogDescription>
        </DialogHeader>

        <div className="space-y-4 py-4">
          <div className="space-y-3">
            <Label>Reason for blocking</Label>
            <RadioGroup value={reason} onValueChange={setReason}>
              {BLOCK_REASONS.map((option) => (
                <div key={option.value} className="flex items-center space-x-2">
                  <RadioGroupItem value={option.value} id={option.value} />
                  <Label htmlFor={option.value} className="font-normal cursor-pointer">
                    {option.label}
                  </Label>
                </div>
              ))}
            </RadioGroup>
          </div>

          {reason === "other" && (
            <div className="space-y-2">
              <Label htmlFor="custom-reason">Please specify</Label>
              <Textarea
                id="custom-reason"
                placeholder="Enter your reason..."
                value={customReason}
                onChange={(e) => setCustomReason(e.target.value)}
                rows={3}
              />
            </div>
          )}
        </div>

        <DialogFooter>
          <Button
            variant="outline"
            onClick={() => onOpenChange(false)}
            disabled={isSubmitting}
          >
            Cancel
          </Button>
          <Button
            variant="destructive"
            onClick={handleSubmit}
            disabled={isSubmitting || (reason === "other" && !customReason.trim())}
          >
            {isSubmitting ? "Blocking..." : "Block User"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
