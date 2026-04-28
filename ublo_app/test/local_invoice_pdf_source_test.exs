defmodule MyApp.LocalInvoicePDFSourceTest do
  use ExUnit.Case, async: true

  alias MyApp.InvoiceErrors
  alias MyApp.LocalInvoicePDFSource
  alias MyApp.Schemas.Invoice

  test "returns the local path when the PDF can be read" do
    path = write_temp_pdf!()

    assert LocalInvoicePDFSource.resolve_pdf_path(%Invoice{pdf_path: path}) == {:ok, path}
  end

  describe "exportable?/1" do
    test "true when pdf_path is a non-empty binary" do
      assert LocalInvoicePDFSource.exportable?(%Invoice{pdf_path: "/tmp/x.pdf"})
    end

    test "false when pdf_path is missing" do
      refute LocalInvoicePDFSource.exportable?(%Invoice{pdf_path: nil})
      refute LocalInvoicePDFSource.exportable?(%Invoice{pdf_path: ""})
    end

    test "false when only the remote name is set (local source can't fetch it)" do
      refute LocalInvoicePDFSource.exportable?(%Invoice{
               pdf_path: nil,
               name: "spaces/invoices/x.pdf"
             })
    end
  end

  test "requires a local pdf_path for the local implementation" do
    assert LocalInvoicePDFSource.resolve_pdf_path(%Invoice{pdf_path: nil}) ==
             {:error, InvoiceErrors.pdf_path_required()}
  end

  test "maps missing files to the shared PDF error" do
    path = Path.join(System.tmp_dir!(), "missing-#{System.unique_integer([:positive])}.pdf")

    assert LocalInvoicePDFSource.resolve_pdf_path(%Invoice{pdf_path: path}) ==
             {:error, InvoiceErrors.pdf_file_not_found()}
  end

  test "maps unreadable paths to the shared PDF error prefix" do
    dir = Path.join(System.tmp_dir!(), "ublo-pdf-source-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rmdir(dir) end)

    assert {:error, reason} = LocalInvoicePDFSource.resolve_pdf_path(%Invoice{pdf_path: dir})
    assert String.starts_with?(reason, InvoiceErrors.cannot_read_pdf_prefix())
  end

  defp write_temp_pdf! do
    dir = Path.join(System.tmp_dir!(), "ublo-pdf-source-tests")
    File.mkdir_p!(dir)
    path = Path.join(dir, "invoice-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "%PDF-1.4 test bytes")
    on_exit(fn -> File.rm(path) end)
    path
  end
end
