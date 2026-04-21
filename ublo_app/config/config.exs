import Config

# :ublo_app Repositories registration
config :ublo_app, ecto_repos: [MyApp.Repo]

# Import configuration files
import_config "#{config_env()}.exs"
