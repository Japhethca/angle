import { FileText, Trash2 } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function VerificationSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-3">
        <h3 className="text-sm font-semibold text-content">Verification</h3>
        <div className="flex items-center gap-3 rounded-xl bg-surface-muted p-4">
          <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary-600/10">
            <FileText className="size-5 text-primary-600" />
          </div>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-medium text-content">
              Government issued ID.pdf
            </p>
            <span className="mt-0.5 inline-block rounded-full bg-feedback-success-muted px-2 py-0.5 text-[10px] font-medium text-feedback-success">
              Drivers license
            </span>
          </div>
          <button
            type="button"
            className="shrink-0 text-content-tertiary hover:text-feedback-error"
          >
            <Trash2 className="size-4" />
          </button>
        </div>
        <p className="text-xs text-content-tertiary">
          Verification Date 19/06/25
        </p>
      </div>
    </div>
  );
}
