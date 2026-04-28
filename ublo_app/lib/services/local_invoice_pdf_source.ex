defmodule MyApp.LocalInvoicePDFSource do
  @moduledoc """
  Filesystem-backed PDF source for local development and tests.
  """

  @behaviour MyApp.InvoicePDFSource

  alias MyApp.InvoiceErrors
  alias MyApp.Schemas.Invoice

  @impl MyApp.InvoicePDFSource
  def exportable?(%Invoice{pdf_path: path}) when is_binary(path) and path != "", do: true
  def exportable?(%Invoice{}), do: false

  @impl MyApp.InvoicePDFSource
  def resolve_pdf_path(%Invoice{pdf_path: path}) when path in [nil, ""] do
    {:error, InvoiceErrors.pdf_path_required()}
  end

  def resolve_pdf_path(%Invoice{pdf_path: path}) when is_binary(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular}} ->
        {:ok, path}

      {:ok, %File.Stat{type: type}} ->
        {:error, InvoiceErrors.cannot_read_pdf({:not_a_regular_file, type})}

      {:error, :enoent} ->
        {:error, InvoiceErrors.pdf_file_not_found()}

      {:error, reason} ->
        {:error, InvoiceErrors.cannot_read_pdf(reason)}
    end
  end

  def resolve_pdf_path(_invoice), do: {:error, InvoiceErrors.pdf_path_required()}
end
