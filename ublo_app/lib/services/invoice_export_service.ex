defmodule MyApp.InvoiceExportService do
  @moduledoc """
  Persists audit records for Pennylane invoice export attempts.

  Concurrency model:
  - Both the success and failure paths take a `FOR UPDATE` lock on the parent
    `invoices` row before reading `MAX(attempts)`, so two writers serialize
    around the same invoice instead of racing on the count.
  - A unique index on `(invoice_id, attempts)` is the last line of defense:
    if the lock is somehow bypassed (e.g. a writer outside this module), an
    in-flight insert retries with a fresh attempt number.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice
  alias MyApp.Schemas.InvoiceExport

  @max_attempt_retries 3

  def mark_success(%Invoice{} = invoice, foreign_id) when is_binary(foreign_id) do
    Multi.new()
    |> Multi.run(:lock, fn repo, _changes -> lock_invoice(repo, invoice.id) end)
    |> Multi.update(
      :invoice,
      Ecto.Changeset.change(invoice, %{
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
    Multi.new()
    |> Multi.run(:lock, fn repo, _ -> lock_invoice(repo, id) end)
    |> Multi.run(:export_attempt, fn repo, _ ->
      insert_attempt(repo, id, %{
        foreign_id: nil,
        status: :failed,
        error: format_error(reason),
        exported_at: nil
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{export_attempt: row}} -> {:ok, row}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
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

  defp lock_invoice(repo, invoice_id) do
    case repo.one(from(i in Invoice, where: i.id == ^invoice_id, lock: "FOR UPDATE")) do
      nil -> {:error, :invoice_not_found}
      %Invoice{} = invoice -> {:ok, invoice}
    end
  end

  defp insert_attempt(repo, invoice_id, attrs, retries \\ @max_attempt_retries)

  defp insert_attempt(_repo, _invoice_id, _attrs, 0), do: {:error, :too_many_attempt_conflicts}

  defp insert_attempt(repo, invoice_id, attrs, retries) do
    attempts = next_attempt(repo, invoice_id)

    %InvoiceExport{}
    |> InvoiceExport.changeset(Map.merge(attrs, %{invoice_id: invoice_id, attempts: attempts}))
    |> repo.insert()
    |> case do
      {:ok, _row} = ok ->
        ok

      {:error, %Ecto.Changeset{errors: errors}} = err ->
        if attempts_conflict?(errors) do
          insert_attempt(repo, invoice_id, attrs, retries - 1)
        else
          err
        end
    end
  end

  defp attempts_conflict?(errors) do
    case Keyword.get(errors, :attempts) do
      {_, opts} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end
  end

  defp next_attempt(repo, invoice_id) do
    max =
      repo.one(
        from(e in InvoiceExport,
          where: e.invoice_id == ^invoice_id,
          select: max(e.attempts)
        )
      )

    (max || 0) + 1
  end

  defp format_error(reason) when is_binary(reason), do: String.slice(reason, 0, 255)
  defp format_error(reason), do: reason |> inspect() |> String.slice(0, 255)
end
