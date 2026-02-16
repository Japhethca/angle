defmodule Angle.Bidding.Order.OrderStatus do
  use Ash.Type.Enum, values: ~w(payment_pending paid dispatched completed cancelled)a
end
