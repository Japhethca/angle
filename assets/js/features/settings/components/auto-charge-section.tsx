import { Separator } from "@/components/ui/separator";
import { Switch } from "@/components/ui/switch";
import { useAshMutation } from "@/hooks/use-ash-query";
import { updateAutoCharge, buildCSRFHeaders } from "@/ash_rpc";
import { toast } from "sonner";

interface AutoChargeSectionProps {
  userId: string;
  autoCharge: boolean;
}

export function AutoChargeSection({ userId, autoCharge }: AutoChargeSectionProps) {
  const { mutate, isPending } = useAshMutation(
    (checked: boolean) =>
      updateAutoCharge({
        identity: userId,
        input: { autoCharge: checked },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => toast.success("Auto-charge preference updated"),
      onError: () => toast.error("Failed to update auto-charge preference"),
    }
  );

  return (
    <div>
      <Separator className="mb-5" />
      <h2 className="mb-4 text-base font-semibold text-neutral-01">Post-win</h2>
      <div className="flex items-center justify-between rounded-xl border border-neutral-07 p-4">
        <div>
          <p className="text-sm font-medium text-neutral-01">Auto-charge</p>
          <p className="text-xs text-neutral-04">
            Your saved payment method would automatically be charged when you win a bid
          </p>
        </div>
        <Switch
          checked={autoCharge}
          onCheckedChange={(checked) => mutate(checked)}
          disabled={isPending}
        />
      </div>
    </div>
  );
}
