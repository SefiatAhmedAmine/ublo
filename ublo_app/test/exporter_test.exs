defmodule ExporterTest do
  use MyApp.DataCase, async: true

  alias MyApp.Exporter
  alias MyApp.InvoiceErrors
  alias MyApp.InvoiceService
  alias MyApp.Repo
  alias MyApp.Schemas.Invoice

  describe "fetch_exportable_invoice/1" do
    test "rejects persisted invoice without id (unsaved struct)" do
      assert InvoiceService.fetch_exportable_invoice(%Invoice{}) ==
               {:error, InvoiceErrors.invoice_id_required()}
    end

    test "rejects unknown id" do
      assert InvoiceService.fetch_exportable_invoice(%Invoice{id: 9_999_999_999}) ==
               {:error, InvoiceErrors.invoice_not_found()}
    end

    test "rejects when already exported" do
      inv = insert_invoice!(%{exported: true, pdf_path: "/any"})

      assert InvoiceService.fetch_exportable_invoice(inv) ==
               {:error, InvoiceErrors.invoice_already_exported()}
    end

    test "rejects when state is not completed" do
      inv = insert_invoice!(%{state: :draft, pdf_path: "/x"})

      assert InvoiceService.fetch_exportable_invoice(inv) ==
               {:error, InvoiceErrors.invoice_not_completed()}
    end

    test "rejects when type is not custom_invoice_notice" do
      inv = insert_invoice!(%{type: :rent_receipt, pdf_path: "/x"})

      assert InvoiceService.fetch_exportable_invoice(inv) ==
               {:error, InvoiceErrors.invoice_not_custom_notice()}
    end

    test "rejects when pdf_path is missing" do
      inv = insert_invoice!(%{pdf_path: nil})

      assert InvoiceService.fetch_exportable_invoice(inv) ==
               {:error, InvoiceErrors.pdf_path_required()}
    end

    test "accepts an invoice with a remote PDF name reference" do
      inv = insert_invoice!(%{pdf_path: nil, name: "spaces/invoices/invoice.pdf"})

      assert {:ok, %Invoice{id: id}} = InvoiceService.fetch_exportable_invoice(inv)
      assert id == inv.id
    end

    test "accepts eligible row from DB" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert {:ok, %Invoice{id: id}} = InvoiceService.fetch_exportable_invoice(inv)
      assert id == inv.id
    end
  end

  describe "export_invoice/1" do
    test "calls configured Pennylane client with invoice pdf path" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})
      api_key = Application.fetch_env!(:ublo_app, :pennylane_api_key)

      Mox.expect(MyApp.PennylaneClientMock, :send_invoice, fn received_path, received_key ->
        assert received_path == path
        assert received_key == api_key
        {:ok, %{"id" => "pl-mock"}}
      end)

      assert {:ok, %Invoice{} = updated} = Exporter.export_invoice(inv)
      assert updated.exported == true
    end

    test "marks exported and stores Pennylane foreign_id when PDF exists" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      assert {:ok, %Invoice{} = updated} = Exporter.export_invoice(inv)
      assert updated.exported == true
      assert updated.foreign_id == "mocked"

      from_db = InvoiceService.get!(inv.id)
      assert from_db.exported == true
      assert from_db.foreign_id == "mocked"
    end

    test "records failure when Pennylane success response has no id" do
      path = write_temp_pdf!()
      inv = insert_invoice!(%{pdf_path: path})

      Mox.expect(MyApp.PennylaneClientMock, :send_invoice, fn ^path, _api_key ->
        {:ok, %{}}
      end)

      assert Exporter.export_invoice(inv) ==
               {:error, "Pennylane response is missing invoice id"}

      from_db = InvoiceService.get!(inv.id)
      assert from_db.exported == false
      assert from_db.failure_reason == "Pennylane response is missing invoice id"
    end

    test "returns error when PDF path is set but file is missing" do
      inv =
        insert_invoice!(%{pdf_path: "/no/such/file-#{System.unique_integer([:positive])}.pdf"})

      assert Exporter.export_invoice(inv) == {:error, InvoiceErrors.pdf_file_not_found()}
      from_db = InvoiceService.get!(inv.id)
      assert from_db.exported == false
      assert from_db.failure_reason == InvoiceErrors.pdf_file_not_found()
    end

    test "returns error from fetch_exportable_invoice without touching file" do
      inv = insert_invoice!(%{state: :draft, pdf_path: write_temp_pdf!()})

      assert Exporter.export_invoice(inv) == {:error, InvoiceErrors.invoice_not_completed()}

      assert InvoiceService.get!(inv.id).failure_reason ==
               InvoiceErrors.invoice_not_completed()
    end

    test "success clears failure_reason after a previous failure" do
      path = write_temp_pdf!()

      inv =
        insert_invoice!(%{
          pdf_path: "/no/such/file-#{System.unique_integer([:positive])}.pdf"
        })

      assert {:error, msg} = Exporter.export_invoice(inv)
      assert msg == InvoiceErrors.pdf_file_not_found()

      inv2 =
        inv
        |> Invoice.changeset(%{pdf_path: path})
        |> Repo.update!()

      assert {:ok, %Invoice{} = ok} = Exporter.export_invoice(inv2)
      assert ok.exported == true
      assert ok.failure_reason == nil
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
      Path.join(dir, "ublo-exporter-test-#{System.unique_integer([:positive])}.pdf")

    File.write!(path, "%PDF-1.4 test bytes")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
