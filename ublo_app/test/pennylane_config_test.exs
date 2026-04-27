defmodule MyApp.PennylaneConfigTest do
  use ExUnit.Case, async: true

  test "pennylane client and endpoint settings are configured" do
    client = Application.fetch_env!(:ublo_app, :pennylane_client)
    endpoint = Application.fetch_env!(:ublo_app, :pennylane_e_invoices_import_url)
    invoice_type = Application.fetch_env!(:ublo_app, :pennylane_e_invoice_type)

    assert client in [MyApp.PennylaneClient, MyApp.PennylaneClientMock]
    assert String.ends_with?(endpoint, "/api/external/v2/e-invoices/imports")
    assert invoice_type in [:customer, :supplier]
  end
end
