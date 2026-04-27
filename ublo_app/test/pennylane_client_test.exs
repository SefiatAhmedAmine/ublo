defmodule MyApp.PennylaneClientTest do
  use ExUnit.Case, async: true

  alias MyApp.PennylaneClient

  setup do
    bypass = Bypass.open()
    path = write_temp_pdf!()

    old_url = Application.get_env(:ublo_app, :pennylane_e_invoices_import_url)
    old_type = Application.get_env(:ublo_app, :pennylane_e_invoice_type)

    Application.put_env(
      :ublo_app,
      :pennylane_e_invoices_import_url,
      "http://127.0.0.1:#{bypass.port}/api/external/v2/e-invoices/imports"
    )

    Application.put_env(:ublo_app, :pennylane_e_invoice_type, :customer)

    on_exit(fn ->
      maybe_put_env(:pennylane_e_invoices_import_url, old_url)
      maybe_put_env(:pennylane_e_invoice_type, old_type)
      File.rm(path)
    end)

    {:ok, bypass: bypass, path: path}
  end

  test "sends multipart payload with file and type", %{bypass: bypass, path: path} do
    Bypass.expect_once(bypass, "POST", "/api/external/v2/e-invoices/imports", fn conn ->
      assert [auth] = Plug.Conn.get_req_header(conn, "authorization")
      assert auth == "Bearer test-api-key"

      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body =~ "name=\"type\""
      assert body =~ "customer"
      assert body =~ "name=\"file\""
      assert body =~ "%PDF-1.4"

      Plug.Conn.resp(conn, 201, ~s({"id":"pl-123"}))
    end)

    assert {:ok, %{"id" => "pl-123"}} = PennylaneClient.send_invoice(path, "test-api-key")
  end

  test "maps unauthorized response", %{bypass: bypass, path: path} do
    Bypass.expect_once(bypass, "POST", "/api/external/v2/e-invoices/imports", fn conn ->
      Plug.Conn.resp(conn, 401, ~s({"error":"invalid token"}))
    end)

    assert {:error, {:unauthorized, %{"error" => "invalid token"}}} =
             PennylaneClient.send_invoice(path, "bad-token")
  end

  test "maps network failures to transient_network", %{path: path} do
    Application.put_env(
      :ublo_app,
      :pennylane_e_invoices_import_url,
      "http://127.0.0.1:1/api/external/v2/e-invoices/imports"
    )

    assert {:error, {:transient_network, _message}} =
             PennylaneClient.send_invoice(path, "test-api-key")
  end

  defp maybe_put_env(key, nil), do: Application.delete_env(:ublo_app, key)
  defp maybe_put_env(key, value), do: Application.put_env(:ublo_app, key, value)

  defp write_temp_pdf! do
    dir = Path.expand("tmp/test_pdfs", File.cwd!())
    File.mkdir_p!(dir)
    path = Path.join(dir, "ublo-pennylane-client-test-#{System.unique_integer([:positive])}.pdf")
    File.write!(path, "%PDF-1.4 test bytes")
    path
  end
end
