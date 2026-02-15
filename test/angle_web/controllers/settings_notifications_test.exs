defmodule AngleWeb.SettingsNotificationsTest do
  use AngleWeb.ConnCase

  describe "GET /settings/notifications" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/notifications")

      assert html_response(conn, 200) =~ "settings/notifications"
    end
  end
end
