defmodule ComplianceListener.Repo.Migrations.CreateLawChanges do
  use Ecto.Migration

  def change do
    create table(:law_changes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :country_id, references(:countries, type: :binary_id, on_delete: :nothing), null: false
      add :change_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :source_url, :string
      add :previous_value, :string
      add :new_value, :string
      add :effective_date, :date
      add :detected_at, :utc_datetime, null: false
      add :processed, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime)
    end

    create index(:law_changes, [:country_id])
    create index(:law_changes, [:change_type])
    create index(:law_changes, [:effective_date])
    create index(:law_changes, [:processed])
    create index(:law_changes, [:detected_at])
  end
end
