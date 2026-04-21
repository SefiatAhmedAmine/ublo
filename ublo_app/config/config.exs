import Config

# :ublo_app Repositories registration
config :ublo_app, ecto_repos: [MyApp.Repo]

# Repo connection configuration
config :ublo_app, MyApp.Repo,
  database: "ublo_db",
  hostname: "localhost",
  password: "root",
  username: "postgres"
