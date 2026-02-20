import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useAshMutation } from "@/hooks/use-ash-query";
import { requestPhoneOtp, verifyPhoneOtp, buildCSRFHeaders } from "@/ash_rpc";
import { toast } from "sonner";
import { router } from "@inertiajs/react";
import { CheckCircle2, Clock } from "lucide-react";

interface PhoneVerificationProps {
  verificationId: string;
  initialPhoneNumber?: string | null;
  phoneVerified: boolean;
  phoneVerifiedAt?: string | null;
  onVerified?: () => void;
}

export function PhoneVerification({
  verificationId,
  initialPhoneNumber,
  phoneVerified,
  phoneVerifiedAt,
  onVerified,
}: PhoneVerificationProps) {
  const [phoneNumber, setPhoneNumber] = useState(initialPhoneNumber || "");
  const [otpSent, setOtpSent] = useState(false);
  const [otpCode, setOtpCode] = useState("");
  const [countdown, setCountdown] = useState(0);

  // Countdown timer for rate limiting
  useEffect(() => {
    if (countdown > 0) {
      const timer = setTimeout(() => setCountdown(countdown - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [countdown]);

  const requestOtpMutation = useAshMutation(
    async (phone: string) => {
      return requestPhoneOtp({
        identity: verificationId,
        input: { phoneNumber: phone },
        fields: ["id", "phoneNumber", "phoneVerified"],
        headers: buildCSRFHeaders(),
      });
    },
    {
      onSuccess: (result) => {
        if (result.success) {
          setOtpSent(true);
          setCountdown(60);
          toast.success("OTP sent! Check your phone for the verification code.");

          // In dev/test mode, the OTP is returned in the result
          if (process.env.NODE_ENV === "development" && (result.data as any).otpCode) {
            console.log("Test OTP Code:", (result.data as any).otpCode);
            toast.info(`Test OTP: ${(result.data as any).otpCode}`, {
              duration: 10000,
            });
          }
        } else {
          toast.error(result.errors[0]?.message || "Failed to send OTP");
        }
      },
      onError: (error) => {
        toast.error(error.message || "Failed to send OTP");
      },
    }
  );

  const verifyOtpMutation = useAshMutation(
    async (code: string) => {
      return verifyPhoneOtp({
        identity: verificationId,
        input: { otpCode: code },
        fields: ["id", "phoneVerified", "phoneVerifiedAt"],
        headers: buildCSRFHeaders(),
      });
    },
    {
      onSuccess: (result) => {
        if (result.success) {
          toast.success("Phone number verified successfully!");
          setOtpSent(false);
          setOtpCode("");
          if (onVerified) {
            onVerified();
          }
          router.reload();
        } else {
          toast.error(result.errors[0]?.message || "Invalid OTP code");
        }
      },
      onError: (error) => {
        toast.error(error.message || "Failed to verify OTP");
      },
    }
  );

  const handleSendOtp = () => {
    // Prepend +234 for Nigeria if not already present
    let formattedPhone = phoneNumber.trim();
    if (!formattedPhone.startsWith("+")) {
      formattedPhone = "+234" + formattedPhone.replace(/^0+/, "");
    }

    // Basic validation
    if (formattedPhone.length < 10) {
      toast.error("Please enter a valid phone number");
      return;
    }

    requestOtpMutation.mutate(formattedPhone);
  };

  const handleVerifyOtp = () => {
    if (otpCode.length !== 6) {
      toast.error("Please enter a 6-digit OTP code");
      return;
    }

    verifyOtpMutation.mutate(otpCode);
  };

  // If already verified, show status
  if (phoneVerified && phoneVerifiedAt) {
    return (
      <div className="rounded-lg border border-green-200 bg-green-50 p-4">
        <div className="flex items-center gap-2">
          <CheckCircle2 className="h-5 w-5 text-green-600" />
          <div>
            <p className="font-medium text-green-900">Phone Verified</p>
            <p className="text-sm text-green-700">
              Verified on {new Date(phoneVerifiedAt).toLocaleDateString()}
            </p>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div>
        <Label htmlFor="phone-number">Phone Number</Label>
        <div className="flex gap-2">
          <Input
            id="phone-number"
            type="tel"
            placeholder="08012345678"
            value={phoneNumber}
            onChange={(e) => setPhoneNumber(e.target.value)}
            disabled={otpSent || requestOtpMutation.isPending}
          />
          <Button
            onClick={handleSendOtp}
            disabled={
              !phoneNumber ||
              countdown > 0 ||
              otpSent ||
              requestOtpMutation.isPending
            }
          >
            {countdown > 0 ? (
              <span className="flex items-center gap-1">
                <Clock className="h-4 w-4" />
                {countdown}s
              </span>
            ) : requestOtpMutation.isPending ? (
              "Sending..."
            ) : (
              "Send OTP"
            )}
          </Button>
        </div>
        <p className="text-sm text-muted-foreground mt-1">
          Enter your Nigerian phone number. We'll send you a verification code.
        </p>
      </div>

      {otpSent && (
        <div className="space-y-3 animate-in slide-in-from-top-2">
          <div>
            <Label htmlFor="otp-code">Verification Code</Label>
            <Input
              id="otp-code"
              type="text"
              inputMode="numeric"
              maxLength={6}
              placeholder="Enter 6-digit code"
              value={otpCode}
              onChange={(e) => setOtpCode(e.target.value.replace(/\D/g, ""))}
              disabled={verifyOtpMutation.isPending}
            />
            <p className="text-sm text-muted-foreground mt-1">
              Enter the 6-digit code sent to your phone.
            </p>
          </div>

          <div className="flex gap-2">
            <Button
              className="flex-1"
              onClick={handleVerifyOtp}
              disabled={otpCode.length !== 6 || verifyOtpMutation.isPending}
            >
              {verifyOtpMutation.isPending ? "Verifying..." : "Verify"}
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                setOtpSent(false);
                setOtpCode("");
              }}
              disabled={verifyOtpMutation.isPending}
            >
              Cancel
            </Button>
          </div>

          {countdown === 0 && (
            <Button
              variant="link"
              className="w-full"
              onClick={handleSendOtp}
              disabled={requestOtpMutation.isPending}
            >
              Didn't receive code? Resend
            </Button>
          )}
        </div>
      )}
    </div>
  );
}
