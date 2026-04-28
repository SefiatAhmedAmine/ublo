defmodule MyApp.InvoiceExportService do
  @moduledoc """
  Persists audit records for Pennylane invoice export attempts.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice
  alias MyApp.Schemas.InvoiceExport

  def mark_success(%Invoice{} = invoice, foreign_id) when is_binary(foreign_id) do
    Multi.new()
    |> Multi.update(
      :invoice,
      Invoice.changeset(invoice, %{
        exported: true,
        foreign_id: foreign_id,
        failure_reason: nil
      })
    )
    |> Multi.run(:export_attempt, fn repo, %{invoice: exported} ->
      insert_attempt(repo, exported.id, %{
        foreign_id: foreign_id,
        status: :success,
        error: nil,
        exported_at: DateTime.utc_now(:second)
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{invoice: exported}} -> {:ok, exported}
      {:error, _operation, reason, _changes} -> {:error, reason}
    end
  end

  def record_failure(%Invoice{id: id}, reason) when is_integer(id) do
    insert_attempt(Repo, id, %{
      foreign_id: nil,
      status: :failed,
      error: format_error(reason),
      exported_at: nil
    })
  end

  def record_failure(_invoice, _reason), do: {:ok, :skipped}

  def list_for_invoice(invoice_id) when is_integer(invoice_id) do
    Repo.all(
      from(e in InvoiceExport,
        where: e.invoice_id == ^invoice_id,
        order_by: [asc: e.attempts, asc: e.id]
      )
    )
  end

  defp insert_attempt(repo, invoice_id, attrs) do
    attempts = next_attempt(repo, invoice_id)

    %InvoiceExport{}
    |> InvoiceExport.changeset(Map.merge(attrs, %{invoice_id: invoice_id, attempts: attempts}))
    |> repo.insert()
  end

  defp next_attempt(repo, invoice_id) do
    count =
      repo.aggregate(
        from(e in InvoiceExport, where: e.invoice_id == ^invoice_id),
        :count,
        :id
      )

    count + 1
  end

  defp format_error(reason) when is_binary(reason), do: String.slice(reason, 0, 255)
  defp format_error(reason), do: reason |> inspect() |> String.slice(0, 255)
end
