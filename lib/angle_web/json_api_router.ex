defmodule AngleWeb.AshJsonApiRouter do
  use AshJsonApi.Router,
    domains: [Angle.Bidding, Angle.Catalog, Angle.Inventory],
    open_api: "/open_api"
end
