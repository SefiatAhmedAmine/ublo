defmodule InvoiceRepoTest do
  use MyApp.DataCase, async: true

  alias MyApp.Repo

  test "inserts an invoice through the Sandbox pool" do
    attrs = %{
      number: "INV-#{System.unique_integer([:positive])}",
      date: Date.utc_today(),
      customer_name: "Sandbox customer",
      total: Decimal.new("12.34"),
      provider: :digital_ocean,
      state: :draft,
      type: :custom_invoice_notice
    }

    invoice =
      %Invoice{}
      |> Invoice.changeset(attrs)
      |> Repo.insert!()

    assert invoice.id
    assert invoice.exported == false
    assert Repo.get(Invoice, invoice.id)
  end
end
