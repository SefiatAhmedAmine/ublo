defmodule MyApp.InvoiceService do
  @moduledoc """
  Point d’entrée pour tout ce qui touche aux factures en base : requêtes,
  règles d’éligibilité, et `Repo` pour `Invoice`.

  Le schéma `MyApp.Schemas.Invoice` ne fait que struct + changesets.
  """

  import Ecto.Query

  alias MyApp.InvoiceErrors
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
  def fetch_exportable_invoice(%Invoice{id: nil}),
    do: {:error, InvoiceErrors.invoice_id_required()}

  def fetch_exportable_invoice(%Invoice{} = invoice) do
    case Repo.get(Invoice, invoice.id) do
      nil ->
        {:error, InvoiceErrors.invoice_not_found()}

      %Invoice{exported: true} ->
        {:error, InvoiceErrors.invoice_already_exported()}

      %Invoice{state: state} when state != :completed ->
        {:error, InvoiceErrors.invoice_not_completed()}

      %Invoice{type: type} when type != :custom_invoice_notice ->
        {:error, InvoiceErrors.invoice_not_custom_notice()}

      %Invoice{pdf_path: path} when path in [nil, ""] ->
        {:error, InvoiceErrors.pdf_path_required()}

      %Invoice{} = db ->
        {:ok, db}
    end
  end
end
