defmodule AngleWeb.AshTypescriptRpcController do
  use AngleWeb, :controller

  def run(conn, params) do
    result = AshTypescript.Rpc.run_action(:angle, conn, params)
    json(conn, result)
  end

  def validate(conn, params) do
    result = AshTypescript.Rpc.validate_action(:angle, conn, params)
    json(conn, result)
  end
end
