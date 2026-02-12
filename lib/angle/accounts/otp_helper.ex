defmodule Angle.Accounts.OtpHelper do
  @moduledoc """
  Helper module for generating, storing, and verifying OTP codes.
  """

  require Ash.Query
  import Ash.Expr

  @otp_expiry_minutes 10
  @otp_cooldown_seconds 60
  @otp_max_resends 5
  @otp_rate_limit_window_minutes 15

  @doc """
  Generates a random 6-digit OTP code string.
  """
  def generate_code do
    :rand.uniform(999_999)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  @doc """
  Checks whether a new OTP can be sent for the given user and purpose.
  Returns `:ok` if allowed, or `{:error, reason}` if throttled.
  """
  def check_throttle(user_id, purpose \\ "confirm_new_user") do
    now = DateTime.utc_now()

    recent_otp =
      Angle.Accounts.Otp
      |> Ash.Query.filter(expr(user_id == ^user_id and purpose == ^purpose))
      |> Ash.Query.sort(created_at: :desc)
      |> Ash.Query.limit(1)
      |> Ash.read!(domain: Angle.Accounts, authorize?: false)

    case recent_otp do
      [latest] ->
        seconds_since = DateTime.diff(now, latest.created_at, :second)

        if seconds_since < @otp_cooldown_seconds do
          {:error, {:throttled, @otp_cooldown_seconds - seconds_since}}
        else
          check_rate_limit(user_id, purpose, now)
        end

      [] ->
        :ok
    end
  end

  defp check_rate_limit(user_id, purpose, now) do
    window_start = DateTime.add(now, -@otp_rate_limit_window_minutes, :minute)

    count =
      Angle.Accounts.Otp
      |> Ash.Query.filter(
        expr(user_id == ^user_id and purpose == ^purpose and created_at >= ^window_start)
      )
      |> Ash.read!(domain: Angle.Accounts, authorize?: false)
      |> length()

    if count >= @otp_max_resends do
      {:error, :rate_limit_exceeded}
    else
      :ok
    end
  end

  @doc """
  Creates an OTP record for a user with the given confirmation token.
  Invalidates any existing unused OTPs for the same user and purpose.

  Note: This function does not enforce throttling. Call `check_throttle/2`
  before calling this function at the controller level.
  """
  def create_otp(user_id, confirmation_token, purpose \\ "confirm_new_user") do
    invalidate_codes(user_id, purpose)

    Ash.create!(
      Angle.Accounts.Otp,
      %{
        code: generate_code(),
        user_id: user_id,
        confirmation_token: confirmation_token,
        purpose: purpose,
        expires_at: DateTime.add(DateTime.utc_now(), @otp_expiry_minutes, :minute)
      },
      authorize?: false
    )
  end

  @doc """
  Verifies an OTP code for a user. Returns {:ok, otp} if valid, {:error, reason} otherwise.
  Marks the OTP as used on success.
  """
  def verify_code(code, user_id, purpose \\ "confirm_new_user") do
    now = DateTime.utc_now()

    case Ash.Query.filter(
           Angle.Accounts.Otp,
           expr(
             code == ^code and user_id == ^user_id and purpose == ^purpose and
               is_nil(used_at) and expires_at > ^now
           )
         )
         |> Ash.Query.sort(created_at: :desc)
         |> Ash.Query.limit(1)
         |> Ash.read(domain: Angle.Accounts, authorize?: false) do
      {:ok, [otp]} ->
        Ash.update!(otp, %{}, action: :mark_used, domain: Angle.Accounts, authorize?: false)
        {:ok, otp}

      {:ok, []} ->
        {:error, :invalid_code}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Invalidates all unused OTP codes for a user and purpose.
  """
  def invalidate_codes(user_id, purpose \\ "confirm_new_user") do
    Ash.Query.filter(
      Angle.Accounts.Otp,
      expr(user_id == ^user_id and purpose == ^purpose and is_nil(used_at))
    )
    |> Ash.read!(domain: Angle.Accounts, authorize?: false)
    |> Enum.each(fn otp ->
      Ash.update!(otp, %{}, action: :mark_used, domain: Angle.Accounts, authorize?: false)
    end)
  end
end
