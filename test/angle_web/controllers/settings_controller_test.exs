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
          phone_number: "08012345678",
          location: "Lagos, Nigeria"
        })

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

  describe "GET /settings/store" do
    test "renders settings/store page with store profile data", %{conn: conn} do
      user = create_user(%{email: "store@example.com"})

      _store_profile =
        create_store_profile(%{
          user_id: user.id,
          store_name: "Test Store",
          contact_phone: "08012345678",
          whatsapp_link: "wa.me/2348012345678",
          location: "Lagos",
          address: "9A, Bade drive, Lagos",
          delivery_preference: "seller_delivers"
        })

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/store")

      response = html_response(conn, 200)
      assert response =~ "settings/store"
      assert response =~ "Test Store"
      assert response =~ "08012345678"
      assert response =~ "Lagos"
    end

    test "renders settings/store page when user has no store profile", %{conn: conn} do
      user = create_user(%{email: "nostore@example.com"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/store")

      response = html_response(conn, 200)
      assert response =~ "settings/store"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/store")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /settings/security" do
    test "renders settings/security page for authenticated user", %{conn: conn} do
      user = create_user(%{email: "security@example.com"})

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/settings/security")

      response = html_response(conn, 200)
      assert response =~ "settings/security"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/settings/security")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
