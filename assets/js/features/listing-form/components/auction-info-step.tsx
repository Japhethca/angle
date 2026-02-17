import { useState } from "react";
import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Info } from "lucide-react";
import { toast } from "sonner";
import { updateDraftItem, buildCSRFHeaders } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import {
  Tooltip,
  TooltipContent,
  TooltipProvider,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { auctionInfoSchema, type AuctionInfoData } from "../schemas/listing-form-schema";

interface AuctionInfoStepProps {
  draftItemId: string;
  defaultValues: AuctionInfoData;
  onNext: (data: AuctionInfoData) => void;
  onBack: () => void;
}

export function AuctionInfoStep({ draftItemId, defaultValues, onNext, onBack }: AuctionInfoStepProps) {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const {
    register,
    handleSubmit,
    control,
    formState: { errors },
  } = useForm<AuctionInfoData>({
    resolver: zodResolver(auctionInfoSchema),
    defaultValues,
  });

  const onSubmit = async (data: AuctionInfoData) => {
    setIsSubmitting(true);
    try {
      const result = await updateDraftItem({
        identity: draftItemId,
        input: {
          id: draftItemId,
          startingPrice: data.startingPrice,
          reservePrice: data.reservePrice || undefined,
          attributes: { _auctionDuration: data.auctionDuration },
        },
        headers: buildCSRFHeaders(),
      });

      if (!result.success) {
        throw new Error(result.errors.map((e: any) => e.message).join("; "));
      }

      onNext(data);
    } catch (error) {
      toast.error(error instanceof Error ? error.message : "Failed to save auction info");
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
      {/* Starting Price + Reserve Price side-by-side */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Starting Price */}
        <div className="space-y-1.5">
          <Label htmlFor="startingPrice">Starting Price</Label>
          <div className="flex">
            <span className="flex items-center rounded-l-md border border-r-0 border-input bg-surface-muted px-3 text-sm text-content-tertiary">
              &#x20A6;
            </span>
            <Input
              id="startingPrice"
              placeholder="0.00"
              className="rounded-l-none"
              {...register("startingPrice")}
            />
          </div>
          <p className="text-xs text-content-tertiary">
            This is the minimum amount buyers can bid
          </p>
          {errors.startingPrice && (
            <p className="text-xs text-feedback-error">{errors.startingPrice.message}</p>
          )}
        </div>

        {/* Reserve Price */}
        <div className="space-y-1.5">
          <Label htmlFor="reservePrice">Reserve Price (Optional)</Label>
          <div className="flex">
            <span className="flex items-center rounded-l-md border border-r-0 border-input bg-surface-muted px-3 text-sm text-content-tertiary">
              &#x20A6;
            </span>
            <Input
              id="reservePrice"
              placeholder="0.00"
              className="rounded-l-none"
              {...register("reservePrice")}
            />
          </div>
          <p className="text-xs text-content-tertiary">
            Only you will see this. Item won't sell unless bids meet this amount.
          </p>
          {errors.reservePrice && (
            <p className="text-xs text-feedback-error">{errors.reservePrice.message}</p>
          )}
        </div>
      </div>

      {/* Auction Duration */}
      <div className="space-y-1.5">
        <div className="flex items-center gap-1.5">
          <Label>Auction Duration</Label>
          <TooltipProvider>
            <Tooltip>
              <TooltipTrigger asChild>
                <Info className="size-3.5 text-content-tertiary" />
              </TooltipTrigger>
              <TooltipContent>
                <p>Choose how long your auction will run.</p>
              </TooltipContent>
            </Tooltip>
          </TooltipProvider>
        </div>
        <Controller
          name="auctionDuration"
          control={control}
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue placeholder="Select duration" />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="24h">24 hours</SelectItem>
                <SelectItem value="3d">3 days</SelectItem>
                <SelectItem value="7d">7 days</SelectItem>
              </SelectContent>
            </Select>
          )}
        />
      </div>

      {/* Buttons */}
      <Button
        type="submit"
        disabled={isSubmitting}
        className="w-auto px-10 rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isSubmitting ? "Saving..." : "Next"}
      </Button>
    </form>
  );
}
