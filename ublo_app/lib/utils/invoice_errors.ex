defmodule MyApp.InvoiceErrors do
  @moduledoc """
  User-visible strings for invoice export eligibility and PDF handling.
  Single source of truth for comparisons, persistence (`failure_reason`), and tests.
  """

  def invoice_id_required, do: "Invoice ID is required"
  def invoice_not_found, do: "Invoice not found"
  def invoice_already_exported, do: "Invoice is already exported"
  def invoice_not_completed, do: "Invoice is not completed"
  def invoice_not_custom_notice, do: "Invoice is not a custom invoice notice"
  def pdf_path_required, do: "PDF path is required"
  def pdf_file_not_found, do: "PDF file not found"
  def pennylane_api_key_missing, do: "Pennylane API key is missing"
  def pennylane_invalid_arguments, do: "Invalid Pennylane request arguments"
  def pennylane_bad_request, do: "Pennylane rejected the request payload"
  def pennylane_unauthorized, do: "Pennylane authorization failed"
  def pennylane_forbidden, do: "Pennylane access forbidden"
  def pennylane_invalid_payload, do: "Pennylane invoice payload is invalid"
  def pennylane_response_missing_id, do: "Pennylane response is missing invoice id"

  def cannot_read_pdf(reason) when is_binary(reason), do: "Cannot read PDF: #{reason}"
  def cannot_read_pdf(reason), do: "Cannot read PDF: #{inspect(reason)}"

  def cannot_read_pdf_prefix, do: "Cannot read PDF"

  @doc "Messages that should not trigger Oban retries when returned from export."
  def non_retryable_export_messages do
    MapSet.new([
      invoice_not_completed(),
      invoice_not_custom_notice(),
      pdf_path_required(),
      invoice_id_required(),
      invoice_already_exported(),
      pennylane_api_key_missing(),
      pennylane_invalid_arguments(),
      pennylane_bad_request(),
      pennylane_unauthorized(),
      pennylane_forbidden(),
      pennylane_invalid_payload(),
      pennylane_response_missing_id()
    ])
  end
end
