defmodule AngleWeb.AuthController do
  use AngleWeb, :controller

  def login(conn, _params) do
    render_inertia(conn, "auth/login")
  end

  def do_login(conn, %{"email" => email, "password" => password}) do
    require Logger

    case Angle.Accounts.User.sign_in_with_password(%{email: email, password: password}) do
      {:ok, %{user: user, metadata: %{token: token}}} ->
        Logger.error("DEBUG AUTH: Login successful with token, user ID: #{inspect(user.id)}")

        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:auth_token, token)
        |> put_flash(:info, "Successfully signed in!")
        |> redirect(to: ~p"/")

      {:ok, user} ->
        Logger.error("DEBUG AUTH: Login successful without token, user ID: #{inspect(user.id)}")

        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(:info, "Successfully signed in!")
        |> redirect(to: ~p"/")

      {:error, err} ->
        Logger.error("DEBUG AUTH: Login failed: #{inspect(err)}")

        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/auth/login")
    end
  end

  def register(conn, _params) do
    render_inertia(conn, "auth/register")
  end

  def do_register(conn, %{
        "email" => email,
        "password" => password,
        "password_confirmation" => password_confirmation
      }) do
    case Angle.Accounts.User.register_with_password(%{
           email: email,
           password: password,
           password_confirmation: password_confirmation
         }) do
      {:ok, %{user: user, metadata: %{token: token}}} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:auth_token, token)
        |> put_flash(
          :info,
          "Account created successfully! Please check your email to confirm your account."
        )
        |> redirect(to: ~p"/")

      {:ok, user} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_flash(
          :info,
          "Account created successfully! Please check your email to confirm your account."
        )
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_flash(:error, "Registration failed: #{errors}")
        |> redirect(to: ~p"/auth/register")
    end
  end

  def forgot_password(conn, _params) do
    render_inertia(conn, "auth/forgot-password")
  end

  def do_forgot_password(conn, %{"email" => email}) do
    # This action always succeeds to prevent email enumeration
    Angle.Accounts.User.request_password_reset_with_password(%{email: email})

    conn
    |> put_flash(
      :info,
      "If an account with that email exists, you will receive password reset instructions."
    )
    |> redirect(to: ~p"/auth/login")
  end

  def reset_password(conn, %{"token" => token}) do
    render_inertia(conn, "auth/reset-password", %{token: token})
  end

  def reset_password(conn, _params) do
    conn
    |> put_flash(:error, "Invalid reset link")
    |> redirect(to: ~p"/auth/forgot-password")
  end

  def do_reset_password(conn, %{
        "reset_token" => token,
        "password" => password,
        "password_confirmation" => password_confirmation
      }) do
    case Angle.Accounts.User.reset_password_with_token(%{
           reset_token: token,
           password: password,
           password_confirmation: password_confirmation
         }) do
      {:ok, %{user: user, metadata: %{token: auth_token}}} ->
        conn
        |> put_session(:current_user_id, user.id)
        |> put_session(:auth_token, auth_token)
        |> put_flash(:info, "Password reset successfully!")
        |> redirect(to: ~p"/")

      {:error, changeset} ->
        errors = format_changeset_errors(changeset)

        conn
        |> put_flash(:error, "Password reset failed: #{errors}")
        |> redirect(to: ~p"/auth/forgot-password")
    end
  end

  def confirm_new_user(conn, %{"token" => token}) do
    # Check if user is already logged in
    case conn.assigns[:current_user] do
      %{confirmed_at: confirmed_at} when not is_nil(confirmed_at) ->
        # User is already logged in and confirmed
        conn
        |> put_flash(:info, "Your account is already confirmed!")
        |> redirect(to: ~p"/dashboard")

      _ ->
        # Proceed with confirmation process
        confirm_user_with_token(conn, token)
    end
  end

  def confirm_new_user(conn, _params) do
    render_confirmation_error(conn, "Invalid confirmation link")
  end

  # Helper function to handle the actual confirmation process
  defp confirm_user_with_token(conn, token) do
    with {:ok, claims} <- verify_confirmation_token(token),
         {:ok, user_id} <- extract_user_id_from_claims(claims),
         {:ok, user} <- Ash.get(Angle.Accounts.User, user_id, domain: Angle.Accounts),
         {:ok, confirmed_user} <- confirm_user_account(user, token) do
      # Successfully confirmed - log in the user and generate new session
      conn
      |> put_session(:current_user_id, confirmed_user.id)
      |> put_flash(:info, "Your account has been confirmed successfully! Welcome!")
      |> redirect(to: ~p"/dashboard")
    else
      {:error, :invalid_token} ->
        render_confirmation_error(conn, "Invalid confirmation link")

      {:error, :expired_token} ->
        render_confirmation_error(conn, "Confirmation link has expired")

      {:error, :token_verification_failed} ->
        render_confirmation_error(conn, "Invalid confirmation link")

      {:error, :token_already_used} ->
        render_confirmation_error(conn, "This confirmation link has already been used")

      {:error, :confirmation_failed} ->
        render_confirmation_error(conn, "Account confirmation failed")

      {:error, %Ash.Error.Invalid{}} ->
        render_confirmation_error(conn, "Invalid or expired confirmation link")

      {:error, %Ash.Error.Query.NotFound{}} ->
        render_confirmation_error(conn, "User account not found")

      {:error, _error} ->
        render_confirmation_error(conn, "Invalid or expired confirmation link")

      _ ->
        render_confirmation_error(conn, "An error occurred during confirmation")
    end
  end

  # Helper function to verify confirmation token using AshAuthentication
  defp verify_confirmation_token(token) do
    # Use AshAuthentication's verify function for proper signature validation
    case AshAuthentication.Jwt.verify(token, Angle.Accounts.User) do
      {:ok, claims} when is_map(claims) ->
        validate_confirmation_claims(claims)

      {:error, :expired} ->
        {:error, :expired_token}

      {:error, _reason} ->
        {:error, :token_verification_failed}
    end
  end

  # Helper function to validate that claims are for confirmation
  defp validate_confirmation_claims(%{"act" => "confirm"} = claims), do: {:ok, claims}
  defp validate_confirmation_claims(_claims), do: {:error, :invalid_token}

  # Helper function to extract user ID from JWT claims
  defp extract_user_id_from_claims(%{"sub" => "user?id=" <> user_id}), do: {:ok, user_id}
  defp extract_user_id_from_claims(_), do: {:error, :invalid_token}

  # Helper function to confirm user account with better error handling
  defp confirm_user_account(user, token) do
    case Ash.update(user, %{confirm: token},
           action: :confirm,
           domain: Angle.Accounts,
           authorize?: false
         ) do
      {:ok, confirmed_user} ->
        {:ok, confirmed_user}

      {:error, %Ash.Error.Invalid{errors: errors}} ->
        # Handle specific validation errors
        case find_token_error(errors) do
          :token_already_used -> {:error, :token_already_used}
          :invalid_token -> {:error, :invalid_token}
          _ -> {:error, :confirmation_failed}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  # Helper function to find token-specific errors in Ash errors
  defp find_token_error(errors) when is_list(errors) do
    errors
    |> Enum.find_value(:confirmation_failed, fn error ->
      case error do
        %{message: message} when is_binary(message) ->
          cond do
            String.contains?(message, "already") -> :token_already_used
            String.contains?(message, "invalid") -> :invalid_token
            true -> nil
          end

        _ ->
          nil
      end
    end)
  end

  defp find_token_error(_), do: :confirmation_failed

  # Helper function to render confirmation errors
  defp render_confirmation_error(conn, message) do
    conn
    |> put_flash(:error, "#{message}. Please try registering again.")
    |> render_inertia("auth/confirm-new-user", %{
      error: true,
      message: message
    })
  end

  def logout(conn, _params) do
    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully!")
    |> redirect(to: ~p"/")
  end

  # Helper function to format changeset errors
  defp format_changeset_errors(changeset) do
    changeset
    |> Ash.Error.to_error_class()
    |> case do
      %Ash.Error.Invalid{errors: errors} ->
        Enum.map_join(errors, ", ", fn error ->
          case error do
            %Ash.Error.Changes.InvalidAttribute{field: field, message: message} ->
              "#{field}: #{message}"

            %Ash.Error.Query.InvalidArgument{field: field, message: message} ->
              "#{field}: #{message}"

            error ->
              Exception.message(error)
          end
        end)

      error ->
        Exception.message(error)
    end
  end
end
