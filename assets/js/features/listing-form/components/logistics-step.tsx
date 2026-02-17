import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { cn } from "@/lib/utils";
import { logisticsSchema, type LogisticsData } from "../schemas/listing-form-schema";

const DELIVERY_OPTIONS = [
  { value: "meetup", label: "Meet-up in person" },
  { value: "buyer_arranges", label: "Buyer arranges delivery" },
  { value: "seller_arranges", label: "Seller (you) arranges delivery" },
] as const;

interface LogisticsStepProps {
  defaultValues: LogisticsData;
  onNext: (data: LogisticsData) => void;
  onBack: () => void;
}

export function LogisticsStep({ defaultValues, onNext }: LogisticsStepProps) {
  const {
    handleSubmit,
    watch,
    setValue,
  } = useForm<LogisticsData>({
    resolver: zodResolver(logisticsSchema),
    defaultValues,
  });

  const selected = watch("deliveryPreference");

  return (
    <form onSubmit={handleSubmit(onNext)} className="space-y-6">
      <div className="space-y-3">
        <Label className="text-base font-medium">How will buyers get the item?</Label>
        <div className="space-y-2">
          {DELIVERY_OPTIONS.map((opt) => (
            <label
              key={opt.value}
              className={cn(
                "flex cursor-pointer items-center gap-3 rounded-lg border px-4 py-3 transition-colors",
                selected === opt.value
                  ? "border-primary-600 bg-primary-600/5"
                  : "border-border hover:bg-surface-secondary"
              )}
            >
              <div
                className={cn(
                  "flex size-5 items-center justify-center rounded-full border-2",
                  selected === opt.value
                    ? "border-primary-600"
                    : "border-content-tertiary"
                )}
              >
                {selected === opt.value && (
                  <div className="size-2.5 rounded-full bg-primary-600" />
                )}
              </div>
              <input
                type="radio"
                name="deliveryPreference"
                value={opt.value}
                checked={selected === opt.value}
                onChange={() => setValue("deliveryPreference", opt.value)}
                className="hidden"
              />
              <span className="text-sm font-medium text-content">{opt.label}</span>
            </label>
          ))}
        </div>
      </div>

      <Button
        type="submit"
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        Preview
      </Button>
    </form>
  );
}
