defmodule AngleWeb.PageController do
  use AngleWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
