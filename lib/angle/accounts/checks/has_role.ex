defmodule Angle.Accounts.Checks.HasRole do
  @moduledoc """
  Policy check to verify if an actor has a specific role.
  """

  use Ash.Policy.SimpleCheck

  @impl true
  def match?(actor, context, opts) do
    required_roles =
      case opts[:role] do
        role when is_binary(role) -> [role]
        roles when is_list(roles) -> roles
        _ -> []
      end

    case actor do
      %{user_roles: user_roles} when is_list(user_roles) ->
        actor_roles = Enum.map(user_roles, fn ur -> ur.role.name end)
        Enum.any?(required_roles, fn role -> role in actor_roles end)

      %{id: user_id} when not is_nil(user_id) ->
        # Need to load user roles if not preloaded
        case Ash.load(actor, [:user_roles], domain: Angle.Accounts) do
          {:ok, loaded_actor} ->
            match?(loaded_actor, context, opts)

          _ ->
            false
        end

      _ ->
        false
    end
  end

  @impl true
  def describe(opts) do
    case opts[:role] do
      role when is_binary(role) -> "has role: #{role}"
      roles when is_list(roles) -> "has any role: #{Enum.join(roles, ", ")}"
      _ -> "has required role"
    end
  end
end
