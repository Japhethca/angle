import { User } from "lucide-react";
import { Button } from "@/components/ui/button";

export function ProfileImageSection() {
  return (
    <div className="flex items-center gap-4">
      <div className="flex size-16 shrink-0 items-center justify-center rounded-full bg-neutral-06 lg:size-20">
        <User className="size-8 text-neutral-04 lg:size-10" />
      </div>
      <div className="flex gap-2">
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="rounded-full"
        >
          Change
        </Button>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="rounded-full text-red-500"
        >
          Delete
        </Button>
      </div>
    </div>
  );
}
