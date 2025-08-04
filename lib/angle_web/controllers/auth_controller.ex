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
    # Extract user ID from JWT token subject
    with {:ok, %{"sub" => subject}} <- decode_jwt_payload(token),
         {:ok, user_id} <- extract_user_id_from_subject(subject),
         {:ok, user} <- Ash.get(Angle.Accounts.User, user_id, domain: Angle.Accounts),
         {:ok, confirmed_user} <- Ash.update(user, %{confirm: token}, 
                                           action: :confirm, 
                                           domain: Angle.Accounts, 
                                           authorize?: false) do
      # Successfully confirmed - log in the user
      conn
      |> put_session(:current_user_id, confirmed_user.id)
      |> put_flash(:info, "Your account has been confirmed successfully! Welcome!")
      |> redirect(to: ~p"/dashboard")
    else
      {:error, :invalid_token} ->
        render_confirmation_error(conn, "Invalid confirmation link")
        
      {:error, :expired_token} ->
        render_confirmation_error(conn, "Confirmation link has expired")
        
      {:error, %Ash.Error.Invalid{}} ->
        render_confirmation_error(conn, "Invalid or expired confirmation link")
        
      {:error, _error} ->
        render_confirmation_error(conn, "Invalid or expired confirmation link")
        
      _ ->
        render_confirmation_error(conn, "An error occurred during confirmation")
    end
  end

  def confirm_new_user(conn, _params) do
    render_confirmation_error(conn, "Invalid confirmation link")
  end

  # Helper function to decode JWT token payload
  defp decode_jwt_payload(token) do
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        try do
          # Add padding if needed
          padded_payload = payload <> String.duplicate("=", rem(4 - rem(String.length(payload), 4), 4))
          decoded = Base.decode64!(padded_payload)
          {:ok, Jason.decode!(decoded)}
        rescue
          _ -> {:error, :invalid_token}
        end
      _ ->
        {:error, :invalid_token}
    end
  end

  # Helper function to extract user ID from JWT subject
  defp extract_user_id_from_subject("user?id=" <> user_id), do: {:ok, user_id}
  defp extract_user_id_from_subject(_), do: {:error, :invalid_token}

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
        errors
        |> Enum.map(fn error ->
          case error do
            %Ash.Error.Changes.InvalidAttribute{field: field, message: message} ->
              "#{field}: #{message}"

            %Ash.Error.Query.InvalidArgument{field: field, message: message} ->
              "#{field}: #{message}"

            error ->
              Exception.message(error)
          end
        end)
        |> Enum.join(", ")

      error ->
        Exception.message(error)
    end
  end
end
