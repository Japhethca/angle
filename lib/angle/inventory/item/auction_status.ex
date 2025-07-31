defmodule Angle.Inventory.Item.ItemStatus do
  use Ash.Type.Enum, values: ~w(pending scheduled active paused ended sold cancelled)a
end
