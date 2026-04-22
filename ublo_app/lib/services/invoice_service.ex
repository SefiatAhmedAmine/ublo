defmodule MyApp.InvoiceService do
  @moduledoc """
  Point d’entrée pour tout ce qui touche aux factures en base : requêtes,
  règles d’éligibilité, et `Repo` pour `Invoice`.

  Le schéma `MyApp.Schemas.Invoice` ne fait que struct + changesets.
  """

  import Ecto.Query

  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  def get(id), do: Repo.get(Invoice, id)

  def get!(id), do: Repo.get!(Invoice, id)

  def update(%Ecto.Changeset{} = changeset), do: Repo.update(changeset)

  def get_invoices_not_exported_by_state_and_type(state, type) do
    Repo.all(
      from(i in Invoice, where: i.state == ^state and i.type == ^type and i.exported == false)
    )
  end

  @doc "Returns `{:ok, db_invoice}` when DB preconditions for export hold, else `{:error, msg}`."
  def fetch_exportable_invoice(%Invoice{id: nil}), do: {:error, "Invoice ID is required"}

  def fetch_exportable_invoice(%Invoice{} = invoice) do
    case Repo.get(Invoice, invoice.id) do
      nil ->
        {:error, "Invoice not found"}

      %Invoice{exported: true} ->
        {:error, "Invoice is already exported"}

      %Invoice{state: state} when state != :completed ->
        {:error, "Invoice is not completed"}

      %Invoice{type: type} when type != :custom_invoice_notice ->
        {:error, "Invoice is not a custom invoice notice"}

      %Invoice{pdf_path: path} when path in [nil, ""] ->
        {:error, "PDF path is required"}

      %Invoice{} = db ->
        {:ok, db}
    end
  end
end
