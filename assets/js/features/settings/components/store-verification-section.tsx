import { FileText, Trash2 } from "lucide-react";
import { Separator } from "@/components/ui/separator";

const verificationItems = [
  {
    label: "Personal id",
    filename: "Emmanuella's drivers license.pdf",
    badge: "Drivers license",
    date: "19/06/25",
  },
  {
    label: "Business ID",
    filename: "CAC reg doc.pdf",
    badge: "CAC registration",
    date: "19/06/25",
  },
];

export function StoreVerificationSection() {
  return (
    <div>
      <Separator className="mb-5" />
      <div className="space-y-4">
        <h3 className="text-sm font-semibold text-neutral-01">Verification</h3>
        {verificationItems.map((item) => (
          <div key={item.label} className="space-y-1.5">
            <p className="text-xs font-medium text-neutral-04">{item.label}</p>
            <div className="flex items-center gap-3 rounded-xl bg-neutral-08 p-4">
              <div className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-primary-600/10">
                <FileText className="size-5 text-primary-600" />
              </div>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-medium text-neutral-01">
                  {item.filename}
                </p>
                <span className="mt-0.5 inline-block rounded-full bg-green-100 px-2 py-0.5 text-[10px] font-medium text-green-700">
                  {item.badge}
                </span>
              </div>
              <button
                type="button"
                className="shrink-0 text-neutral-04 hover:text-red-500"
              >
                <Trash2 className="size-4" />
              </button>
            </div>
            <p className="text-xs text-neutral-04">
              Verification Date {item.date}
            </p>
          </div>
        ))}
      </div>
    </div>
  );
}
