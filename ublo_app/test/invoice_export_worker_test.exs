defmodule MyApp.InvoiceExportWorkerTest do
  use MyApp.DataCase, async: true

  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceExportWorker
  alias MyApp.InvoiceService
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  describe "perform/1 via perform_job/2" do
    test "exports eligible invoice" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert :ok = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})

      from_db = InvoiceService.get!(inv.id)
      assert from_db.exported == true
      assert from_db.foreign_id == "mocked"
    end

    test "second run on already-exported invoice is :ok and does not change foreign_id" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert :ok = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      first = InvoiceService.get!(inv.id)
      assert first.exported == true

      assert :ok = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      second = InvoiceService.get!(inv.id)
      assert second.foreign_id == first.foreign_id
      assert second.updated_at == first.updated_at
    end

    test "missing invoice_id arg cancels" do
      assert {:cancel, :missing_invoice_id} = perform_job(InvoiceExportWorker, %{})
    end

    test "unknown invoice id cancels" do
      assert {:cancel, :invoice_not_found} =
               perform_job(InvoiceExportWorker, %{invoice_id: 9_999_999_999})
    end

    test "invalid invoice_id string cancels" do
      assert {:cancel, :invalid_invoice_id} =
               perform_job(InvoiceExportWorker, %{invoice_id: "not-a-number"})
    end

    test "non-retryable exporter error returns cancel" do
      inv = insert_invoice!(%{state: :draft, pdf_path: write_temp_pdf!()})

      assert {:cancel, msg} = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      assert msg == InvoiceErrors.invoice_not_completed()
    end

    test "Pennylane client-side rejection is non-retryable" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      Mox.expect(MyApp.PennylaneClientMock, :send_invoice, fn ^path, _api_key ->
        {:error, {:bad_request, %{"error" => "bad payload"}}}
      end)

      assert {:cancel, msg} = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      assert msg == InvoiceErrors.pennylane_bad_request()
    end

    test "client raising File.Error during upload returns retryable error, not a crash" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      Mox.expect(MyApp.PennylaneClientMock, :send_invoice, fn ^path, _api_key ->
        raise File.Error, action: "stream", reason: :enoent, path: path
      end)

      assert {:error, msg} = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      assert String.starts_with?(msg, InvoiceErrors.cannot_read_pdf_prefix())

      from_db = InvoiceService.get!(inv.id)
      assert from_db.exported == false
      assert from_db.failure_reason == msg
    end

    test "missing PDF file returns error tuple for retries" do
      inv =
        insert_invoice!(%{
          pdf_path: "/no/such/file-#{System.unique_integer([:positive])}.pdf"
        })

      assert {:error, msg} = perform_job(InvoiceExportWorker, %{invoice_id: inv.id})
      assert msg == InvoiceErrors.pdf_file_not_found()
    end

    test "accepts string invoice_id from JSON-style args" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert :ok = perform_job(InvoiceExportWorker, %{"invoice_id" => to_string(inv.id)})
    end
  end

  describe "enqueue_export/1" do
    test "inserts a job for the worker and args" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert {:ok, %Oban.Job{}} = InvoiceExportWorker.enqueue_export(inv.id)

      assert_enqueued(worker: InvoiceExportWorker, args: %{invoice_id: inv.id})
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
      Path.join(dir, "ublo-worker-test-#{System.unique_integer([:positive])}.pdf")

    File.write!(path, "%PDF-1.4 test bytes")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
