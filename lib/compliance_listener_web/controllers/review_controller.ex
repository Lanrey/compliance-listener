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
