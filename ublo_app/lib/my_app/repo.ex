defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :ublo_app,
    adapter: Ecto.Adapters.Postgres
end
