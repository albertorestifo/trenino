# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :trenino,
  ecto_repos: [Trenino.Repo],
  generators: [timestamp_type: :utc_datetime]

# Semver requirement that incoming firmware releases must satisfy.
# Releases outside this range are shown but cannot be installed.
# nil = no restriction (any parseable version compatible). Set per
# release line, e.g. ">= 1.0.0 and < 2.0.0" before a breaking firmware
# version ships.
config :trenino, :firmware_version_requirement, nil

# Configures the endpoint
config :trenino, TreninoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TreninoWeb.ErrorHTML, json: TreninoWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Trenino.PubSub,
  live_view: [signing_salt: "zLxA4/mQ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  trenino: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  trenino: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Sentry error tracking (Better Stack)
# DSN is set at runtime via SENTRY_DSN env var; Sentry is inactive without it.
config :sentry,
  environment_name: config_env(),
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
