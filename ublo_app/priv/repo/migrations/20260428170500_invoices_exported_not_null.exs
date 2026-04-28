defmodule MyApp.Repo.Migrations.InvoicesExportedNotNull do
  use Ecto.Migration

  def up do
    execute("UPDATE invoices SET exported = FALSE WHERE exported IS NULL")
    alter table(:invoices) do
      modify :exported, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:invoices) do
      modify :exported, :boolean, null: true, default: false
    end
  end
end
