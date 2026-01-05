defmodule ComplianceListener.RulesEngine.Processor do
  require Logger
  import Ecto.Query

  alias ComplianceListener.Repo
  alias ComplianceListener.Compliance.{LawChange, Country, EmployeeContract, ReviewItem}

  def process_changes(change_groups) do
    Logger.info("Processing #{length(change_groups)} change groups")
    
    Enum.each(change_groups, fn changes ->
      Enum.each(changes, &process_single_change/1)
    end)
  end

  defp process_single_change(change_data) do
    country = get_or_create_country(change_data.country_code)
    
    attrs = Map.put(change_data, :country_id, country.id)
    
    case create_law_change(attrs) do
      {:ok, law_change} ->
        Logger.info("Created law change: #{law_change.title}")
        flag_affected_contracts(law_change)
      {:error, changeset} ->
        Logger.error("Failed to create law change: #{inspect(changeset.errors)}")
    end
  end

  defp get_or_create_country(country_code) do
    case Repo.get_by(Country, code: country_code) do
      nil ->
        {:ok, country} = Repo.insert(%Country{
          code: country_code,
          name: country_name(country_code)
        })
        country
      country ->
        country
    end
  end

  defp create_law_change(attrs) do
    %LawChange{}
    |> LawChange.changeset(attrs)
    |> Repo.insert()
  end

  defp flag_affected_contracts(%LawChange{} = law_change) do
    # Find all active contracts in the affected country
    contracts = from(c in EmployeeContract,
      where: c.country_id == ^law_change.country_id and c.status == "active"
    )
    |> Repo.all()

    Logger.info("Found #{length(contracts)} contracts affected by #{law_change.title}")

    # Apply specific rules based on change type
    affected_contracts = apply_matching_rules(law_change, contracts)

    # Create review items (idempotent due to unique constraint)
    Enum.each(affected_contracts, fn contract ->
      create_review_item(law_change, contract)
    end)

    affected_contracts
  end

  defp apply_matching_rules(%{change_type: "tax_rate"} = _law_change, contracts) do
    # Tax rate changes affect all employees
    contracts
  end

  defp apply_matching_rules(%{change_type: "social_contribution"} = _law_change, contracts) do
    # Social contribution changes affect all employees
    contracts
  end

  defp apply_matching_rules(%{change_type: "minimum_wage"} = law_change, contracts) do
    # Minimum wage changes only affect employees below threshold
    # For demo, we'll flag all as potentially affected
    contracts
  end

  defp apply_matching_rules(_law_change, contracts) do
    # Default: flag all contracts for review
    contracts
  end

  defp create_review_item(law_change, contract) do
    attrs = %{
      law_change_id: law_change.id,
      contract_id: contract.id,
      status: "pending",
      priority: determine_priority(law_change),
      reason: "Contract may be affected by: #{law_change.title}"
    }

    case Repo.insert(ReviewItem.changeset(%ReviewItem{}, attrs)) do
      {:ok, review} ->
        Logger.debug("Created review item for contract #{contract.employee_id}")
        {:ok, review}
      {:error, %{errors: [law_change_id: {_, [constraint: :unique, constraint_name: _]}]}} ->
        Logger.debug("Review item already exists for contract #{contract.employee_id}")
        {:ok, :already_exists}
      {:error, changeset} ->
        Logger.error("Failed to create review item: #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end

  defp determine_priority(%{change_type: "tax_rate"}), do: "high"
  defp determine_priority(%{change_type: "social_contribution"}), do: "high"
  defp determine_priority(_), do: "normal"

  defp country_name("DE"), do: "Germany"
  defp country_name("FR"), do: "France"
  defp country_name("GB"), do: "United Kingdom"
  defp country_name("ES"), do: "Spain"
  defp country_name("IT"), do: "Italy"
  defp country_name(code), do: code
end
