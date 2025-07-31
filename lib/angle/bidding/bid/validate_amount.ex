defmodule Angle.Bidding.Bid.ValidateAmount do
  use Ash.Resource.Validation

  def validate(%{amount: amount}) do
    if amount > 0 do
      :ok
    else
      {:error, "Bid amount must be greater than zero"}
    end
  end
end
