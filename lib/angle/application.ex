defmodule Angle.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AngleWeb.Telemetry,
      Angle.Repo,
      {DNSCluster, query: Application.get_env(:angle, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:angle, :ash_domains),
         Application.fetch_env!(:angle, Oban)
       )},
      {Phoenix.PubSub, name: Angle.PubSub},
      # Start a worker by calling: Angle.Worker.start_link(arg)
      # {Angle.Worker, arg},
      # Start to serve requests, typically the last entry
      AngleWeb.Endpoint,
      {Absinthe.Subscription, AngleWeb.Endpoint},
      AshGraphql.Subscription.Batcher,
      {AshAuthentication.Supervisor, [otp_app: :angle]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Angle.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AngleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
