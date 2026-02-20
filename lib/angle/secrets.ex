defmodule Angle.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Angle.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:angle, :token_signing_secret)
  end

  def secret_for(
        [:authentication, :strategies, :google, :client_id],
        Angle.Accounts.User,
        _opts,
        _context
      ) do
    get_env("GOOGLE_CLIENT_ID")
  end

  def secret_for(
        [:authentication, :strategies, :google, :client_secret],
        Angle.Accounts.User,
        _opts,
        _context
      ) do
    get_env("GOOGLE_CLIENT_SECRET")
  end

  def secret_for(
        [:authentication, :strategies, :google, :redirect_uri],
        Angle.Accounts.User,
        _opts,
        _context
      ) do
    case System.get_env("GOOGLE_OAUTH_REDIRECT_URI") do
      nil ->
        {:ok,
         Application.get_env(
           :angle,
           :google_oauth_redirect_uri,
           "http://localhost:4000/auth/user/google/callback"
         )}

      redirect_uri ->
        {:ok, redirect_uri}
    end
  end

  defp get_env(key) do
    case System.get_env(key) do
      nil -> :error
      value -> {:ok, value}
    end
  end
end
