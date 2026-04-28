defmodule MyApp.Exporter do
  @moduledoc false

  alias MyApp.InvoiceExportService
  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceService
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  @doc """
  Export synchrone : vérifie la facture, lit le PDF, envoie vers Pennylane,
  puis persiste le succès ou une `failure_reason`.
  """
  def export_invoice(%Invoice{} = invoice) do
    result =
      with {:ok, db_invoice} <- InvoiceService.fetch_exportable_invoice(invoice),
           {:ok, pdf_path} <- pdf_source().resolve_pdf_path(db_invoice),
           {:ok, response} <- send_to_pennylane(pdf_path),
           {:ok, pennylane_id} <- extract_pennylane_id(response),
           {:ok, exported} <- persist_success(db_invoice, pennylane_id) do
        {:ok, exported}
      else
        {:error, %Ecto.Changeset{} = cs} ->
          {:error, changeset_failure_message(cs)}

        {:error, reason} when is_binary(reason) ->
          {:error, reason}

        {:error, reason} ->
          {:error, pennylane_error_message(reason)}

        other ->
          {:error, format_failure_reason(other)}
      end

    case result do
      {:ok, _} = ok ->
        ok

      {:error, reason} = err ->
        record_failure_on_invoice(invoice, reason)
        InvoiceExportService.record_failure(invoice, reason)
        err
    end
  end

  defp extract_pennylane_id(%{"id" => id}) when is_binary(id) and id != "", do: {:ok, id}
  defp extract_pennylane_id(%{"id" => id}) when is_integer(id), do: {:ok, Integer.to_string(id)}
  defp extract_pennylane_id(_response), do: {:error, :missing_pennylane_id}

  defp persist_success(%Invoice{} = db_invoice, pennylane_id),
    do: InvoiceExportService.mark_success(db_invoice, pennylane_id)

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
          |> Ecto.Changeset.change(%{failure_reason: text})
          |> Repo.update()

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
    Application.get_env(:ublo_app, :pennylane_api_key, "")
  end

  defp send_to_pennylane(pdf_path) do
    try do
      client_module().send_invoice(pdf_path, api_key())
    rescue
      e in File.Error ->
        {:error, {:pdf_unavailable, Exception.message(e)}}

      e ->
        {:error, {:unexpected_error, Exception.message(e)}}
    end
  end

  defp client_module do
    Application.get_env(:ublo_app, :pennylane_client, MyApp.PennylaneClient)
  end

  defp pdf_source do
    Application.get_env(:ublo_app, :invoice_pdf_source, MyApp.LocalInvoicePDFSource)
  end

  defp pennylane_error_message(:missing_api_key), do: InvoiceErrors.pennylane_api_key_missing()

  defp pennylane_error_message(:invalid_arguments),
    do: InvoiceErrors.pennylane_invalid_arguments()

  defp pennylane_error_message(:missing_pennylane_id),
    do: InvoiceErrors.pennylane_response_missing_id()

  defp pennylane_error_message({:pdf_unavailable, msg}),
    do: InvoiceErrors.cannot_read_pdf(msg)

  defp pennylane_error_message({:bad_request, _}),
    do: InvoiceErrors.pennylane_bad_request()

  defp pennylane_error_message({:unauthorized, _}), do: InvoiceErrors.pennylane_unauthorized()
  defp pennylane_error_message({:forbidden, _}), do: InvoiceErrors.pennylane_forbidden()

  defp pennylane_error_message({:invalid_payload, _}),
    do: InvoiceErrors.pennylane_invalid_payload()

  defp pennylane_error_message({:transient_network, _}),
    do: "Pennylane network error"

  defp pennylane_error_message({:transient_http_error, status, _}),
    do: "Pennylane temporary server error (#{status})"

  defp pennylane_error_message({:unexpected_status, status, _}),
    do: "Pennylane unexpected status (#{status})"

  defp pennylane_error_message({:transport_error, _}),
    do: "Pennylane transport error"

  defp pennylane_error_message({:unexpected_error, _}),
    do: "Pennylane unexpected error"

  defp pennylane_error_message(other), do: format_failure_reason(other)
end
