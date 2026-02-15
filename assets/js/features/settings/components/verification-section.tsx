import { ShieldCheck } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function VerificationSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-neutral-01">Verification</h3>
        <div className="flex items-center gap-3 rounded-xl bg-neutral-08 p-4">
          <ShieldCheck className="size-5 text-neutral-04" />
          <div className="flex-1">
            <p className="text-sm font-medium text-neutral-02">
              Government Issued ID
            </p>
            <p className="text-xs text-neutral-04">Uploaded</p>
          </div>
        </div>
      </div>
    </div>
  );
}
