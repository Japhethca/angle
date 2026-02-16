import { useState } from "react";
import { Minus, Plus, Info, Heart, Share2 } from "lucide-react";
import { useAuth } from "@/features/auth";
import { useAshMutation } from "@/hooks/use-ash-query";
import { makeBid, buildCSRFHeaders } from "@/ash_rpc";
import { formatNaira } from "@/lib/format";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { ConfirmBidDialog } from "./confirm-bid-dialog";

interface BidSectionProps {
  itemId: string;
  itemTitle: string;
  currentPrice: string | null;
  startingPrice: string;
  bidIncrement: string | null;
  bidCount: number;
  isWatchlisted?: boolean;
  onToggleWatch?: () => void;
  isWatchPending?: boolean;
}

const QUICK_ADD_AMOUNTS = [1000, 5000, 10000];

export function BidSection({
  itemId,
  itemTitle,
  currentPrice,
  startingPrice,
  bidIncrement,
  bidCount,
  isWatchlisted = false,
  onToggleWatch,
  isWatchPending = false,
}: BidSectionProps) {
  const { authenticated } = useAuth();
  const increment = bidIncrement ? parseFloat(bidIncrement) : 1000;
  const basePrice = currentPrice
    ? parseFloat(currentPrice)
    : parseFloat(startingPrice);
  const [bidAmount, setBidAmount] = useState(basePrice + increment);
  const [confirmOpen, setConfirmOpen] = useState(false);

  const { mutate: placeBid, isPending } = useAshMutation(
    (amount: number) =>
      makeBid({
        input: {
          amount: amount.toString(),
          bidType: "manual",
          itemId,
        },
        fields: ["id", "amount"],
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        setConfirmOpen(false);
        toast.success("Bid placed successfully!");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to place bid");
      },
    }
  );

  const handlePlaceBid = () => {
    if (!authenticated) {
      router.visit(
        `/auth/login?return_to=${encodeURIComponent(window.location.pathname)}`
      );
      return;
    }
    setConfirmOpen(true);
  };

  const handleConfirmBid = () => {
    placeBid(bidAmount);
  };

  const handleDecrement = () => {
    const newAmount = bidAmount - increment;
    if (newAmount > basePrice) {
      setBidAmount(newAmount);
    }
  };

  const handleIncrement = () => {
    setBidAmount(bidAmount + increment);
  };

  const handleQuickAdd = (amount: number) => {
    setBidAmount(bidAmount + amount);
  };

  return (
    <div className="space-y-4">
      {/* Bid count */}
      {bidCount > 0 && (
        <p className="text-xs text-content-tertiary">
          {bidCount} bid{bidCount !== 1 ? "s" : ""} so far
        </p>
      )}

      {/* Bid amount label */}
      <div className="flex items-center gap-1.5">
        <span className="text-sm font-medium text-content">Bid Amount</span>
        <Info className="size-3.5 text-content-tertiary" />
      </div>

      {/* Bid input with +/- buttons */}
      <div className="flex items-center gap-2">
        <button
          onClick={handleDecrement}
          disabled={bidAmount - increment <= basePrice}
          className="flex size-10 shrink-0 items-center justify-center rounded-full border border-strong transition-colors hover:bg-surface-inset disabled:opacity-40"
        >
          <Minus className="size-4 text-content-secondary" />
        </button>

        <div className="flex-1 rounded-xl bg-surface-muted px-4 py-3 text-center text-base font-semibold text-content">
          {formatNaira(bidAmount)}
        </div>

        <button
          onClick={handleIncrement}
          className="flex size-10 shrink-0 items-center justify-center rounded-full border border-strong transition-colors hover:bg-surface-inset"
        >
          <Plus className="size-4 text-content-secondary" />
        </button>
      </div>

      {/* Quick-add chips */}
      <div className="flex gap-2">
        {QUICK_ADD_AMOUNTS.map((amount) => (
          <button
            key={amount}
            onClick={() => handleQuickAdd(amount)}
            className="rounded-full border border-strong px-3 py-1.5 text-xs font-medium text-content-secondary transition-colors hover:bg-surface-inset"
          >
            +{formatNaira(amount)}
          </button>
        ))}
      </div>

      {/* Place Bid CTA */}
      <button
        onClick={handlePlaceBid}
        disabled={isPending}
        className="w-full rounded-full bg-primary-600 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-primary-600/90 disabled:opacity-60"
      >
        {isPending ? "Placing Bid..." : "Place Bid"}
      </button>

      {/* Desktop: Watch & Share buttons */}
      <div className="hidden gap-3 lg:flex">
        <button
          onClick={onToggleWatch}
          disabled={isWatchPending}
          className={`flex flex-1 items-center justify-center gap-2 rounded-full border py-2.5 text-sm font-medium transition-colors ${
            isWatchlisted
              ? "border-red-200 bg-red-50 text-red-600 hover:bg-red-100"
              : "border-strong text-content hover:bg-surface-inset"
          }`}
        >
          <Heart className={`size-4 ${isWatchlisted ? "fill-red-500 text-red-500" : ""}`} />
          {isWatchlisted ? "Watching" : "Watch"}
        </button>
        <button className="flex flex-1 items-center justify-center gap-2 rounded-full border border-strong py-2.5 text-sm font-medium text-content transition-colors hover:bg-surface-inset">
          <Share2 className="size-4" />
          Share
        </button>
      </div>

      <ConfirmBidDialog
        open={confirmOpen}
        onOpenChange={setConfirmOpen}
        onConfirm={handleConfirmBid}
        isPending={isPending}
        itemTitle={itemTitle}
        bidAmount={formatNaira(bidAmount)}
      />
    </div>
  );
}
