defmodule MyApp.Repo.Migrations.UniqueInvoiceExportsAttempts do
  use Ecto.Migration

  def change do
    create unique_index(:invoice_exports, [:invoice_id, :attempts])
  end
end
