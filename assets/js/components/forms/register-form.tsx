import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { router, Link } from "@inertiajs/react";
import { Button } from "../ui/button";
import { Input } from "../ui/input";
import { Label } from "../ui/label";
import { Alert, AlertDescription } from "../ui/alert";
import { Eye, EyeOff } from "lucide-react";

const emailSchema = z.object({
  full_name: z.string().min(1, "Full name is required"),
  email: z.string().email("Please enter a valid email address"),
  password: z.string().min(8, "Password must be at least 8 characters long"),
});

const phoneSchema = z.object({
  full_name: z.string().min(1, "Full name is required"),
  phone_number: z
    .string()
    .min(10, "Please enter a valid phone number")
    .regex(/^\d+$/, "Phone number must contain only digits"),
  password: z.string().min(8, "Password must be at least 8 characters long"),
});

type EmailFormData = z.infer<typeof emailSchema>;
type PhoneFormData = z.infer<typeof phoneSchema>;
type RegisterMode = "email" | "phone";

interface RegisterFormProps {
  error?: string;
}

function GoogleIcon() {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
      <path
        d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
        fill="#4285F4"
      />
      <path
        d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
        fill="#34A853"
      />
      <path
        d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18A10.96 10.96 0 0 0 1 12c0 1.77.42 3.44 1.18 4.93l3.66-2.84z"
        fill="#FBBC05"
      />
      <path
        d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
        fill="#EA4335"
      />
    </svg>
  );
}

function PasswordField({
  showPassword,
  onToggle,
  register,
  error,
}: {
  showPassword: boolean;
  onToggle: () => void;
  register: ReturnType<typeof useForm>["register"];
  error?: string;
}) {
  return (
    <div className="space-y-2">
      <Label htmlFor="password">Password</Label>
      <div className="relative">
        <Input
          id="password"
          type={showPassword ? "text" : "password"}
          placeholder="Enter your password"
          className="pr-10"
          {...register("password")}
        />
        <button
          type="button"
          onClick={onToggle}
          className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
          tabIndex={-1}
          aria-label={showPassword ? "Hide password" : "Show password"}
        >
          {showPassword ? (
            <EyeOff className="h-4 w-4" />
          ) : (
            <Eye className="h-4 w-4" />
          )}
        </button>
      </div>
      {error && <p className="text-sm text-red-600">{error}</p>}
    </div>
  );
}

