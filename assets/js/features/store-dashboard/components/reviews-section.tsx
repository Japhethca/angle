import { Star } from "lucide-react";
import { ReviewCard } from "@/components/reviews/review-card";

interface ReviewsSectionProps {
  reviews: Array<{
    id: string;
    rating: number;
    comment: string | null;
    insertedAt: string;
    reviewer?: { id: string; username: string | null; fullName: string | null };
  }>;
}

export function ReviewsSection({ reviews = [] }: ReviewsSectionProps) {
  return (
    <div className="rounded-xl border border-surface-muted bg-white p-6">
      <h3 className="text-base font-semibold text-content">Reviews</h3>

      {reviews.length > 0 ? (
        <div className="mt-4">
          {reviews.map((review) => (
            <ReviewCard key={review.id} review={review} />
          ))}
        </div>
      ) : (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Star className="mb-3 size-10 text-surface-emphasis" />
          <p className="text-content-tertiary">No reviews yet</p>
          <p className="mt-1 text-sm text-content-placeholder">
            Reviews will appear here once buyers leave feedback
          </p>
        </div>
      )}
    </div>
  );
}
