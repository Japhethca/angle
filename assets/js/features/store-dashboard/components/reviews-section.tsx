import { Star } from "lucide-react";

export function ReviewsSection() {
  return (
    <div className="rounded-xl border border-surface-muted bg-white p-6">
      <h3 className="text-base font-semibold text-content">Reviews</h3>

      <div className="flex flex-col items-center justify-center py-12 text-center">
        <Star className="mb-3 size-10 text-surface-emphasis" />
        <p className="text-content-tertiary">No reviews yet</p>
        <p className="mt-1 text-sm text-content-placeholder">
          Reviews will appear here once buyers leave feedback
        </p>
      </div>
    </div>
  );
}
