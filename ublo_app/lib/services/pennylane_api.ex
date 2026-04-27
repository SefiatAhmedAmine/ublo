defmodule MyApp.PennylaneAPI do
  @moduledoc """
  Behaviour for Pennylane e-invoice upload integration.
  """

  @type response_body :: map()
  @type error_reason :: term()

  @callback send_invoice(pdf_path :: String.t(), api_key :: String.t()) ::
              {:ok, response_body()} | {:error, error_reason()}
end
