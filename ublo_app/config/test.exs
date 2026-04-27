import Config

config :ublo_app, :pennylane_api_key, "test-placeholder-never-calls-real-api"
config :ublo_app, :pennylane_client, MyApp.PennylaneClientMock

config :ublo_app, MyApp.Repo,
  database: "ublo_test_db",
  hostname: "localhost",
  password: "root",
  username: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox

# Oban configuration for testing: manual mode means Oban will not run jobs automatically.
config :ublo_app, Oban, testing: :manual
