defmodule MyApp.InvoiceCompleteAndEnqueueTest do
  @moduledoc false

  use MyApp.DataCase, async: true

  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceExportWorker
  alias MyApp.InvoiceService
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  describe "complete_and_enqueue_export/1 (Sprint 5 — checkpoint: transition + transactional job)" do
    test "draft + PDF → completed and one Oban job" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          state: :draft,
          pdf_path: path
        })

      assert {:ok, {:scheduled, from_db, %Oban.Job{}}} =
               InvoiceService.validate_invoice_and_enqueue_export(inv.id)

      assert from_db.state == :completed
      assert_enqueued(worker: InvoiceExportWorker, args: %{invoice_id: inv.id})
    end

    test "already completed + PDF → enqueues without changing state" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          state: :completed,
          pdf_path: path
        })

      assert {:ok, {:scheduled, from_db, %Oban.Job{}}} =
               InvoiceService.validate_invoice_and_enqueue_export(inv.id)

      assert from_db.state == :completed
      assert_enqueued(worker: InvoiceExportWorker, args: %{invoice_id: inv.id})
    end

    test "already exported → skipped, no new job" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          state: :completed,
          pdf_path: path,
          exported: true
        })

      assert {:ok, {:skipped, :already_exported}} =
               InvoiceService.validate_invoice_and_enqueue_export(inv.id)

      refute_enqueued(worker: InvoiceExportWorker)
    end

    test "unknown id → not_found" do
      assert {:error, :not_found} =
               InvoiceService.validate_invoice_and_enqueue_export(9_999_999_999)
    end

    test "wrong document type → error and no job" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          state: :draft,
          type: :payment_notice,
          pdf_path: path
        })

      assert {:error, msg} = InvoiceService.validate_invoice_and_enqueue_export(inv.id)
      assert msg == InvoiceErrors.invoice_not_custom_notice()
      refute_enqueued(worker: InvoiceExportWorker)
    end

    test "failed state → invalid_state" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          state: :failed,
          pdf_path: path
        })

      assert {:error, :invalid_state} = InvoiceService.validate_invoice_and_enqueue_export(inv.id)
      refute_enqueued(worker: InvoiceExportWorker)
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

    attrs =
      defaults
      |> Map.merge(overrides)
      |> Map.put_new_lazy(:pdf_path, fn -> write_temp_pdf!() end)

    %Invoice{}
    |> Invoice.changeset(attrs)
    |> Repo.insert!()
  end

  defp write_temp_pdf! do
    dir = Path.expand("tmp/test_pdfs", File.cwd!())
    File.mkdir_p!(dir)

    path =
      Path.join(dir, "ublo-trigger-test-#{System.unique_integer([:positive])}.pdf")

    File.write!(path, "%PDF-1.4 test bytes")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
