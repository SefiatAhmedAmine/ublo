import Config

# :ublo_app Repositories registration
config :ublo_app, ecto_repos: [MyApp.Repo]

# Oban configuration
config :ublo_app, Oban,
  engine: Oban.Engines.Basic,
  queues: [default: 10, invoices: 5],
  repo: MyApp.Repo

config :ublo_app,
  pennylane_client: MyApp.PennylaneClient,
  invoice_pdf_source: MyApp.LocalInvoicePDFSource,
  pennylane_e_invoices_import_url: "https://app.pennylane.com/api/external/v2/e-invoices/imports",
  pennylane_e_invoice_type: :customer

# Import configuration files
import_config "#{config_env()}.exs"
