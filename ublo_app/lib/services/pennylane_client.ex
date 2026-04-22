defmodule MyApp.PennylaneClient do
  @moduledoc """
  Client HTTP vers l’import e-factures Pennylane (multipart).

  **État actuel :** no-op — la fonction existe pour câbler le flux dans
  `MyApp.Exporter` (lecture PDF → étape « envoi » → persistance). Aucun appel
  réseau ; implémentation Req/multipart + tests mockés aux sprints 6–7.
  """

  require Logger

  @endpoint "https://app.pennylane.com/api/external/v2/e-invoices/imports"

  @doc "Placeholder jusqu’à l’implémentation HTTP. Retourne toujours `:ok`."
  def send_invoice(name, api_key) do
    Logger.debug(
      "PennylaneClient.send_invoice no-op name=#{inspect(name)} endpoint=#{@endpoint} api_key_set?=#{api_key != ""}"
    )

    :ok
  end
end
