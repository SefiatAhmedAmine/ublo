import Config

config :ublo_app, MyApp.Repo,
  database: "ublo_test_db",
  hostname: "localhost",
  password: "root",
  username: "postgres",
  pool: Ecto.Adapters.SQL.Sandbox
