defmodule Equiroute.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      EquirouteWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Equiroute.PubSub},
      # Start the Endpoint (http/https)
      EquirouteWeb.Endpoint,
      # Start a worker by calling: Equiroute.Worker.start_link(arg)
      # {Equiroute.Worker, arg}
      {Finch, name: MyFinch},
      {ConCache,
       [
         name: :equiroute_cache,
         ttl_check_interval: :timer.minutes(1),
         global_ttl: :timer.hours(12)
       ]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Equiroute.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EquirouteWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
