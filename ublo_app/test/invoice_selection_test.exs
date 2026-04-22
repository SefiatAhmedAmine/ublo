defmodule InvoiceSelectionTest do
  use MyApp.DataCase, async: true

  alias MyApp.InvoiceService
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  describe "get_invoices_not_exported_by_state_and_type/2" do
    test "export candidates: only completed custom_invoice_notice with exported false" do
      eligible =
        insert_invoice!(%{
          state: :completed,
          type: :custom_invoice_notice,
          exported: false
        })

      insert_invoice!(%{state: :completed, type: :rent_receipt, exported: false})
      insert_invoice!(%{state: :draft, type: :custom_invoice_notice, exported: false})
      insert_invoice!(%{state: :completed, type: :custom_invoice_notice, exported: true})

      result =
        InvoiceService.get_invoices_not_exported_by_state_and_type(
          :completed,
          :custom_invoice_notice
        )

      ids = Enum.map(result, & &1.id) |> MapSet.new()
      assert MapSet.size(ids) == 1
      assert MapSet.member?(ids, eligible.id)
    end

    test "returns every matching row when several qualify" do
      a =
        insert_invoice!(%{
          number: "INV-A-#{System.unique_integer([:positive])}",
          state: :completed,
          type: :custom_invoice_notice,
          exported: false
        })

      b =
        insert_invoice!(%{
          number: "INV-B-#{System.unique_integer([:positive])}",
          state: :completed,
          type: :custom_invoice_notice,
          exported: false
        })

      result =
        InvoiceService.get_invoices_not_exported_by_state_and_type(
          :completed,
          :custom_invoice_notice
        )

      ids = Enum.map(result, & &1.id) |> MapSet.new()
      assert MapSet.equal?(ids, MapSet.new([a.id, b.id]))
    end

    test "filters by the given state and type independently" do
      draft_notice =
        insert_invoice!(%{state: :draft, type: :custom_invoice_notice, exported: false})

      completed_receipt =
        insert_invoice!(%{state: :completed, type: :rent_receipt, exported: false})

      draft_notices =
        InvoiceService.get_invoices_not_exported_by_state_and_type(:draft, :custom_invoice_notice)

      completed_receipts =
        InvoiceService.get_invoices_not_exported_by_state_and_type(:completed, :rent_receipt)

      assert Enum.map(draft_notices, & &1.id) == [draft_notice.id]
      assert Enum.map(completed_receipts, & &1.id) == [completed_receipt.id]
    end
  end

  defp insert_invoice!(overrides) do
    defaults = %{
      number: "INV-#{System.unique_integer([:positive])}",
      date: Date.utc_today(),
      customer_name: "Customer",
      total: Decimal.new("10.00"),
      provider: :digital_ocean,
      state: :completed,
      type: :custom_invoice_notice,
      exported: false
    }

    %Invoice{}
    |> Invoice.changeset(Map.merge(defaults, overrides))
    |> Repo.insert!()
  end
end
