import { User, Camera, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ProfileImageSection() {
  return (
    <div className="flex items-center gap-4">
      <div className="flex size-16 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-20">
        <User className="size-8 text-neutral-04 lg:size-10" />
      </div>
      <div>
        <p className="mb-2 text-sm font-semibold text-neutral-01">
          Profile Image
        </p>
        <div className="flex items-center gap-2">
          <Button
            type="button"
            variant="outline"
            size="sm"
            className="rounded-full"
          >
            Change
            <Camera className="size-4" />
          </Button>
          <Button
            type="button"
            variant="ghost"
            size="icon"
            className="size-8 text-neutral-04 hover:text-red-500"
          >
            <Trash2 className="size-4" />
          </Button>
        </div>
      </div>
    </div>
  );
}
