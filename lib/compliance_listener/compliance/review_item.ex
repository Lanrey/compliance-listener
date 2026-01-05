defmodule ComplianceListener.Compliance.ReviewItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "review_queue" do
    field :status, :string
    field :priority, :string
    field :reason, :string
    field :reviewed_at, :utc_datetime
    field :reviewed_by, :string
    field :notes, :string
    field :metadata, :map

    belongs_to :law_change, ComplianceListener.Compliance.LawChange
    belongs_to :contract, ComplianceListener.Compliance.EmployeeContract

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(review_item, attrs) do
    review_item
    |> cast(attrs, [:law_change_id, :contract_id, :status, :priority, :reason, 
                    :reviewed_at, :reviewed_by, :notes, :metadata])
    |> validate_required([:law_change_id, :contract_id])
    |> unique_constraint([:law_change_id, :contract_id], name: :unique_review_per_change_contract)
  end
end
