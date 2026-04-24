defmodule MyApp.InvoiceService do
  @moduledoc """
  Point d’entrée pour tout ce qui touche aux factures en base : requêtes,
  règles d’éligibilité, et `Repo` pour `Invoice`.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias Oban
  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceExportWorker
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

  @doc """
  Transition « validation OK » (`:completed`), puis insertion d’un job d’export dans la **même**
  transaction que la mise à jour facture.

  Retours:
  - `{:ok, {:scheduled, %Invoice{}, %Oban.Job{}}}` — nouveau job inséré.
  - `{:ok, {:skipped, :already_exported}}` — facture déjà exportée.
  - `{:ok, {:skipped, :already_enqueued}}` — un job d’export **incomplet** existe déjà pour cette facture (unicité Oban).
  - `{:error, reason}` — facture absente, état incompatible, type / PDF invalides, ou échec insert job.
  """
  def validate_invoice_and_enqueue_export(invoice_id) when is_integer(invoice_id) do
    Multi.new()
    |> Multi.run(:trigger, fn repo, _changes ->
      case repo.get(Invoice, invoice_id) do
        nil ->
          {:error, :not_found}

        %Invoice{exported: true} ->
          {:ok, {:skipped, :already_exported}}

        %Invoice{} = invoice ->
          with :ok <- check_export_trigger_preconditions(invoice),
               {:ok, invoice} <- transition_to_completed_if_needed(repo, invoice) do
            {:ok, {:enqueue, invoice}}
          end
      end
    end)
    |> Multi.merge(fn %{trigger: step} ->
      case step do
        {:skipped, _} ->
          Multi.new()
          |> Multi.run(:export_job, fn _repo, _ -> {:ok, :none} end)

        {:enqueue, %Invoice{} = inv} ->
          Multi.new()
          |> Oban.insert(:export_job, InvoiceExportWorker.new(%{invoice_id: inv.id}))
      end
    end)
    |> Repo.transaction()
    |> unwrap_validate_and_enqueue_result()
  end

  defp check_export_trigger_preconditions(%Invoice{} = invoice) do
    cond do
      invoice.type != :custom_invoice_notice ->
        {:error, InvoiceErrors.invoice_not_custom_notice()}

      invoice.pdf_path in [nil, ""] ->
        {:error, InvoiceErrors.pdf_path_required()}

      invoice.state == :failed ->
        {:error, :invalid_state}

      invoice.state not in [:draft, :uploading, :completed] ->
        {:error, :invalid_state}

      true ->
        :ok
    end
  end

  defp transition_to_completed_if_needed(_repo, %Invoice{state: :completed} = invoice) do
    {:ok, invoice}
  end

  defp transition_to_completed_if_needed(repo, %Invoice{} = invoice) do
    invoice
    |> Invoice.changeset(%{state: :completed})
    |> repo.update()
  end

  defp unwrap_validate_and_enqueue_result(result) do
    case result do
      {:ok, %{trigger: {:skipped, _} = skipped, export_job: :none}} ->
        {:ok, skipped}

      {:ok, %{trigger: {:enqueue, invoice}, export_job: %Oban.Job{} = job}} ->
        if job.conflict? do
          {:ok, {:skipped, :already_enqueued}}
        else
          {:ok, {:scheduled, invoice, job}}
        end

      {:error, _failed_op, reason, _changes} ->
        {:error, reason}
    end
  end
end
