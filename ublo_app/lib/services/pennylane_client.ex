defmodule MyApp.PennylaneClient do
  @moduledoc """
  HTTP client for Pennylane e-invoice imports.
  """

  @behaviour MyApp.PennylaneAPI

  @impl MyApp.PennylaneAPI
  def send_invoice(pdf_path, api_key) when is_binary(pdf_path) and is_binary(api_key) do
    with true <- api_key != "" or {:error, :missing_api_key},
         {:ok, body} <- request_upload(pdf_path, api_key) do
      {:ok, body}
    else
      {:error, _} = err -> err
      false -> {:error, :missing_api_key}
      other -> {:error, {:unexpected_error, other}}
    end
  end

  def send_invoice(_pdf_path, _api_key), do: {:error, :invalid_arguments}

  defp request_upload(pdf_path, api_key) do
    case Req.post(url: endpoint(), auth: {:bearer, api_key}, form_multipart: multipart_fields(pdf_path)) do
      {:ok, %Req.Response{status: status, body: body}} when status in [200, 201] ->
        {:ok, normalize_body(body)}

      {:ok, %Req.Response{status: 400, body: body}} ->
        {:error, {:bad_request, normalize_body(body)}}

      {:ok, %Req.Response{status: 401, body: body}} ->
        {:error, {:unauthorized, normalize_body(body)}}

      {:ok, %Req.Response{status: 403, body: body}} ->
        {:error, {:forbidden, normalize_body(body)}}

      {:ok, %Req.Response{status: 422, body: body}} ->
        {:error, {:invalid_payload, normalize_body(body)}}

      {:ok, %Req.Response{status: status, body: body}} when status >= 500 ->
        {:error, {:transient_http_error, status, normalize_body(body)}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:unexpected_status, status, normalize_body(body)}}

      {:error, %Req.TransportError{} = err} ->
        {:error, {:transient_network, Exception.message(err)}}

      {:error, err} ->
        {:error, {:transport_error, Exception.message(err)}}
    end
  end

  defp multipart_fields(pdf_path) do
    [
      type: Atom.to_string(invoice_type()),
      file: {File.stream!(pdf_path), filename: Path.basename(pdf_path)}
    ]
  end

  defp normalize_body(%{} = body), do: body

  defp normalize_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{} = decoded} -> decoded
      _ -> %{"raw" => body}
    end
  end

  defp normalize_body(body), do: %{"raw" => inspect(body)}

  defp endpoint do
    Application.fetch_env!(:ublo_app, :pennylane_e_invoices_import_url)
  end

  defp invoice_type do
    case Application.fetch_env!(:ublo_app, :pennylane_e_invoice_type) do
      :customer -> :customer
      :supplier -> :supplier
      _ -> :customer
    end
  end
end
