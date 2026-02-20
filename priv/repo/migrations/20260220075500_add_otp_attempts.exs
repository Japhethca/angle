defmodule Angle.Repo.Migrations.AddOtpAttempts do
  use Ecto.Migration

  def change do
    alter table(:user_verifications) do
      add :otp_attempts, :integer, default: 0, null: false
    end
  end
end
