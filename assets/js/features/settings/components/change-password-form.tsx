import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { toast } from "sonner";
import { useAshMutation } from "@/hooks/use-ash-query";
import { changePassword, buildCSRFHeaders } from "@/ash_rpc";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";

const passwordSchema = z
  .object({
    current_password: z.string().min(1, "Current password is required"),
    new_password: z.string().min(8, "Password must be at least 8 characters"),
    confirm_password: z.string().min(1, "Please confirm your new password"),
  })
  .refine((data) => data.new_password === data.confirm_password, {
    message: "Passwords do not match",
    path: ["confirm_password"],
  });

type PasswordFormData = z.infer<typeof passwordSchema>;

interface ChangePasswordFormProps {
  userId: string;
}

export function ChangePasswordForm({ userId }: ChangePasswordFormProps) {
  const {
    register,
    handleSubmit,
    reset,
    formState: { errors, isDirty },
  } = useForm<PasswordFormData>({
    resolver: zodResolver(passwordSchema),
    defaultValues: {
      current_password: "",
      new_password: "",
      confirm_password: "",
    },
  });

  const { mutate: doChangePassword, isPending } = useAshMutation(
    (data: PasswordFormData) =>
      changePassword({
        identity: userId,
        input: {
          currentPassword: data.current_password,
          password: data.new_password,
          passwordConfirmation: data.confirm_password,
        },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Password changed successfully");
        reset();
      },
      onError: (error) => {
        toast.error(error.message || "Failed to change password");
      },
    }
  );

  const onSubmit = (data: PasswordFormData) => {
    doChangePassword(data);
  };

  return (
    <div>
      <h2 className="mb-5 text-base font-semibold text-neutral-01">
        Change Password
      </h2>
      <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
        <div className="space-y-2">
          <Label htmlFor="current_password">Old Password</Label>
          <Input
            id="current_password"
            type="password"
            {...register("current_password")}
          />
          {errors.current_password && (
            <p className="text-xs text-red-500">
              {errors.current_password.message}
            </p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="new_password">New Password</Label>
          <Input
            id="new_password"
            type="password"
            {...register("new_password")}
          />
          {errors.new_password && (
            <p className="text-xs text-red-500">
              {errors.new_password.message}
            </p>
          )}
        </div>

        <div className="space-y-2">
          <Label htmlFor="confirm_password">Confirm New Password</Label>
          <Input
            id="confirm_password"
            type="password"
            {...register("confirm_password")}
          />
          {errors.confirm_password && (
            <p className="text-xs text-red-500">
              {errors.confirm_password.message}
            </p>
          )}
        </div>

        <Button
          type="submit"
          disabled={isPending || !isDirty}
          className="rounded-full bg-primary-600 px-8 text-white hover:bg-primary-600/90"
        >
          {isPending ? "Saving..." : "Save"}
        </Button>
      </form>
    </div>
  );
}
