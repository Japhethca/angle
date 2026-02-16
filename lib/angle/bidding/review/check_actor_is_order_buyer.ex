defmodule Angle.Bidding.Review.CheckActorIsOrderBuyer do
  @moduledoc "Checks that the actor is the buyer of the order being reviewed."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "actor is the buyer of the order"
  end

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: %Ash.Changeset{} = changeset}, _opts) do
    order_id = Ash.Changeset.get_attribute(changeset, :order_id)

    if order_id do
      case Ash.get(Angle.Bidding.Order, order_id, authorize?: false) do
        {:ok, order} -> {:ok, order.buyer_id == actor.id}
        {:error, _} -> {:ok, false}
      end
    else
      {:ok, false}
    end
  end

  def match?(_, _, _), do: {:ok, false}
end
