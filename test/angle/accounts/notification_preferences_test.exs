defmodule Angle.Accounts.NotificationPreferencesTest do
  use Angle.DataCase, async: true

  describe "default notification preferences" do
    test "new user has all 9 notification preferences defaulting to true" do
      user = create_user()

      prefs = user.notification_preferences

      # Push notifications
      assert prefs.push_bidding == true
      assert prefs.push_watchlist == true
      assert prefs.push_payments == true
      assert prefs.push_communication == true

      # Email notifications
      assert prefs.email_communication == true
      assert prefs.email_marketing == true
      assert prefs.email_security == true

      # SMS notifications
      assert prefs.sms_communication == true
      assert prefs.sms_security == true
    end
  end

  describe "update_notification_preferences" do
    test "can toggle individual preferences" do
      user = create_user()

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{notification_preferences: %{push_bidding: false, email_marketing: false}},
          authorize?: false
        )
        |> Ash.update()

      # Toggled preferences should be false
      assert updated.notification_preferences.push_bidding == false
      assert updated.notification_preferences.email_marketing == false

      # All other preferences should remain true
      assert updated.notification_preferences.push_watchlist == true
      assert updated.notification_preferences.push_payments == true
      assert updated.notification_preferences.push_communication == true
      assert updated.notification_preferences.email_communication == true
      assert updated.notification_preferences.email_security == true
      assert updated.notification_preferences.sms_communication == true
      assert updated.notification_preferences.sms_security == true
    end

    test "can disable all preferences at once" do
      user = create_user()

      all_disabled = %{
        push_bidding: false,
        push_watchlist: false,
        push_payments: false,
        push_communication: false,
        email_communication: false,
        email_marketing: false,
        email_security: false,
        sms_communication: false,
        sms_security: false
      }

      {:ok, updated} =
        user
        |> Ash.Changeset.for_update(
          :update_notification_preferences,
          %{notification_preferences: all_disabled},
          authorize?: false
        )
        |> Ash.update()

      prefs = updated.notification_preferences

      assert prefs.push_bidding == false
      assert prefs.push_watchlist == false
      assert prefs.push_payments == false
      assert prefs.push_communication == false
      assert prefs.email_communication == false
      assert prefs.email_marketing == false
      assert prefs.email_security == false
      assert prefs.sms_communication == false
      assert prefs.sms_security == false
    end
  end
end
