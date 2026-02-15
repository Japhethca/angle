import { Monitor, Camera } from "lucide-react";
import { Button } from "@/components/ui/button";

export function StoreLogoSection() {
  return (
    <div className="flex items-center gap-4">
      <div className="flex size-16 shrink-0 items-center justify-center rounded-2xl bg-surface-muted lg:size-20">
        <Monitor className="size-8 text-primary-600 lg:size-10" />
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold text-content">Store logo</p>
        <div className="flex items-center gap-2">
          <Button type="button" variant="outline" size="sm" className="rounded-full">
            Change
            <Camera className="size-4" />
          </Button>
          <Button type="button" variant="ghost" size="sm" className="rounded-full text-content-tertiary">
            Delete
          </Button>
        </div>
      </div>
    </div>
  );
}
