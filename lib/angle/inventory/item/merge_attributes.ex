defmodule Angle.Inventory.Item.MergeAttributes do
  @moduledoc """
  Ash change that merges incoming attributes with existing ones.

  When the incoming map contains user-visible keys (no underscore prefix),
  all existing user-visible keys are replaced while system keys (underscore-
  prefixed like `_auctionDuration`) are preserved. This handles category
  changes in step 1 where old category attributes must be cleared.

  When only system keys are sent (steps 2/3), a simple merge preserves
  all existing keys.

  System keys are restricted to an allowlist to prevent arbitrary injection.
  """
  use Ash.Resource.Change

  @allowed_system_keys MapSet.new([
                         "_auctionDuration",
                         "_deliveryPreference",
                         "_customFeatures"
                       ])

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :attributes) do
      new_attrs =
        changeset
        |> Ash.Changeset.get_attribute(:attributes)
        |> reject_unknown_system_keys()

      existing = Map.get(changeset.data, :attributes) || %{}

      has_user_keys? =
        Enum.any?(new_attrs, fn {key, _val} -> not String.starts_with?(key, "_") end)

      merged =
        if has_user_keys? do
          # Replace user-visible attrs, preserve system fields from existing
          existing_system =
            Map.filter(existing, fn {key, _val} -> String.starts_with?(key, "_") end)

          Map.merge(existing_system, new_attrs)
        else
          Map.merge(existing, new_attrs)
        end

      Ash.Changeset.force_change_attribute(changeset, :attributes, merged)
    else
      changeset
    end
  end

  defp reject_unknown_system_keys(attrs) do
    Map.reject(attrs, fn {key, _val} ->
      String.starts_with?(key, "_") and key not in @allowed_system_keys
    end)
  end
end
