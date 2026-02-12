defmodule AngleWeb.AuthControllerTest do
  use AngleWeb.ConnCase, async: true

  alias Angle.Factory

  describe "GET /auth/verify-account" do
    @tag :skip_until_ssr_built
    test "renders verify page when verify_user_id in session", %{conn: conn} do
      user = Factory.create_user()

      conn =
        conn
        |> init_test_session(%{verify_user_id: user.id, verify_email: "test@example.com"})
        |> get("/auth/verify-account")

      assert conn.status == 200
    end

    test "redirects to register when no verify_user_id in session", %{conn: conn} do
      conn = get(conn, "/auth/verify-account")
      assert redirected_to(conn) == "/auth/register"
    end
  end

  describe "POST /auth/verify-account" do
    test "rejects invalid OTP code", %{conn: conn} do
      user = Factory.create_user()
      _otp = Angle.Accounts.OtpHelper.create_otp(user.id, "fake_token")

      conn =
        conn
        |> init_test_session(%{verify_user_id: user.id, verify_email: to_string(user.email)})
        |> post("/auth/verify-account", %{"code" => "000000"})

      assert redirected_to(conn) == "/auth/verify-account"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid"
    end

    test "redirects to register when no session", %{conn: conn} do
      conn = post(conn, "/auth/verify-account", %{"code" => "123456"})
      assert redirected_to(conn) == "/auth/register"
    end
  end

  describe "POST /auth/resend-otp" do
    test "redirects to verify-account with flash", %{conn: conn} do
      user = Factory.create_user()

      conn =
        conn
        |> init_test_session(%{verify_user_id: user.id, verify_email: to_string(user.email)})
        |> post("/auth/resend-otp")

      assert redirected_to(conn) == "/auth/verify-account"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "verification code"
    end

    test "redirects to register when no session", %{conn: conn} do
      conn = post(conn, "/auth/resend-otp")
      assert redirected_to(conn) == "/auth/register"
    end
  end
end
