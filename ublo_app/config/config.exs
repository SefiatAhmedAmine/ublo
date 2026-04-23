import Config

# :ublo_app Repositories registration
config :ublo_app, ecto_repos: [MyApp.Repo]

# Oban configuration
config :ublo_app, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, invoices: 5],
  repo: MyApp.Repo

# Import configuration files
import_config "#{config_env()}.exs"
