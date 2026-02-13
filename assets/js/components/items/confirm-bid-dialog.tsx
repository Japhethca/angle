import { Gavel, X } from "lucide-react";
import { useIsMobile } from "@/hooks/use-mobile";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Drawer,
  DrawerClose,
  DrawerContent,
  DrawerDescription,
  DrawerTitle,
} from "@/components/ui/drawer";

interface ConfirmBidDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onConfirm: () => void;
  isPending: boolean;
  itemTitle: string;
  bidAmount: string;
}

function ItemPreview({
  itemTitle,
  bidAmount,
  titleSize = "text-2xl",
  amountSize = "text-2xl",
  labelSize = "text-xs",
}: {
  itemTitle: string;
  bidAmount: string;
  titleSize?: string;
  amountSize?: string;
  labelSize?: string;
}) {
  return (
    <div className="space-y-2">
      <p className={`${titleSize} text-neutral-01`}>{itemTitle}</p>
      <p className={`${labelSize} tracking-wider text-neutral-04`}>Your Bid</p>
      <p className={`${amountSize} font-bold text-neutral-01`}>{bidAmount}</p>
    </div>
  );
}

function ConfirmButton({
  onClick,
  isPending,
}: {
  onClick: () => void;
  isPending: boolean;
}) {
  return (
    <button
      onClick={onClick}
      disabled={isPending}
      className="w-full rounded-full bg-primary-600 py-3 text-base font-medium text-white transition-colors hover:bg-primary-600/90 disabled:opacity-60"
    >
      {isPending ? "Confirming..." : "Confirm Bid"}
    </button>
  );
}

function DesktopDialog({
  open,
  onOpenChange,
  onConfirm,
  isPending,
  itemTitle,
  bidAmount,
}: ConfirmBidDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        showCloseButton={false}
        overlayClassName="bg-[#2B2B2F]/40 backdrop-blur-[1px]"
        className="max-w-[736px] rounded-xl bg-white border-none px-10 py-20 shadow-[0px_4px_16px_0px_rgba(0,0,1,0.08)]"
      >
        <DialogTitle className="sr-only">Confirm your bid</DialogTitle>
        <DialogDescription className="sr-only">
          Review and confirm your bid details
        </DialogDescription>

        <DialogClose className="absolute right-4 top-4 rounded-sm opacity-70 transition-opacity hover:opacity-100">
          <X className="size-5 text-neutral-03" />
          <span className="sr-only">Close</span>
        </DialogClose>

        <div className="flex gap-8">
          {/* Image placeholder */}
          <div className="flex flex-1 items-center justify-center rounded-lg bg-neutral-08">
            <Gavel className="size-16 text-neutral-05" />
          </div>

          {/* Details */}
          <div className="flex w-[291px] shrink-0 flex-col justify-center">
            <ItemPreview
              itemTitle={itemTitle}
              bidAmount={bidAmount}
              titleSize="text-2xl"
              amountSize="text-2xl"
              labelSize="text-xs"
            />
          </div>
        </div>

        <ConfirmButton onClick={onConfirm} isPending={isPending} />
      </DialogContent>
    </Dialog>
  );
}

function MobileDrawer({
  open,
  onOpenChange,
  onConfirm,
  isPending,
  itemTitle,
  bidAmount,
}: ConfirmBidDialogProps) {
  return (
    <Drawer open={open} onOpenChange={onOpenChange}>
      <DrawerContent
        overlayClassName="bg-[#0A0A0A]/40"
        className="rounded-t-3xl border-none px-4 bg-white pb-6 shadow-[0px_4px_8px_3px_rgba(3,38,38,0.08),0px_16px_24px_0px_rgba(3,38,38,0.24)]"
      >
        <DrawerDescription className="sr-only">
          Review and confirm your bid details
        </DrawerDescription>

        {/* Header */}
        <div className="flex items-center justify-between py-4">
          <DrawerTitle className="font-heading text-xl font-medium">
            Bid
          </DrawerTitle>
          <DrawerClose className="rounded-sm opacity-70 transition-opacity hover:opacity-100">
            <X className="size-5 text-neutral-03" />
            <span className="sr-only">Close</span>
          </DrawerClose>
        </div>

        {/* Image placeholder */}
        <div className="flex aspect-[4/3] w-full items-center justify-center rounded-xl bg-neutral-08">
          <Gavel className="size-12 text-neutral-05" />
        </div>

        <div className="mt-4">
          <ItemPreview
            itemTitle={itemTitle}
            bidAmount={bidAmount}
            titleSize="text-base"
            amountSize="text-base"
            labelSize="text-[10px]"
          />
        </div>

        <div className="mt-6">
          <ConfirmButton onClick={onConfirm} isPending={isPending} />
        </div>
      </DrawerContent>
    </Drawer>
  );
}

export function ConfirmBidDialog(props: ConfirmBidDialogProps) {
  const isMobile = useIsMobile();

  if (isMobile) {
    return <MobileDrawer {...props} />;
  }

  return <DesktopDialog {...props} />;
}
