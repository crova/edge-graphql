# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :edge_graphql, EdgeGraphqlWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "SeyW2TnqPoaADGzhhT0H3AN2hvy63cFX6rMknDIX+IpInqogxnzFsXTMOSnMbPNc",
  render_errors: [view: EdgeGraphqlWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: EdgeGraphql.PubSub,
  live_view: [signing_salt: "LmrNVNqW"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
