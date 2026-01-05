defmodule ComplianceListener.Compliance.Country do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "countries" do
    field :code, :string
    field :name, :string
    field :region, :string
    field :tax_system, :string
    field :metadata, :map

    has_many :law_changes, ComplianceListener.Compliance.LawChange
    has_many :employee_contracts, ComplianceListener.Compliance.EmployeeContract

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(country, attrs) do
    country
    |> cast(attrs, [:code, :name, :region, :tax_system, :metadata])
    |> validate_required([:code, :name])
    |> unique_constraint(:code)
  end
end
