defmodule Angle.Bidding.Bid.BidType do
  use Ash.Type.Enum, values: [:auto, :proxy, :manual]
end
