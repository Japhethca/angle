import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { ChevronDown } from "lucide-react";
import { useAshMutation } from "@/hooks/use-ash-query";
import { updateProfile, buildCSRFHeaders } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import type { ImageData } from "@/lib/image-url";
import { ProfileImageSection } from "./profile-image-section";
import { VerificationSection } from "./verification-section";
import { QuickSignInSection } from "./quick-sign-in-section";

const profileSchema = z.object({
  full_name: z.string().min(1, "Name is required"),
  phone_number: z.string().optional().or(z.literal("")),
  location: z.string().optional().or(z.literal("")),
});

type ProfileFormData = z.infer<typeof profileSchema>;

interface AccountFormProps {
  user: {
    id: string;
    email: string;
    full_name: string | null;
    phone_number: string | null;
    location: string | null;
  };
  avatarImages: ImageData[];
}

export function AccountForm({ user, avatarImages }: AccountFormProps) {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
  } = useForm<ProfileFormData>({
    resolver: zodResolver(profileSchema),
    defaultValues: {
      full_name: user.full_name ?? "",
      phone_number: user.phone_number ?? "",
      location: user.location ?? "",
    },
  });

  const { mutate: saveProfile, isPending } = useAshMutation(
    (data: ProfileFormData) =>
      updateProfile({
        identity: user.id,
        input: {
          fullName: data.full_name,
          phoneNumber: data.phone_number || null,
          location: data.location || null,
        },
        fields: ["id", "fullName", "phoneNumber", "location"],
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Profile updated successfully");
        router.reload();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to update profile");
      },
    }
  );

  const onSubmit = (data: ProfileFormData) => {
    saveProfile(data);
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-8">
      {/* Profile Image */}
      <ProfileImageSection userId={user.id} avatarImages={avatarImages} />

      {/* Form Fields */}
      <div className="space-y-5">
        {/* Name */}
        <div className="space-y-2">
          <Label htmlFor="full_name">Name</Label>
          <Input
            id="full_name"
            placeholder="Enter your full name"
            {...register("full_name")}
          />
          {errors.full_name && (
            <p className="text-xs text-feedback-error">{errors.full_name.message}</p>
          )}
        </div>

        {/* Email (read-only) */}
        <div className="space-y-2">
          <Label htmlFor="email">Email</Label>
          <Input
            id="email"
            value={user.email}
            disabled
            className="bg-surface-muted text-content-tertiary"
          />
        </div>

        {/* Phone Number */}
        <div className="space-y-2">
          <Label htmlFor="phone_number">Phone Number</Label>
          <div className="flex gap-2">
            <div className="flex h-10 shrink-0 items-center gap-1 rounded-md border border-input bg-surface-muted px-2 text-sm text-content-tertiary">
              <span className="text-xs leading-none">🇳🇬</span>
              <span>234</span>
              <ChevronDown className="size-3" />
            </div>
            <Input
              id="phone_number"
              placeholder="Enter phone number"
              {...register("phone_number")}
            />
          </div>
          {errors.phone_number && (
            <p className="text-xs text-feedback-error">
              {errors.phone_number.message}
            </p>
          )}
        </div>

        {/* Address */}
        <div className="space-y-2">
          <Label htmlFor="location">Address</Label>
          <Input
            id="location"
            placeholder="Enter your address"
            {...register("location")}
          />
          {errors.location && (
            <p className="text-xs text-feedback-error">{errors.location.message}</p>
          )}
        </div>
      </div>

      {/* Verification */}
      <VerificationSection />

      {/* Quick Sign In */}
      <QuickSignInSection />

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
