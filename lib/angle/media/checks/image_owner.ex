defmodule Angle.Media.Checks.ImageOwner do
  @moduledoc "Checks that the actor owns the image being modified."
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts) do
    "actor owns the image"
  end

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(
        actor,
        %{subject: %Ash.Changeset{data: %{owner_type: owner_type, owner_id: owner_id}}},
        _opts
      ) do
    check_ownership(actor, owner_type, owner_id)
  end

  def match?(_, _, _), do: {:ok, false}

  defp check_ownership(actor, :user_avatar, owner_id) do
    {:ok, actor.id == owner_id}
  end

  defp check_ownership(actor, :item, owner_id) do
    case Ash.get(Angle.Inventory.Item, owner_id, authorize?: false) do
      {:ok, item} -> {:ok, item.created_by_id == actor.id}
      {:error, _} -> {:ok, false}
    end
  end

  defp check_ownership(actor, :store_logo, owner_id) do
    case Ash.get(Angle.Accounts.StoreProfile, owner_id, authorize?: false) do
      {:ok, store} -> {:ok, store.user_id == actor.id}
      {:error, _} -> {:ok, false}
    end
  end

  defp check_ownership(_, _, _), do: {:ok, false}
end
