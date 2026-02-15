import { Phone } from "lucide-react";
import { Separator } from "@/components/ui/separator";

export function TwoFactorSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <h2 className="mb-4 text-base font-semibold text-neutral-01">
        Two-factor Authentication
      </h2>

      {/* Phone number card */}
      <div className="flex items-center justify-between rounded-xl border border-neutral-07 p-4">
        <div className="flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-full bg-neutral-08">
            <Phone className="size-5 text-neutral-04" />
          </div>
          <div>
            <p className="text-sm font-medium text-neutral-01">Phone Number</p>
            <p className="text-xs text-neutral-04">
              08142963054{" "}
              <span className="text-green-600">· connected</span>
            </p>
          </div>
        </div>
        <button className="text-sm font-medium text-primary-600">
          Remove
        </button>
      </div>

      <p className="mt-3 text-xs text-neutral-05">Added 19/06/25</p>

      <button className="mt-3 flex items-center gap-1 text-sm font-medium text-primary-600">
        <span>+</span> Add New Number
      </button>
    </div>
  );
}
