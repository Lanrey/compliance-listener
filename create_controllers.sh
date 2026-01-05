#!/bin/bash

# Create Review Controller
cat > lib/compliance_listener_web/controllers/review_controller.ex << 'EOF'
defmodule ComplianceListenerWeb.ReviewController do
  use ComplianceListenerWeb, :controller
  import Ecto.Query
  alias ComplianceListener.Repo
  alias ComplianceListener.Compliance.ReviewItem

  def index(conn, params) do
    page = Map.get(params, "page", "1") |> String.to_integer()
    per_page = 20
    offset = (page - 1) * per_page

    reviews = from(r in ReviewItem,
      order_by: [desc: r.inserted_at],
      limit: ^per_page,
      offset: ^offset,
      preload: [:law_change, :contract]
    )
    |> Repo.all()

    json(conn, %{reviews: format_reviews(reviews), page: page})
  end

  def pending(conn, params) do
    country = Map.get(params, "country")

    query = from r in ReviewItem,
      where: r.status == "pending",
      order_by: [desc: r.priority, desc: r.inserted_at],
      preload: [:law_change, contract: :country]

    query = if country do
      from [r, contract: c] in query, where: c.country_id == ^country
    else
      query
    end

    reviews = Repo.all(query)
    json(conn, %{pending_reviews: format_reviews(reviews), count: length(reviews)})
  end

  def show(conn, %{"id" => id}) do
    case Repo.get(ReviewItem, id) |> Repo.preload([:law_change, contract: :country]) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Review not found"})
      review ->
        json(conn, %{review: format_review(review)})
    end
  end

  def complete(conn, %{"id" => id}) do
    case Repo.get(ReviewItem, id) do
      nil -> 
        conn
        |> put_status(:not_found)
        |> json(%{error: "Review not found"})
      review ->
        changeset = ReviewItem.changeset(review, %{
          status: "completed",
          reviewed_at: DateTime.utc_now(),
          reviewed_by: "system"
        })

        case Repo.update(changeset) do
          {:ok, updated} ->
            json(conn, %{review: format_review(updated), message: "Review completed"})
          {:error, changeset} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{errors: format_changeset_errors(changeset)})
        end
    end
  end

  defp format_reviews(reviews) do
    Enum.map(reviews, &format_review/1)
  end

  defp format_review(review) do
    %{
      id: review.id,
      status: review.status,
      priority: review.priority,
      reason: review.reason,
      reviewed_at: review.reviewed_at,
      reviewed_by: review.reviewed_by,
      law_change: if(review.law_change, do: %{
        id: review.law_change.id,
        title: review.law_change.title,
        change_type: review.law_change.change_type,
        effective_date: review.law_change.effective_date
      }),
      contract: if(review.contract, do: %{
        id: review.contract.id,
        employee_id: review.contract.employee_id,
        employee_name: review.contract.employee_name,
        country: if(review.contract.country, do: %{
          code: review.contract.country.code,
          name: review.contract.country.name
        })
      }),
      created_at: review.inserted_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
EOF

# Create Law Change Controller
cat > lib/compliance_listener_web/controllers/law_change_controller.ex << 'EOF'
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
EOF

# Create Stats Controller
cat > lib/compliance_listener_web/controllers/stats_controller.ex << 'EOF'
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
EOF

echo "API Controllers created!"
