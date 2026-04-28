defmodule MyApp.Repo.Migrations.CreateInvoiceExports do
  use Ecto.Migration

  def change do
    create table(:invoice_exports) do
      add :invoice_id, references(:invoices, on_delete: :delete_all), null: false
      add :foreign_id, :string
      add :status, :string, null: false
      add :attempts, :integer, null: false
      add :error, :string
      add :exported_at, :utc_datetime

      timestamps()
    end

    create index(:invoice_exports, [:invoice_id])
  end
end
