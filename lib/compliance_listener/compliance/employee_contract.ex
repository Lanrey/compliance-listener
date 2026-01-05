defmodule ComplianceListener.Compliance.EmployeeContract do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "employee_contracts" do
    field :employee_id, :string
    field :employee_name, :string
    field :contract_type, :string
    field :tax_code, :string
    field :salary_amount, :decimal
    field :salary_currency, :string
    field :start_date, :date
    field :status, :string
    field :metadata, :map

    belongs_to :country, ComplianceListener.Compliance.Country
    has_many :reviews, ComplianceListener.Compliance.ReviewItem, foreign_key: :contract_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(employee_contract, attrs) do
    employee_contract
    |> cast(attrs, [:employee_id, :employee_name, :country_id, :contract_type, 
                    :tax_code, :salary_amount, :salary_currency, :start_date, 
                    :status, :metadata])
    |> validate_required([:employee_id, :employee_name, :country_id])
  end
end
