import { useForm, Controller } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { ChevronDown } from "lucide-react";
import { useAshMutation } from "@/hooks/use-ash-query";
import { upsertStoreProfile, buildCSRFHeaders } from "@/ash_rpc";
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
import { Separator } from "@/components/ui/separator";
import type { ImageData } from "@/lib/image-url";
import { StoreLogoSection } from "./store-logo-section";
import { StoreVerificationSection } from "./store-verification-section";

const NIGERIAN_STATES = [
  "Abia", "Adamawa", "Akwa Ibom", "Anambra", "Bauchi", "Bayelsa", "Benue",
  "Borno", "Cross River", "Delta", "Ebonyi", "Edo", "Ekiti", "Enugu",
  "FCT Abuja", "Gombe", "Imo", "Jigawa", "Kaduna", "Kano", "Katsina",
  "Kebbi", "Kogi", "Kwara", "Lagos", "Nasarawa", "Niger", "Ogun", "Ondo",
  "Osun", "Oyo", "Plateau", "Rivers", "Sokoto", "Taraba", "Yobe", "Zamfara",
] as const;

const DELIVERY_OPTIONS = [
  { value: "you_arrange", label: "You arrange delivery" },
  { value: "seller_delivers", label: "Seller delivers" },
  { value: "pickup_only", label: "Pickup only" },
] as const;

const storeSchema = z.object({
  store_name: z.string().min(1, "Store name is required"),
  contact_phone: z.string().optional().or(z.literal("")),
  whatsapp_link: z.string().optional().or(z.literal("")),
  location: z.string().optional().or(z.literal("")),
  address: z.string().optional().or(z.literal("")),
  delivery_preference: z.string().optional().or(z.literal("")),
});

type StoreFormData = z.infer<typeof storeSchema>;

interface StoreFormProps {
  userId: string;
  storeProfile: {
    id: string;
    store_name: string;
    contact_phone: string | null;
    whatsapp_link: string | null;
    location: string | null;
    address: string | null;
    delivery_preference: string | null;
  } | null;
  logoImages: ImageData[];
}

export function StoreForm({ userId, storeProfile, logoImages }: StoreFormProps) {
  const {
    register,
    handleSubmit,
    control,
    formState: { errors, isDirty },
  } = useForm<StoreFormData>({
    resolver: zodResolver(storeSchema),
    defaultValues: {
      store_name: storeProfile?.store_name ?? "",
      contact_phone: storeProfile?.contact_phone ?? "",
      whatsapp_link: storeProfile?.whatsapp_link ?? "",
      location: storeProfile?.location ?? "",
      address: storeProfile?.address ?? "",
      delivery_preference: storeProfile?.delivery_preference ?? "you_arrange",
    },
  });

  const { mutate: saveStore, isPending } = useAshMutation(
    (data: StoreFormData) =>
      upsertStoreProfile({
        input: {
          userId: userId,
          storeName: data.store_name,
          contactPhone: data.contact_phone || null,
          whatsappLink: data.whatsapp_link || null,
          location: data.location || null,
          address: data.address || null,
          deliveryPreference: data.delivery_preference || "you_arrange",
        },
        fields: ["id", "storeName", "contactPhone", "whatsappLink", "location", "address", "deliveryPreference"],
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Store profile updated successfully");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to update store profile");
      },
    }
  );

  const onSubmit = (data: StoreFormData) => {
    saveStore(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
      {/* Store Logo */}
      <StoreLogoSection storeProfileId={storeProfile?.id ?? null} logoImages={logoImages} />

      {/* Form Fields */}
      <div className="space-y-5">
        {/* Store Name */}
        <div className="space-y-2">
          <Label htmlFor="store_name">Store Name</Label>
          <Input
            id="store_name"
            placeholder="Enter store name"
            {...register("store_name")}
          />
          {errors.store_name && (
            <p className="text-xs text-feedback-error">{errors.store_name.message}</p>
          )}
        </div>

        {/* Contact */}
        <div className="space-y-2">
          <Label htmlFor="contact_phone">Contact</Label>
          <div className="flex gap-2">
            <div className="flex h-10 shrink-0 items-center gap-1 rounded-md border border-input bg-surface-muted px-2 text-sm text-content-tertiary">
              <span className="text-xs leading-none">🇳🇬</span>
              <span>234</span>
              <ChevronDown className="size-3" />
            </div>
            <Input
              id="contact_phone"
              placeholder="Enter phone number"
              {...register("contact_phone")}
            />
          </div>
          {errors.contact_phone && (
            <p className="text-xs text-feedback-error">{errors.contact_phone.message}</p>
          )}
        </div>

        {/* WhatsApp Link */}
        <div className="space-y-2">
          <Label htmlFor="whatsapp_link">Whatsapp Link</Label>
          <div className="flex gap-2">
            <div className="flex h-10 shrink-0 items-center rounded-md border border-input bg-surface-muted px-3 text-sm text-content-tertiary">
              http://
            </div>
            <Input
              id="whatsapp_link"
              placeholder="wa.me/234"
              {...register("whatsapp_link")}
            />
          </div>
          {errors.whatsapp_link && (
            <p className="text-xs text-feedback-error">{errors.whatsapp_link.message}</p>
          )}
        </div>

        {/* Location (dropdown) */}
        <div className="space-y-2">
          <Label>Location</Label>
          <Controller
            name="location"
            control={control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger>
                  <SelectValue placeholder="Select state" />
                </SelectTrigger>
                <SelectContent>
                  {NIGERIAN_STATES.map((state) => (
                    <SelectItem key={state} value={state}>
                      {state}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          {errors.location && (
            <p className="text-xs text-feedback-error">{errors.location.message}</p>
          )}
        </div>

        {/* Address */}
        <div className="space-y-2">
          <Label htmlFor="address">Address</Label>
          <Input
            id="address"
            placeholder="Enter your address"
            {...register("address")}
          />
          {errors.address && (
            <p className="text-xs text-feedback-error">{errors.address.message}</p>
          )}
        </div>
      </div>

      {/* Verification */}
      <StoreVerificationSection />

      {/* Preferences */}
      <div>
        <Separator className="mb-5" />
        <div className="space-y-3">
          <h3 className="text-sm font-semibold text-content">Preferences</h3>
          <div className="space-y-2">
            <Label>Delivery</Label>
            <Controller
              name="delivery_preference"
              control={control}
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger>
                    <SelectValue placeholder="Select delivery option" />
                  </SelectTrigger>
                  <SelectContent>
                    {DELIVERY_OPTIONS.map((opt) => (
                      <SelectItem key={opt.value} value={opt.value}>
                        {opt.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </div>
        </div>
      </div>

      {/* Save Button */}
      <Button
        type="submit"
        disabled={isPending || !isDirty}
        className="w-full rounded-full bg-primary-600 text-white hover:bg-primary-600/90"
      >
        {isPending ? "Saving..." : "Save Changes"}
      </Button>
    </form>
  );
}
