defmodule Angle.Bidding.Review.SetSellerFromOrder do
  @moduledoc "Sets the seller_id on the review from the associated order."
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      order_id = Ash.Changeset.get_attribute(changeset, :order_id)

      if order_id do
        order = Ash.get!(Angle.Bidding.Order, order_id, authorize?: false)
        Ash.Changeset.force_change_attribute(changeset, :seller_id, order.seller_id)
      else
        changeset
      end
    end)
  end
end
