defmodule Angle.Inventory.Item.MergeAttributes do
  @moduledoc """
  Ash change that shallow-merges incoming attributes with existing ones
  instead of replacing the entire map. Only runs when attributes
  is actually being changed, to avoid unnecessary DB writes.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :attributes) do
      new_attrs = Ash.Changeset.get_attribute(changeset, :attributes)
      existing = Map.get(changeset.data, :attributes) || %{}
      merged = Map.merge(existing, new_attrs)
      Ash.Changeset.force_change_attribute(changeset, :attributes, merged)
    else
      changeset
    end
  end
end
