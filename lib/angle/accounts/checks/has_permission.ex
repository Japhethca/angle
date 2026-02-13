defmodule Angle.Accounts.Checks.HasPermission do
  @moduledoc """
  Policy check to verify if an actor has a specific permission via their roles.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, _context, opts) do
    required_permission = opts[:permission]

    case ensure_permissions_loaded(actor) do
      {:ok, loaded_actor} ->
        loaded_actor.roles
        |> Enum.flat_map(fn
          %{permissions: permissions} when is_list(permissions) -> permissions
          _ -> []
        end)
        |> Enum.any?(fn perm -> perm.name == required_permission end)

      _ ->
        false
    end
  end

  defp ensure_permissions_loaded(%{id: user_id} = actor) when not is_nil(user_id) do
    case actor do
      %{roles: roles} when is_list(roles) ->
        # Roles loaded — check if permissions are loaded on at least the first role
        if permissions_loaded?(roles) do
          {:ok, actor}
        else
          Ash.load(actor, [roles: :permissions], domain: Angle.Accounts, authorize?: false)
        end

      _ ->
        Ash.load(actor, [roles: :permissions], domain: Angle.Accounts, authorize?: false)
    end
  end

  defp ensure_permissions_loaded(_actor), do: :error

  defp permissions_loaded?([]), do: true

  defp permissions_loaded?([%{permissions: permissions} | _]) when is_list(permissions), do: true

  defp permissions_loaded?(_), do: false

  @impl true
  def describe(opts) do
    "has permission: #{opts[:permission]}"
  end
end
