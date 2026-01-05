defmodule ComplianceListener.Repo.Migrations.CreateEmployeeContracts do
  use Ecto.Migration

  def change do
    create table(:employee_contracts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :employee_id, :string, null: false
      add :employee_name, :string, null: false
      add :country_id, references(:countries, type: :binary_id, on_delete: :nothing), null: false
      add :contract_type, :string
      add :tax_code, :string
      add :salary_amount, :decimal, precision: 15, scale: 2
      add :salary_currency, :string
      add :start_date, :date
      add :status, :string, default: "active"
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:employee_contracts, [:employee_id])
    create index(:employee_contracts, [:country_id])
    create index(:employee_contracts, [:status])
    create index(:employee_contracts, [:tax_code])
  end
end
