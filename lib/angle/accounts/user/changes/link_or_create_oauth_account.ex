defmodule Angle.Accounts.User.Changes.LinkOrCreateOAuthAccount do
  @moduledoc """
  Custom change for OAuth account linking.

  Handles linking Google OAuth to existing accounts or creating new ones.
  Key insight: AshAuthentication's confirmation hook only triggers if email is being changed.
  We use upsert_identity to match on email without setting it as a changed attribute.
  """
  use Ash.Resource.Change

  def change(changeset, _opts, _context) do
    user_info = Ash.Changeset.get_argument(changeset, :user_info)
    email = Map.get(user_info, "email")

    # Set email for upsert matching WITHOUT using change_attribute
    # This prevents AshAuthentication's hijack prevention from triggering
    changeset =
      changeset
      |> Ash.Changeset.force_change_attribute(:email, email)
      |> Ash.Changeset.force_change_attribute(:full_name, Map.get(user_info, "name"))
      |> Ash.Changeset.force_change_attribute(:confirmed_at, DateTime.utc_now())

    # Add after_action to confirm existing unconfirmed users via direct DB update
    Ash.Changeset.after_action(changeset, fn _changeset, user ->
      # If user is still unconfirmed after upsert (means upsert_fields was empty),
      # confirm them via direct DB update
      if is_nil(user.confirmed_at) do
        import Ecto.Query

        Angle.Repo.update_all(
          from(u in "users", where: u.id == ^user.id),
          set: [confirmed_at: DateTime.utc_now()]
        )

        {:ok, Ash.get!(Angle.Accounts.User, user.id, authorize?: false)}
      else
        {:ok, user}
      end
    end)
  end
end
