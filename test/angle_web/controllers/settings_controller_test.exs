defmodule AngleWeb.SettingsControllerTest do
  use AngleWeb.ConnCase

  describe "GET /settings (index)" do
    test "renders settings/index page for authenticated user", %{conn: conn} do
      user = create_user(%{full_name: "Test User", email: "settings@example.com"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings")

      response = html_response(conn, 200)
      assert response =~ "settings/index"
      assert response =~ "Test User"
      assert response =~ "settings@example.com"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /settings/account" do
    test "renders settings/account page with user profile data", %{conn: conn} do
      user =
        create_user(%{
          full_name: "Account User",
          email: "account@example.com",
          phone_number: "08012345678"
        })

      # Set location directly since factory doesn't support it
      user
      |> Ecto.Changeset.change(%{location: "Lagos, Nigeria"})
      |> Angle.Repo.update!()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/account")

      response = html_response(conn, 200)
      assert response =~ "settings/account"
      assert response =~ "Account User"
      assert response =~ "account@example.com"
      assert response =~ "08012345678"
      assert response =~ "Lagos, Nigeria"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/account")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
