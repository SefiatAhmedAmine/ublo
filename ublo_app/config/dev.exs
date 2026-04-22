import Config

# Optional: set PENNYLANE_API_KEY in the environment for real calls; placeholder otherwise.
config :ublo_app, :pennylane_api_key, "dev-placeholder-not-for-production"

config :ublo_app, MyApp.Repo,
  database: "ublo_db",
  hostname: "localhost",
  password: "root",
  username: "postgres"
