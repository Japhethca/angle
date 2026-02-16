import { CircleAlert, X } from "lucide-react";
import { useState } from "react";

export function OutbidBadge() {
  const [dismissed, setDismissed] = useState(false);

  if (dismissed) return null;

  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-feedback-error/20 bg-feedback-error-muted px-3 py-1.5 text-sm text-feedback-error">
      <CircleAlert className="size-4" />
      <span>You've been outbid</span>
      <button onClick={() => setDismissed(true)} className="ml-1">
        <X className="size-3.5" />
      </button>
    </div>
  );
}
