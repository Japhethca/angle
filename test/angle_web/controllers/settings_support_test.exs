defmodule AngleWeb.SettingsSupportTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /settings/support" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/support")

      assert html_response(conn, 200) =~ "settings/support"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/support")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
