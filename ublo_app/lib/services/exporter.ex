defmodule MyApp.Exporter do
  @moduledoc false

  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceService
  alias MyApp.PennylaneClient
  alias MyApp.Schemas.Invoice

  @doc """
  Export synchrone : vérifie la facture, lit le PDF, passe par l’étape Pennylane
  (no-op pour l’instant), puis persiste le succès ou une `failure_reason`.
  """
  def export_invoice(%Invoice{} = invoice) do
    result =
      with {:ok, db_invoice} <- InvoiceService.fetch_exportable_invoice(invoice),
           :ok <- verify_pdf_readable(db_invoice.pdf_path),
           :ok <- PennylaneClient.send_invoice(db_invoice.name, api_key()),
           {:ok, exported} <- persist_success(db_invoice) do
        {:ok, exported}
      else
        {:error, %Ecto.Changeset{} = cs} ->
          {:error, changeset_failure_message(cs)}

        {:error, reason} when is_binary(reason) ->
          {:error, reason}

        other ->
          {:error, format_failure_reason(other)}
      end

    case result do
      {:ok, _} = ok ->
        ok

      {:error, reason} = err ->
        record_failure_on_invoice(invoice, reason)
        err
    end
  end

  defp verify_pdf_readable(path) do
    case File.read(path) do
      {:ok, _} -> :ok
      {:error, :enoent} -> {:error, InvoiceErrors.pdf_file_not_found()}
      {:error, reason} -> {:error, InvoiceErrors.cannot_read_pdf(reason)}
    end
  end

  defp persist_success(%Invoice{} = db_invoice) do
    db_invoice
    |> Invoice.changeset(%{
      exported: true,
      foreign_id: "stub-#{db_invoice.id}",
      failure_reason: nil
    })
    |> InvoiceService.update()
  end

  defp record_failure_on_invoice(%Invoice{id: id}, reason) when is_integer(id) do
    text = format_failure_reason(reason)

    case InvoiceService.get(id) do
      nil ->
        :ok

      %Invoice{exported: true} ->
        :ok

      row ->
        _ =
          row
          |> Invoice.changeset(%{failure_reason: text})
          |> InvoiceService.update()

        :ok
    end
  end

  defp record_failure_on_invoice(_, _), do: :ok

  defp format_failure_reason(msg) when is_binary(msg), do: String.slice(msg, 0, 255)

  defp format_failure_reason(other),
    do: other |> inspect() |> String.slice(0, 255)

  defp changeset_failure_message(cs) do
    cs
    |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map_join("; ", fn {field, errs} -> "#{field}: #{Enum.join(errs, ", ")}" end)
    |> String.slice(0, 255)
  end

  defp api_key do
    Application.fetch_env!(:ublo_app, :pennylane_api_key)
  end
end
