defmodule Invoice do
  use Ecto.Schema

  ## Module attributes start ##
  @state MyApp.InvoiceConstants.state()
  @provider MyApp.InvoiceConstants.provider()
  @invoice_documents_type MyApp.InvoiceConstants.invoice_documents_type()
  ## Module attributes end ##

  schema "invoices" do
    field(:number, :string)
    field(:date, :date)
    field(:customer_name, :string)
    field(:total, :decimal)
    field(:pdf_path, :string)
    field(:exported, :boolean, default: false)
    field(:foreign_id, :string)
    field(:provider, Ecto.Enum, values: @provider)
    field(:failure_reason, :string)
    field(:name, :string)
    field(:description, :string)
    field(:mime_type, :string)
    field(:state, Ecto.Enum, values: @state)
    field(:type, Ecto.Enum, values: @invoice_documents_type)
    field(:start_date, :date)
    field(:end_date, :date)
    field(:terms, {:array, :string})
    field(:start_term, :string)
    field(:end_term, :string)
    timestamps()
  end
end
