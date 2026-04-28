defmodule MyApp.Schemas.InvoiceExportChangesetTest do
  use MyApp.DataCase, async: true

  alias MyApp.Schemas.Invoice
  alias MyApp.Schemas.InvoiceExport

  describe "changeset/2" do
    test "valid for a success row" do
      cs =
        InvoiceExport.changeset(%InvoiceExport{}, %{
          invoice_id: 1,
          foreign_id: "pl-1",
          status: :success,
          attempts: 1,
          exported_at: DateTime.utc_now(:second)
        })

      assert cs.valid?
    end

    test "valid for a failed row when error is set" do
      cs =
        InvoiceExport.changeset(%InvoiceExport{}, %{
          invoice_id: 1,
          status: :failed,
          attempts: 1,
          error: "boom"
        })

      assert cs.valid?
    end

    test "invalid for a failed row without an error message" do
      cs =
        InvoiceExport.changeset(%InvoiceExport{}, %{
          invoice_id: 1,
          status: :failed,
          attempts: 1
        })

      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :error)
    end

    test "invalid when attempts is not positive" do
      cs =
        InvoiceExport.changeset(%InvoiceExport{}, %{
          invoice_id: 1,
          status: :success,
          attempts: 0
        })

      refute cs.valid?
      assert Keyword.has_key?(cs.errors, :attempts)
    end
  end

  describe "unique_constraint on (invoice_id, attempts)" do
    test "DB violation surfaces under :attempts (not :invoice_id) so retries can detect it" do
      invoice = insert_invoice!()

      attrs = %{
        invoice_id: invoice.id,
        status: :failed,
        attempts: 1,
        error: "boom"
      }

      assert {:ok, _row} =
               %InvoiceExport{} |> InvoiceExport.changeset(attrs) |> Repo.insert()

      assert {:error, %Ecto.Changeset{errors: errors}} =
               %InvoiceExport{} |> InvoiceExport.changeset(attrs) |> Repo.insert()

      refute Keyword.has_key?(errors, :invoice_id)
      assert {_, opts} = Keyword.get(errors, :attempts)
      assert Keyword.get(opts, :constraint) == :unique
    end
  end

  defp insert_invoice! do
    %Invoice{}
    |> Invoice.changeset(%{
      number: "INV-#{System.unique_integer([:positive])}",
      date: Date.utc_today(),
      customer_name: "Customer",
      total: Decimal.new("10.00"),
      provider: :digital_ocean,
      state: :completed,
      type: :custom_invoice_notice,
      exported: false
    })
    |> Repo.insert!()
  end
end
