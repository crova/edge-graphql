defmodule EdgeGraphql.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      EdgeGraphqlWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: EdgeGraphql.PubSub},
      # Start the Endpoint (http/https)
      EdgeGraphqlWeb.Endpoint,
      # Start Cache
      {Cachex, name: :graphql}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EdgeGraphql.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    EdgeGraphqlWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
