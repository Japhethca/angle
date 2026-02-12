defmodule AngleWeb.PageControllerTest do
  use AngleWeb.ConnCase

  test "GET / returns an Inertia response", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)
    assert response =~ ~s(id="app")
    assert response =~ ~s(data-page=)
  end
end
