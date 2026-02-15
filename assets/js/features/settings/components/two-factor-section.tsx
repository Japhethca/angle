import { Phone } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function TwoFactorSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <h2 className="mb-4 text-base font-semibold text-content">
        Two-factor Authentication
      </h2>

      {/* Phone number card */}
      <div className="flex items-center justify-between rounded-xl border border-subtle p-4">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-full bg-surface-muted">
            <Phone className="size-5 text-content-tertiary" />
          </div>
          <div>
            <p className="text-sm font-medium text-content">Phone Number</p>
            <p className="text-xs text-content-tertiary">
              08142963054{" "}
              <span className="text-green-600">· connected</span>
            </p>
          </div>
        </div>
        <button className="text-sm font-medium text-primary-600">
          Remove
        </button>
      </div>

      <p className="mt-3 text-xs text-content-placeholder">Added 19/06/25</p>

      <button className="mt-3 flex items-center gap-1 text-sm font-medium text-primary-600">
        <span>+</span> Add New Number
      </button>
    </div>
  );
}
