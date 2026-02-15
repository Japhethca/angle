import { useState } from "react";
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
  const [checked, setChecked] = useState(autoCharge);

  const { mutate, isPending } = useAshMutation(
    (value: boolean) =>
      updateAutoCharge({
        identity: userId,
        input: { autoCharge: value },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => toast.success("Auto-charge preference updated"),
      onError: () => {
        setChecked((prev) => !prev);
        toast.error("Failed to update auto-charge preference");
      },
    }
  );

  const handleToggle = (value: boolean) => {
    setChecked(value);
    mutate(value);
  };

  return (
    <div>
      <Separator className="mb-5" />
      <h2 className="mb-4 text-base font-semibold text-content">Post-win</h2>
      <div className="flex items-center justify-between rounded-xl border border-subtle p-4">
        <div>
          <p className="text-sm font-medium text-content">Auto-charge</p>
          <p className="text-xs text-content-tertiary">
            Your saved payment method would automatically be charged when you win a bid
          </p>
        </div>
        <Switch
          checked={checked}
          onCheckedChange={handleToggle}
          disabled={isPending}
        />
      </div>
    </div>
  );
}
