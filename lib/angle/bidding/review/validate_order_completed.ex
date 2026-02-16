defmodule Angle.Bidding.Review.ValidateOrderCompleted do
  @moduledoc "Validates that the order is completed before allowing a review."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, review ->
      order =
        Angle.Bidding.Order
        |> Ash.get!(review.order_id, authorize?: false)

      if order.status == :completed do
        {:ok, review}
      else
        {:error,
         Ash.Error.Changes.InvalidAttribute.exception(
           field: :order_id,
           message: "Order must be completed before leaving a review"
         )}
      end
    end)
  end
end
