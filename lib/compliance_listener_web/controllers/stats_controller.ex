defmodule ComplianceListenerWeb.StatsController do
  use ComplianceListenerWeb, :controller
  import Ecto.Query
  alias ComplianceListener.Repo
  alias ComplianceListener.Compliance.{ReviewItem, LawChange, EmployeeContract, Country}

  def index(conn, _params) do
    stats = %{
      reviews: %{
        total: Repo.aggregate(ReviewItem, :count),
        pending: from(r in ReviewItem, where: r.status == "pending") |> Repo.aggregate(:count),
        completed: from(r in ReviewItem, where: r.status == "completed") |> Repo.aggregate(:count),
        by_priority: priority_breakdown()
      },
      law_changes: %{
        total: Repo.aggregate(LawChange, :count),
        this_month: recent_law_changes(30),
        by_type: law_changes_by_type()
      },
      contracts: %{
        total: Repo.aggregate(EmployeeContract, :count),
        active: from(c in EmployeeContract, where: c.status == "active") |> Repo.aggregate(:count),
        by_country: contracts_by_country()
      },
      countries: Repo.aggregate(Country, :count)
    }

    json(conn, stats)
  end

  defp priority_breakdown do
    Repo.all(from r in ReviewItem,
      where: r.status == "pending",
      group_by: r.priority,
      select: {r.priority, count(r.id)}
    )
    |> Enum.into(%{})
  end

  defp recent_law_changes(days) do
    date = DateTime.utc_now() |> DateTime.add(-days, :day)
    from(l in LawChange, where: l.detected_at >= ^date) |> Repo.aggregate(:count)
  end

  defp law_changes_by_type do
    Repo.all(from l in LawChange,
      group_by: l.change_type,
      select: {l.change_type, count(l.id)}
    )
    |> Enum.into(%{})
  end

  defp contracts_by_country do
    Repo.all(from c in EmployeeContract,
      join: country in assoc(c, :country),
      where: c.status == "active",
      group_by: country.code,
      select: {country.code, count(c.id)}
    )
    |> Enum.into(%{})
  end
end
