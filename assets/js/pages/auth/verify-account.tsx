import { useState, useEffect, useCallback } from "react";
import { Head, usePage, router } from "@inertiajs/react";
import {
  InputOTP,
  InputOTPGroup,
  InputOTPSlot,
  InputOTPSeparator,
} from "@/components/ui/input-otp";
import { AuthProvider } from "@/features/auth";
import type { PageProps } from "@/features/auth";
import { AuthLayout } from "@/layouts/auth-layout";
import { Button } from "@/components/ui/button";
import { Alert, AlertDescription } from "@/components/ui/alert";

interface VerifyAccountPageProps extends PageProps {
  email?: string;
}

export default function VerifyAccount() {
  const { props } = usePage<VerifyAccountPageProps>();
  const [code, setCode] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isResending, setIsResending] = useState(false);
  const [cooldownSeconds, setCooldownSeconds] = useState(60);

  useEffect(() => {
    if (cooldownSeconds <= 0) return;

    const timer = setInterval(() => {
      setCooldownSeconds((prev) => prev - 1);
    }, 1000);

    return () => clearInterval(timer);
  }, [cooldownSeconds]);

  const resetCooldown = useCallback(() => {
    setCooldownSeconds(60);
  }, []);

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setIsSubmitting(true);
    router.post(
      "/auth/verify-account",
      { code },
      {
        onFinish: () => setIsSubmitting(false),
      }
    );
  }

  function handleResend() {
    setIsResending(true);
    router.post(
      "/auth/resend-otp",
      {},
      {
        onFinish: () => {
          setIsResending(false);
          setCode("");
          resetCooldown();
        },
      }
    );
  }

  return (
    <AuthLayout>
      <Head title="Verify Account" />

      <div className="space-y-6">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-gray-900">
            Verify Account
          </h1>
          <p className="mt-2 text-sm text-gray-600">
            Check your email for the OTP code shared.
          </p>
        </div>

        {props.flash?.error && (
          <Alert variant="destructive">
            <AlertDescription>{props.flash.error}</AlertDescription>
          </Alert>
        )}

        <form id="verify-form" onSubmit={handleSubmit} className="space-y-6">
          <div className="space-y-2">
            <label className="text-sm font-medium text-gray-700">
              Secure code
            </label>
            <InputOTP
              maxLength={6}
              value={code}
              onChange={(value) => setCode(value)}
            >
              <InputOTPGroup>
                <InputOTPSlot index={0} className="h-12 w-12 text-lg" />
                <InputOTPSlot index={1} className="h-12 w-12 text-lg" />
                <InputOTPSlot index={2} className="h-12 w-12 text-lg" />
              </InputOTPGroup>
              <InputOTPSeparator />
              <InputOTPGroup>
                <InputOTPSlot index={3} className="h-12 w-12 text-lg" />
                <InputOTPSlot index={4} className="h-12 w-12 text-lg" />
                <InputOTPSlot index={5} className="h-12 w-12 text-lg" />
              </InputOTPGroup>
            </InputOTP>
          </div>

          <Button
            type="submit"
            disabled={code.length !== 6 || isSubmitting}
            className="w-full bg-orange-500 hover:bg-orange-600 text-white rounded-full h-12"
          >
            {isSubmitting ? "Verifying..." : "Verify Account"}
          </Button>
        </form>

        <div className="text-center text-sm text-gray-600">
          Didn't receive code?{" "}
          <button
            type="button"
            onClick={handleResend}
            disabled={isResending || cooldownSeconds > 0}
            className="font-medium text-orange-500 hover:text-orange-600 disabled:opacity-50"
          >
            {isResending
              ? "Resending..."
              : cooldownSeconds > 0
                ? `Resend OTP (${cooldownSeconds}s)`
                : "Resend OTP"}
          </button>
        </div>
      </div>
    </AuthLayout>
  );
}

VerifyAccount.layout = (page: React.ReactNode) => (
  <AuthProvider>{page}</AuthProvider>
);