export function RegisterForm({ error }: RegisterFormProps) {
  const [mode, setMode] = useState<RegisterMode>("email");
  const [showPassword, setShowPassword] = useState(false);

  const emailForm = useForm<EmailFormData>({
    resolver: zodResolver(emailSchema),
  });

  const phoneForm = useForm<PhoneFormData>({
    resolver: zodResolver(phoneSchema),
  });

  const isSubmitting =
    mode === "email"
      ? emailForm.formState.isSubmitting
      : phoneForm.formState.isSubmitting;

  const handleModeSwitch = (newMode: RegisterMode) => {
    setMode(newMode);
    emailForm.reset();
    phoneForm.reset();
  };

  const onEmailSubmit = (data: EmailFormData) => {
    router.post("/auth/register", {
      full_name: data.full_name,
      email: data.email,
      password: data.password,
    });
  };

  const onPhoneSubmit = (data: PhoneFormData) => {
    router.post("/auth/register", {
      full_name: data.full_name,
      phone_number: data.phone_number,
      email: `phone_${Date.now()}@placeholder.angle.app`,
      password: data.password,
    });
  };

  return (
    <div className="w-full space-y-6">
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Create Account</h1>
        <p className="mt-1 text-sm text-gray-500">
          Join Angle to start bidding on exclusive items
        </p>
      </div>

      {error && (
        <Alert variant="destructive">
          <AlertDescription>{error}</AlertDescription>
        </Alert>
      )}

      {/* Mode toggle */}
      <div className="flex rounded-full border border-gray-200 p-1">
        <button
          type="button"
          onClick={() => handleModeSwitch("email")}
          className={`flex-1 rounded-full px-4 py-2 text-sm font-medium transition-colors ${
            mode === "email"
              ? "bg-orange-500 text-white"
              : "text-gray-500 hover:text-gray-700"
          }`}
        >
          Email
        </button>
        <button
          type="button"
          onClick={() => handleModeSwitch("phone")}
          className={`flex-1 rounded-full px-4 py-2 text-sm font-medium transition-colors ${
            mode === "phone"
              ? "bg-orange-500 text-white"
              : "text-gray-500 hover:text-gray-700"
          }`}
        >
          Phone
        </button>
      </div>

      {/* Email form */}
      {mode === "email" && (
        <form
          id="register-form"
          onSubmit={emailForm.handleSubmit(onEmailSubmit)}
          className="space-y-4"
        >
          <div className="space-y-2">
            <Label htmlFor="full_name">Full Name</Label>
            <Input
              id="full_name"
              type="text"
              placeholder="Enter your full name"
              {...emailForm.register("full_name")}
            />
            {emailForm.formState.errors.full_name && (
              <p className="text-sm text-red-600">
                {emailForm.formState.errors.full_name.message}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="email">Email</Label>
            <Input
              id="email"
              type="email"
              placeholder="Enter your email"
              {...emailForm.register("email")}
            />
            {emailForm.formState.errors.email && (
              <p className="text-sm text-red-600">
                {emailForm.formState.errors.email.message}
              </p>
            )}
          </div>

          <PasswordField
            showPassword={showPassword}
            onToggle={() => setShowPassword(!showPassword)}
            register={emailForm.register}
            error={emailForm.formState.errors.password?.message}
          />

          <Button
            type="submit"
            className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12"
            disabled={isSubmitting}
          >
            {isSubmitting ? "Creating account..." : "Sign Up"}
          </Button>
        </form>
      )}

      {/* Phone form */}
      {mode === "phone" && (
        <form
          id="register-form"
          onSubmit={phoneForm.handleSubmit(onPhoneSubmit)}
          className="space-y-4"
        >
          <div className="space-y-2">
            <Label htmlFor="full_name">Full Name</Label>
            <Input
              id="full_name"
              type="text"
              placeholder="Enter your full name"
              {...phoneForm.register("full_name")}
            />
            {phoneForm.formState.errors.full_name && (
              <p className="text-sm text-red-600">
                {phoneForm.formState.errors.full_name.message}
              </p>
            )}
          </div>

          <div className="space-y-2">
            <Label htmlFor="phone_number">Phone Number</Label>
            <div className="flex gap-2">
              <div className="flex h-9 items-center rounded-md border border-input bg-gray-50 px-3 text-sm text-gray-500">
                +234
              </div>
              <Input
                id="phone_number"
                type="tel"
                placeholder="8012345678"
                className="flex-1"
                {...phoneForm.register("phone_number")}
              />
            </div>
            {phoneForm.formState.errors.phone_number && (
              <p className="text-sm text-red-600">
                {phoneForm.formState.errors.phone_number.message}
              </p>
            )}
          </div>

          <PasswordField
            showPassword={showPassword}
            onToggle={() => setShowPassword(!showPassword)}
            register={phoneForm.register}
            error={phoneForm.formState.errors.password?.message}
          />

          <Button
            type="submit"
            className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12"
            disabled={isSubmitting}
          >
            {isSubmitting ? "Creating account..." : "Sign Up"}
          </Button>
        </form>
      )}

      <p className="text-center text-xs text-gray-500">
        By signing up, you agree to our{" "}
        <Link href="/terms" className="text-orange-500 hover:underline">
          Terms of Service
        </Link>{" "}
        and{" "}
        <Link href="/conditions" className="text-orange-500 hover:underline">
          Conditions
        </Link>
      </p>

      <div className="text-center text-sm text-gray-600">
        Already have an account?{" "}
        <Link
          href="/auth/login"
          className="font-medium text-orange-500 hover:underline"
        >
          Log In
        </Link>
      </div>

      {/* Divider */}
      <div className="relative">
        <div className="absolute inset-0 flex items-center">
          <div className="w-full border-t border-gray-200" />
        </div>
        <div className="relative flex justify-center text-sm">
          <span className="bg-white px-4 text-gray-400">or</span>
        </div>
      </div>

      {/* Google sign-in */}
      <Button
        type="button"
        variant="outline"
        className="w-full rounded-full h-12"
        onClick={() => router.visit("/auth/google")}
      >
        <GoogleIcon />
        Continue with Google
      </Button>
    </div>
  );
}
