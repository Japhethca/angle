defmodule Angle.Bidding.Review.ValidateOrderEligibility do
  @moduledoc "Validates that the order is completed and within the 30-day review window."
  use Ash.Resource.Change

  @review_window_days 30

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, review ->
      case Ash.get(Angle.Bidding.Order, review.order_id, authorize?: false) do
        {:ok, order} ->
          cond do
            order.status != :completed ->
              {:error,
               Ash.Error.Changes.InvalidAttribute.exception(
                 field: :order_id,
                 message: "Order must be completed before leaving a review"
               )}

            not within_review_window?(order) ->
              {:error,
               Ash.Error.Changes.InvalidAttribute.exception(
                 field: :order_id,
                 message: "Review window has expired (30 days after order completion)"
               )}

            true ->
              {:ok, review}
          end

        {:error, _} ->
          {:error,
           Ash.Error.Changes.InvalidAttribute.exception(
             field: :order_id,
             message: "Order not found"
           )}
      end
    end)
  end

  defp within_review_window?(order) do
    cutoff = DateTime.add(order.completed_at, @review_window_days * 24 * 3600)
    DateTime.compare(DateTime.utc_now(), cutoff) == :lt
  end
end
