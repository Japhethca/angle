defmodule AngleWeb.StoreDashboardControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /store" do
    test "redirects to /store/listings", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store")

      assert redirected_to(conn) == ~p"/store/listings"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/store")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end

  describe "GET /store/listings" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/listings")

      assert html_response(conn, 200) =~ "store/listings"
    end
  end

  describe "GET /store/payments" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/payments")

      assert html_response(conn, 200) =~ "store/payments"
    end
  end

  describe "GET /store/profile" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/store/profile")

      assert html_response(conn, 200) =~ "store/profile"
    end
  end
end
