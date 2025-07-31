defmodule Angle.Inventory.Item.PublicationStatus do
  use Ash.Type.Enum, values: ~w(draft pending published unpublished archived)a
end
