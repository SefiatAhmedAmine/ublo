import Config

if config_env() != :test do
  if api_key = System.get_env("PENNYLANE_API_KEY") do
    config :ublo_app, :pennylane_api_key, api_key
  end
end
