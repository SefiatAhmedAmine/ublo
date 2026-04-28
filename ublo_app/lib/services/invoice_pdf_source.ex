defmodule MyApp.InvoicePDFSource do
  @moduledoc """
  Boundary for resolving the PDF file used by invoice exports.

  The local implementation returns a filesystem path. A remote implementation can
  later resolve `invoice.name` from DigitalOcean Spaces into a temporary file.
  """

  alias MyApp.Schemas.Invoice

  @doc """
  Cheap, side-effect-free check used by eligibility / enqueue logic to decide
  whether the configured source has any chance of resolving a PDF for this
  invoice. should return `true` when the relevant fields are
  populated (e.g. `pdf_path` for the local source, `name` for a remote one)
  """
  @callback exportable?(Invoice.t()) :: boolean()

  @callback resolve_pdf_path(Invoice.t()) :: {:ok, String.t()} | {:error, String.t()}
end
