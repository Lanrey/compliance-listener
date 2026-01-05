defmodule ComplianceListenerWeb.LawChangeController do
  use ComplianceListenerWeb, :controller
  import Ecto.Query
  alias ComplianceListener.Repo
  alias ComplianceListener.Compliance.LawChange

  def index(conn, params) do
    country = Map.get(params, "country")
    
    query = from l in LawChange,
      order_by: [desc: l.detected_at],
      preload: [:country]

    query = if country do
      from l in query, join: c in assoc(l, :country), where: c.code == ^country
    else
      query
    end

    law_changes = Repo.all(query) |> Enum.take(50)
    json(conn, %{law_changes: format_law_changes(law_changes)})
  end

  def recent(conn, _params) do
    seven_days_ago = DateTime.utc_now() |> DateTime.add(-7, :day)

    law_changes = from(l in LawChange,
      where: l.detected_at >= ^seven_days_ago,
      order_by: [desc: l.detected_at],
      preload: [:country]
    )
    |> Repo.all()

    json(conn, %{recent_changes: format_law_changes(law_changes), count: length(law_changes)})
  end

  defp format_law_changes(law_changes) do
    Enum.map(law_changes, fn lc ->
      %{
        id: lc.id,
        title: lc.title,
        description: lc.description,
        change_type: lc.change_type,
        previous_value: lc.previous_value,
        new_value: lc.new_value,
        effective_date: lc.effective_date,
        detected_at: lc.detected_at,
        processed: lc.processed,
        country: if(lc.country, do: %{
          code: lc.country.code,
          name: lc.country.name
        })
      }
    end)
  end
end
