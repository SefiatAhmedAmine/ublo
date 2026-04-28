defmodule MyApp.InvoicePDFSource do
  @moduledoc """
  Boundary for resolving the PDF file used by invoice exports.

  The local implementation returns a filesystem path. A remote implementation can
  later resolve `invoice.name` from DigitalOcean Spaces into a temporary file.
  """

  alias MyApp.Schemas.Invoice

  @callback resolve_pdf_path(Invoice.t()) :: {:ok, String.t()} | {:error, String.t()}
end
