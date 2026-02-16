defmodule Angle.Bidding.Review.ValidateReviewWindow do
  @moduledoc "Validates that the review is within 30 days of order completion."
  use Ash.Resource.Change

  @review_window_days 30

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, review ->
      order =
        Angle.Bidding.Order
        |> Ash.get!(review.order_id, authorize?: false)

      cutoff = DateTime.add(order.completed_at, @review_window_days * 24 * 3600)

      if DateTime.compare(DateTime.utc_now(), cutoff) == :lt do
        {:ok, review}
      else
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :order_id,
           message: "Review window has expired (30 days after order completion)"
         )}
      end
    end)
  end
end
