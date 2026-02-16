import { Star } from "lucide-react";
import { cn } from "@/lib/utils";

interface StarDisplayProps {
  rating: number;
  size?: "sm" | "md";
}

export function StarDisplay({ rating, size = "sm" }: StarDisplayProps) {
  const iconSize = size === "sm" ? "size-3.5" : "size-4";

  return (
    <div className="flex items-center gap-0.5">
      {[1, 2, 3, 4, 5].map((star) => (
        <Star
          key={star}
          className={cn(
            iconSize,
            star <= Math.round(rating)
              ? "fill-yellow-400 text-yellow-400"
              : "text-gray-300",
          )}
        />
      ))}
    </div>
  );
}
