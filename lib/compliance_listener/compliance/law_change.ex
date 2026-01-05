defmodule ComplianceListener.Compliance.LawChange do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "law_changes" do
    field :change_type, :string
    field :title, :string
    field :description, :string
    field :source_url, :string
    field :previous_value, :string
    field :new_value, :string
    field :effective_date, :date
    field :detected_at, :utc_datetime
    field :processed, :boolean, default: false
    field :metadata, :map

    belongs_to :country, ComplianceListener.Compliance.Country
    has_many :reviews, ComplianceListener.Compliance.ReviewItem

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(law_change, attrs) do
    law_change
    |> cast(attrs, [:country_id, :change_type, :title, :description, :source_url, 
                    :previous_value, :new_value, :effective_date, :detected_at, 
                    :processed, :metadata])
    |> validate_required([:country_id, :change_type, :title, :detected_at])
  end
end
