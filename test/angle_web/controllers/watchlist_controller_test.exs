defmodule AngleWeb.WatchlistControllerTest do
  use AngleWeb.ConnCase, async: true

  describe "GET /watchlist" do
    test "returns 200 for authenticated user", %{conn: conn} do
      user = create_user()

      conn =
        conn
        |> init_test_session(%{current_user_id: user.id})
        |> get(~p"/watchlist")

      assert html_response(conn, 200) =~ "watchlist"
    end

    test "redirects to login when not authenticated", %{conn: conn} do
      conn = get(conn, ~p"/watchlist")
      assert redirected_to(conn) == ~p"/auth/login"
    end
  end
end
