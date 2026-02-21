import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { toast } from "sonner";
import { updateDraftItem, buildCSRFHeaders } from "@/ash_rpc";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { LocationCombobox } from "@/components/forms/location-combobox";
import { cn } from "@/lib/utils";
import { logisticsSchema, type LogisticsData } from "../schemas/listing-form-schema";

const DELIVERY_OPTIONS = [
  { value: "meetup", label: "Meet-up in person" },
  { value: "buyer_arranges", label: "Buyer arranges delivery" },
  { value: "seller_arranges", label: "Seller (you) arranges delivery" },
] as const;

interface LogisticsStepProps {
  draftItemId: string;
  defaultValues: LogisticsData;
  onNext: (data: LogisticsData) => void;
  onBack: () => void;
}

export function LogisticsStep({ draftItemId, defaultValues, onNext }: LogisticsStepProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const {
    handleSubmit,
    watch,
    setValue,
    formState: { errors },
  } = useForm<LogisticsData>({
    resolver: zodResolver(logisticsSchema),
    defaultValues,
  });

  const selected = watch("deliveryPreference");

  const onSubmit = async (data: LogisticsData) => {
    setIsSubmitting(true);
    try {
      const result = await updateDraftItem({
        identity: draftItemId,
        input: {
          id: draftItemId,
          attributes: {
            _deliveryPreference: data.deliveryPreference,
            _state: data.location.state,
            _lga: data.location.lga || null,
          },
        },
        headers: buildCSRFHeaders(),
      });

      if (!result.success) {
        throw new Error(result.errors.map((e: any) => e.message).join("; "));
      }

      onNext(data);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to save logistics");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-6">
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

      <div className="space-y-3">
        <Label className="text-base font-medium">
          Where is the item located? <span className="text-destructive">*</span>
        </Label>
        <LocationCombobox
          value={watch("location")}
          onChange={(val) => setValue("location", val, { shouldValidate: true })}
          error={errors.location?.state?.message}
        />
        <p className="text-xs text-content-tertiary">
          Buyers need to know the item's location for delivery/pickup planning
        </p>
      </div>

      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Preview"}
      </Button>
    </form>
  );
}
