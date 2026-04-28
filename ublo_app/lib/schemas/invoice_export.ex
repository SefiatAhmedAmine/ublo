defmodule MyApp.Schemas.InvoiceExport do
  @moduledoc """
  Audit record for Pennylane invoice export attempts.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @statuses [:success, :failed]

  schema "invoice_exports" do
    field(:foreign_id, :string)
    field(:status, Ecto.Enum, values: @statuses)
    field(:attempts, :integer)
    field(:error, :string)
    field(:exported_at, :utc_datetime)

    belongs_to(:invoice, MyApp.Schemas.Invoice)

    timestamps()
  end

  @cast_fields [:invoice_id, :foreign_id, :status, :attempts, :error, :exported_at]
  @required_fields [:invoice_id, :status, :attempts]

  def changeset(invoice_export, attrs \\ %{}) do
    invoice_export
    |> cast(attrs, @cast_fields)
    |> validate_required(@required_fields)
    |> validate_number(:attempts, greater_than: 0)
    |> validate_failed_has_error()
    |> unique_constraint([:invoice_id, :attempts], error_key: :attempts)
  end

  defp validate_failed_has_error(changeset) do
    case get_field(changeset, :status) do
      :failed -> validate_required(changeset, [:error])
      _ -> changeset
    end
  end
end
