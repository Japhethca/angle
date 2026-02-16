import { useState } from "react";
import { Star } from "lucide-react";
import { createReview, updateReview, buildCSRFHeaders } from "@/ash_rpc";
import { useAshMutation } from "@/hooks/use-ash-query";
import { router } from "@inertiajs/react";
import { toast } from "sonner";
import { cn } from "@/lib/utils";

interface ReviewFormProps {
  orderId: string;
  existingReview?: {
    id: string;
    rating: number;
    comment: string | null;
    insertedAt: string;
  } | null;
  onClose: () => void;
}

function StarRating({
  value,
  onChange,
}: {
  value: number;
  onChange: (v: number) => void;
}) {
  const [hover, setHover] = useState(0);

  return (
    <div className="flex gap-1">
      {[1, 2, 3, 4, 5].map((star) => (
        <button
          key={star}
          type="button"
          onClick={() => onChange(star)}
          onMouseEnter={() => setHover(star)}
          onMouseLeave={() => setHover(0)}
          className="p-0.5"
        >
          <Star
            className={cn(
              "size-6 transition-colors",
              (hover || value) >= star
                ? "fill-yellow-400 text-yellow-400"
                : "text-gray-300",
            )}
          />
        </button>
      ))}
    </div>
  );
}

export function ReviewForm({
  orderId,
  existingReview,
  onClose,
}: ReviewFormProps) {
  const [rating, setRating] = useState(existingReview?.rating || 0);
  const [comment, setComment] = useState(existingReview?.comment || "");
  const isEdit = !!existingReview;

  const { mutate: submitCreate, isPending: createPending } = useAshMutation(
    () =>
      createReview({
        input: {
          orderId,
          rating,
          comment: comment || undefined,
        },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Review submitted!");
        onClose();
        router.reload();
      },
      onError: (err) => toast.error(err.message || "Failed to submit review"),
    },
  );

  const { mutate: submitUpdate, isPending: updatePending } = useAshMutation(
    () =>
      updateReview({
        identity: existingReview?.id || "",
        input: { rating, comment: comment || undefined },
        headers: buildCSRFHeaders(),
      }),
    {
      onSuccess: () => {
        toast.success("Review updated!");
        onClose();
        router.reload();
      },
      onError: (err) => toast.error(err.message || "Failed to update review"),
    },
  );

  const isPending = createPending || updatePending;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (rating === 0) {
      toast.error("Please select a rating");
      return;
    }
    if (isEdit) {
      submitUpdate();
    } else {
      submitCreate();
    }
  };

  return (
    <form
      onSubmit={handleSubmit}
      className="space-y-3 rounded-lg border border-surface-muted bg-surface-secondary p-4"
    >
      <div>
        <label className="mb-1.5 block text-sm font-medium text-content">
          {isEdit ? "Update your rating" : "Rate this seller"}
        </label>
        <StarRating value={rating} onChange={setRating} />
      </div>

      <div>
        <textarea
          value={comment}
          onChange={(e) => setComment(e.target.value)}
          placeholder="Share your experience (optional)"
          rows={3}
          className="w-full resize-none rounded-lg border border-default bg-surface px-3 py-2 text-sm text-content placeholder:text-content-placeholder outline-none focus:border-primary-600"
        />
      </div>

      <div className="flex items-center gap-2">
        <button
          type="submit"
          disabled={isPending || rating === 0}
          className="rounded-full bg-primary-600 px-5 py-2 text-sm font-medium text-white hover:bg-primary-700 disabled:opacity-50"
        >
          {isPending
            ? "Submitting..."
            : isEdit
              ? "Update Review"
              : "Submit Review"}
        </button>
        <button
          type="button"
          onClick={onClose}
          className="rounded-full border border-default px-5 py-2 text-sm font-medium text-content-secondary hover:bg-surface-muted"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
