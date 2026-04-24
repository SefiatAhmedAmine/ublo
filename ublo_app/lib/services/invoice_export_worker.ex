defmodule MyApp.InvoiceExportWorker do
  @moduledoc """
  **Retry policy (Oban 2.x):**
  - `:ok` — success, or invoice already `exported: true` (idempotent skip; no call to Exporter).
  - `{:cancel, reason}` — non-retryable: bad args, unknown invoice id, or exporter errors that
    will not fix themselves without domain changes (wrong state/type, missing `pdf_path` rule).
  - `{:error, reason}` — retryable: missing PDF on disk, read errors, and other possibly transient failures.

  ## Enqueue from IEx
      iex -S mix
      MyApp.InvoiceExportWorker.enqueue_export(42)

  Jobs are **unique** per `invoice_id` while an export job is still *incomplete* (Oban states
  `available`, `scheduled`, `executing`, `retryable`, `suspended`). A second insert returns
  `{:ok, %Oban.Job{conflict?: true}}` with the existing job. Prefer
  `InvoiceService.validate_invoice_and_enqueue_export/1` for domain callers so skips are explicit.
  """

  use Oban.Worker,
    queue: :invoices,
    max_attempts: 5,
    unique: [
      period: :infinity,
      fields: [:worker, :args],
      keys: [:invoice_id],
      states: :incomplete
    ]

  alias MyApp.Exporter
  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceService

  @non_retryable_errors InvoiceErrors.non_retryable_export_messages()

  @doc """
  Enqueues a single export job for `invoice_id`.

  Returns `{:ok, %Oban.Job{}}` or `{:error, changeset}` from `Oban.insert/1`.
  """
  def enqueue_export(invoice_id) do
    %{invoice_id: invoice_id}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invoice_id" => id}}) do
    case normalize_invoice_id(id) do
      {:cancel, reason} ->
        {:cancel, reason}

      {:ok, int_id} ->
        case InvoiceService.get(int_id) do
          nil ->
            {:cancel, :invoice_not_found}

          %_{exported: true} ->
            :ok

          invoice ->
            case Exporter.export_invoice(invoice) do
              {:ok, _} -> :ok
              {:error, reason} -> map_exporter_error(reason)
            end
        end
    end
  end

  def perform(%Oban.Job{}), do: {:cancel, :missing_invoice_id}

  defp normalize_invoice_id(id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> {:cancel, :invalid_invoice_id}
    end
  end

  defp normalize_invoice_id(id) when is_number(id) and id > 0 do
    {:ok, trunc(id)}
  end

  defp normalize_invoice_id(_), do: {:cancel, :invalid_invoice_id}

  defp map_exporter_error(reason) when is_binary(reason) do
    cond do
      MapSet.member?(@non_retryable_errors, reason) ->
        {:cancel, reason}

      reason == InvoiceErrors.pdf_file_not_found() ->
        {:error, reason}

      String.starts_with?(reason, InvoiceErrors.cannot_read_pdf_prefix()) ->
        {:error, reason}

      true ->
        {:error, reason}
    end
  end

  defp map_exporter_error(reason), do: {:error, reason}
end
