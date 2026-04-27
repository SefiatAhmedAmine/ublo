defmodule MyApp.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      alias MyApp.Repo

      use Oban.Testing, repo: MyApp.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
    end
  end

  setup tags do
    Mox.verify_on_exit!()
    Mox.stub(MyApp.PennylaneClientMock, :send_invoice, fn _path, _key -> {:ok, %{"id" => "mocked"}} end)

    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
