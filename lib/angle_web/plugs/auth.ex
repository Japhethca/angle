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
  """
  def ensure_authenticated(conn, _opts) do
    case get_current_user_id(conn) do
      nil ->
        conn
        |> put_flash(:error, "You must be logged in to access this page")
        |> redirect(to: ~p"/auth/login")
        |> halt()

      user_id ->
        assign(conn, :current_user_id, user_id)
    end
  end

  @doc """
  Loads current user and assigns to conn. Sets nil if not authenticated.
  """
  def load_current_user(conn, _opts) do
    require Logger

    # Try to get user via JWT token first, then fall back to user ID
    auth_token = get_session(conn, :auth_token)
    Logger.error("DEBUG AUTH: auth_token from session = #{inspect(auth_token != nil)}")

    cond do
      auth_token != nil ->
        Logger.error("DEBUG AUTH: Attempting to load user with JWT token")

        case Accounts.User.get_by_subject(%{subject: auth_token}) do
          {:ok, user} ->
            Logger.error("DEBUG AUTH: Successfully loaded user via token: #{user.email}")

            conn
            |> assign(:current_user, user)

          {:error, error} ->
            Logger.error("DEBUG AUTH: Failed to load user via token: #{inspect(error)}")
            # Token might be expired, clear session and try user ID fallback
            user_id = get_current_user_id(conn)
            load_user_by_id(conn, user_id)
        end

      true ->
        # Fall back to user ID method
        user_id = get_current_user_id(conn)
        Logger.error("DEBUG AUTH: No token, trying user_id = #{inspect(user_id)}")
        load_user_by_id(conn, user_id)
    end
  end

  # Helper function for loading by user ID (kept for backwards compatibility)
  defp load_user_by_id(conn, user_id) do
    require Logger

    case user_id do
      nil ->
        Logger.error("DEBUG AUTH: No user ID in session")
        assign(conn, :current_user, nil)

      user_id ->
        Logger.error("DEBUG AUTH: Attempting to load user with ID: #{inspect(user_id)}")

        case Ash.get(Accounts.User, user_id, domain: Accounts) do
          {:ok, user} ->
            Logger.error("DEBUG AUTH: Successfully loaded user: #{user.email}")

            conn
            |> assign(:current_user, user)
            |> assign_prop(:auth, %{
              user: %{id: user.id, email: user.email, confirmed_at: user.confirmed_at},
              authenticated: true
            })

          {:error, error} ->
            Logger.error("DEBUG AUTH: Failed to load user: #{inspect(error)}")

            conn
            |> clear_session()
            |> assign(:current_user, nil)
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
end
