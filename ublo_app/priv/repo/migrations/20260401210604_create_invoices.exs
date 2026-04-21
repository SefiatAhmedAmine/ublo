defmodule MyApp.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices) do
      add :number, :string
      add :date, :date
      add :customer_name, :string
      add :total, :decimal
      add :pdf_path, :string
      add :exported, :boolean, default: false
      add :foreign_id, :string
      add :provider, :string
      add :failure_reason, :string
      add :name, :string
      add :description, :string
      add :mime_type, :string
      add :state, :string
      add :type, :string
      add :start_date, :date
      add :end_date, :date
      add :terms, {:array, :string}
      add :start_term, :string
      add :end_term, :string

      timestamps()
    end
  end
end
