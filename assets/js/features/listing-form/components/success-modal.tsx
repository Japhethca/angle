import { router } from "@inertiajs/react";
import { CheckCircle } from "lucide-react";
import {
  Dialog,
  DialogContent,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";

interface SuccessModalProps {
  open: boolean;
  itemId: string | null;
}

export function SuccessModal({ open, itemId }: SuccessModalProps) {
  const handleViewListing = () => {
    if (itemId) {
      router.visit(`/items/${itemId}`);
    }
  };

  const handleListAnother = () => {
    router.visit("/items/new");
  };

  return (
    <Dialog open={open}>
      <DialogContent
        className="text-center sm:max-w-sm"
        showCloseButton={false}
      >
        <div className="flex flex-col items-center gap-4 py-4">
          <div className="flex size-16 items-center justify-center rounded-full bg-feedback-success/10">
            <CheckCircle className="size-10 text-feedback-success" />
          </div>
          <div className="space-y-2">
            <h2 className="text-xl font-bold text-content">Your Item is Live!</h2>
            <p className="text-sm text-content-secondary">
              Buyers can now bid on your listing. You'll get notified when someone places a bid.
            </p>
          </div>
          <div className="flex w-full flex-col gap-2 pt-2">
            <Button
              onClick={handleViewListing}
              className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
            >
              View Listing
            </Button>
            <Button
              variant="outline"
              onClick={handleListAnother}
              className="w-full rounded-full"
            >
              List Another Item
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
