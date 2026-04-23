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

  def cannot_read_pdf(reason), do: "Cannot read PDF: #{inspect(reason)}"

  def cannot_read_pdf_prefix, do: "Cannot read PDF"

  @doc "Messages that should not trigger Oban retries when returned from export."
  def non_retryable_export_messages do
    MapSet.new([
      invoice_not_completed(),
      invoice_not_custom_notice(),
      pdf_path_required(),
      invoice_id_required(),
      invoice_already_exported()
    ])
  end
end
