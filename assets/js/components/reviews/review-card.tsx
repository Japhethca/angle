import { User } from "lucide-react";
import { StarDisplay } from "./star-display";

interface ReviewCardProps {
  review: {
    id: string;
    rating: number;
    comment: string | null;
    insertedAt: string;
    reviewer?: {
      id: string;
      username: string | null;
      fullName: string | null;
    };
  };
}

function formatReviewDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function ReviewCard({ review }: ReviewCardProps) {
  const displayName =
    review.reviewer?.username || review.reviewer?.fullName || "Anonymous";

  return (
    <div className="flex gap-3 border-b border-surface-muted py-4 last:border-0">
      <div className="flex size-10 shrink-0 items-center justify-center rounded-full bg-surface-muted">
        <User className="size-5 text-content-placeholder" />
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-2">
          <span className="text-sm font-medium text-content">{displayName}</span>
          <span className="text-xs text-content-placeholder">
            {formatReviewDate(review.insertedAt)}
          </span>
        </div>
        <div className="mt-1">
          <StarDisplay rating={review.rating} />
        </div>
        {review.comment && (
          <p className="mt-2 text-sm text-content-secondary">{review.comment}</p>
        )}
      </div>
    </div>
  );
}
