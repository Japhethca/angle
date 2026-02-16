defmodule Angle.Bidding.Order.OrderStatus do
  @moduledoc "Enum representing the lifecycle status of an order."

  # `cancelled` is reserved for future use (e.g. buyer/seller cancellation flow)
  use Ash.Type.Enum, values: ~w(payment_pending paid dispatched completed cancelled)a
end
