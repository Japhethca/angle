defmodule AngleWeb.Plugs.Auth do
  @moduledoc """
  Authentication plugs for protecting routes and loading current user.
  """

  import Plug.Conn
  import Phoenix.Controller
  import Inertia.Controller
  alias Angle.Accounts

  # Import verified routes for ~p sigil
  use Phoenix.VerifiedRoutes,
    endpoint: AngleWeb.Endpoint,
    router: AngleWeb.Router,
    statics: AngleWeb.static_paths()

  @doc """
  Ensures user is authenticated, redirects to login if not.
  Saves the requested path to session so the user can be returned after login.
  """
  def ensure_authenticated(conn, _opts) do
    case get_current_user_id(conn) do
      nil ->
        return_to = return_to_path(conn)

        conn
        |> put_session(:return_to, return_to)
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: ~p"/auth/login")
        |> halt()

      user_id ->
        assign(conn, :current_user_id, user_id)
    end
  end

  @doc """
  Pops the return-to URL from session, returning `{conn, url}`.
  Falls back to the given `fallback` path if none is stored or the stored path is invalid.
  """
  def pop_return_to(conn, fallback) do
    return_to = get_session(conn, :return_to)
    conn = delete_session(conn, :return_to)

    url =
      if is_binary(return_to) and valid_return_to?(return_to) do
        return_to
      else
        fallback
      end

    {conn, url}
  end

  @doc """
  Validates that a return-to path is a safe relative path.
  Must start with `/` but not `//` (prevents open redirect).
  """
  def valid_return_to?("/" <> rest) do
    not String.starts_with?(rest, "/")
  end

  def valid_return_to?(_), do: false

  defp return_to_path(conn) do
    case conn.query_string do
      "" -> conn.request_path
      qs -> "#{conn.request_path}?#{qs}"
    end
  end

  @doc """
  Loads current user and assigns to conn. Sets nil if not authenticated.
  """
  def load_current_user(conn, _opts) do
    # Try to get user via JWT token first, then fall back to user ID
    auth_token = get_session(conn, :auth_token)

    if auth_token != nil do
      case Accounts.User.get_by_subject(%{subject: auth_token}) do
        {:ok, user} ->
          # Load user with roles and permissions
          user = user |> Ash.load!([:active_roles, :roles], domain: Accounts, authorize?: false)
          user_permissions = get_user_permissions(user)

          conn
          |> Ash.PlugHelpers.set_actor(user)
          |> assign(:current_user, user)
          |> assign_prop(:auth, %{
            user: %{
              id: user.id,
              email: user.email,
              confirmed_at: user.confirmed_at,
              roles: user.active_roles || [],
              permissions: user_permissions
            },
            authenticated: true
          })

        {:error, _error} ->
          # Token might be expired, clear session and try user ID fallback
          user_id = get_current_user_id(conn)
          load_user_by_id(conn, user_id)
      end
    else
      # Fall back to user ID method
      user_id = get_current_user_id(conn)
      load_user_by_id(conn, user_id)
    end
  end

  # Helper function for loading by user ID (kept for backwards compatibility)
  defp load_user_by_id(conn, user_id) do
    case user_id do
      nil ->
        conn
        |> assign(:current_user, nil)
        |> assign_prop(:auth, %{
          user: nil,
          authenticated: false
        })

      user_id ->
        case Ash.get(Accounts.User, user_id, domain: Accounts, authorize?: false) do
          {:ok, user} ->
            # Load user with roles and permissions
            user =
              case Ash.load(user, [:active_roles, :roles], domain: Accounts) do
                {:ok, loaded_user} -> loaded_user
                # Fall back to user without roles if loading fails
                {:error, _} -> user
              end

            # Get user's permissions through their roles
            user_permissions = get_user_permissions(user)

            conn
            |> Ash.PlugHelpers.set_actor(user)
            |> assign(:current_user, user)
            |> assign_prop(:auth, %{
              user: %{
                id: user.id,
                email: user.email,
                confirmed_at: user.confirmed_at,
                roles: user.active_roles || [],
                permissions: user_permissions
              },
              authenticated: true
            })

          {:error, _error} ->
            conn
            |> clear_session()
            |> assign(:current_user, nil)
            |> assign_prop(:auth, %{
              user: nil,
              authenticated: false
            })
        end
    end
  end

  @doc """
  Validates JWT token for API requests.
  """
  def validate_api_token(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user} <- Accounts.User.get_by_subject(%{subject: token}) do
      assign(conn, :current_user, user)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid or missing authentication token"})
        |> halt()
    end
  end

  # Private helper
  defp get_current_user_id(conn) do
    get_session(conn, :current_user_id)
  end

  # Get all permissions for a user through their roles
  defp get_user_permissions(user) do
    user
    |> Ash.load!([roles: :permissions], domain: Accounts, authorize?: false)
    |> Map.get(:roles, [])
    |> Enum.flat_map(fn role -> role.permissions end)
    |> Enum.map(& &1.name)
    |> Enum.uniq()
  end
end
