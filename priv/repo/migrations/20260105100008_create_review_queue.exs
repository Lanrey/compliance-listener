defmodule ComplianceListener.Repo.Migrations.CreateReviewQueue do
  use Ecto.Migration

  def change do
    create table(:review_queue, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :law_change_id, references(:law_changes, type: :binary_id, on_delete: :nothing), null: false
      add :contract_id, references(:employee_contracts, type: :binary_id, on_delete: :nothing), null: false
      add :status, :string, default: "pending", null: false
      add :priority, :string, default: "normal"
      add :reason, :text
      add :reviewed_at, :utc_datetime
      add :reviewed_by, :string
      add :notes, :text
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:review_queue, [:law_change_id])
    create index(:review_queue, [:contract_id])
    create index(:review_queue, [:status])
    create index(:review_queue, [:priority])
    create unique_index(:review_queue, [:law_change_id, :contract_id], name: :unique_review_per_change_contract)
  end
end
