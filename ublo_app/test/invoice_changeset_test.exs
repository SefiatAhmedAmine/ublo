defmodule InvoiceChangesetTest do
  use MyApp.DataCase, async: true

  describe "changeset/2" do
    test "valid with required attributes" do
      params = %{
        number: "INV-42",
        date: ~D[2026-04-01],
        customer_name: "Acme",
        total: Decimal.new("99.00"),
        provider: :pandadoc,
        state: :completed,
        type: :custom_invoice_notice
      }

      changeset = Invoice.changeset(%Invoice{}, params)
      assert changeset.valid?
    end

    test "invalid when required attributes are missing" do
      changeset = Invoice.changeset(%Invoice{}, %{})
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :number)
    end
  end
end
