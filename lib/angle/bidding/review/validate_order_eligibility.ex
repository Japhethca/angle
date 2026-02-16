defmodule Angle.Bidding.Review.ValidateOrderEligibility do
  @moduledoc "Validates order is completed and within 30-day window, and sets seller_id."
  use Ash.Resource.Change

  @review_window_days 30

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      order_id = Ash.Changeset.get_attribute(changeset, :order_id)

      case Ash.get(Angle.Bidding.Order, order_id, authorize?: false) do
        {:ok, order} ->
          cond do
            order.status != :completed ->
              Ash.Changeset.add_error(changeset,
                field: :order_id,
                message: "Order must be completed before leaving a review"
              )

            not within_review_window?(order) ->
              Ash.Changeset.add_error(changeset,
                field: :order_id,
                message: "Review window has expired (30 days after order completion)"
              )

            true ->
              Ash.Changeset.force_change_attribute(changeset, :seller_id, order.seller_id)
          end

        {:error, _} ->
          Ash.Changeset.add_error(changeset,
            field: :order_id,
            message: "Order not found"
          )
      end
    end)
  end

  defp within_review_window?(order) do
    cutoff = DateTime.add(order.completed_at, @review_window_days * 24 * 3600)
    DateTime.compare(DateTime.utc_now(), cutoff) == :lt
  end
end
