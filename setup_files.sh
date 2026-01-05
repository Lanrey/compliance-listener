#!/bin/bash

# Create Polling GenServer
cat > lib/compliance_listener/polling/source_poller.ex << 'EOF'
defmodule ComplianceListener.Polling.SourcePoller do
  use GenServer
  require Logger

  alias ComplianceListener.Polling.SourceFetcher
  alias ComplianceListener.RulesEngine.Processor

  @poll_interval :timer.minutes(5)

  def start_link(sources) do
    GenServer.start_link(__MODULE__, sources, name: __MODULE__)
  end

  @impl true
  def init(sources) do
    schedule_poll()
    {:ok, %{sources: sources, last_poll: nil}}
  end

  @impl true
  def handle_info(:poll, state) do
    Logger.info("Starting concurrent poll of #{length(state.sources)} sources")
    
    results = SourceFetcher.fetch_all(state.sources)
    Processor.process_changes(results)
    
    schedule_poll()
    {:noreply, %{state | last_poll: DateTime.utc_now()}}
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval)
  end
end
EOF

# Create Source Fetcher with Task.async_stream
cat > lib/compliance_listener/polling/source_fetcher.ex << 'EOF'
defmodule ComplianceListener.Polling.SourceFetcher do
  require Logger

  @max_concurrency 10
  @timeout :timer.seconds(30)

  def fetch_all(sources) do
    sources
    |> Task.async_stream(&fetch_source/1, 
      max_concurrency: @max_concurrency,
      timeout: @timeout,
      on_timeout: :kill_task
    )
    |> Enum.to_list()
    |> Enum.filter(fn
      {:ok, {:ok, _}} -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, {:ok, data}} -> data end)
  end

  defp fetch_source(%{type: :api, url: url, country_code: code}) do
    Logger.debug("Fetching API source: #{url}")
    
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_api_response(body, code)}
      {:error, reason} ->
        Logger.error("Failed to fetch #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_source(%{type: :rss, url: url}) do
    Logger.debug("Fetching RSS source: #{url}")
    
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, parse_rss_response(body)}
      {:error, reason} ->
        Logger.error("Failed to fetch RSS #{url}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_api_response(%{"changes" => changes, "country" => country}, _code) do
    Enum.map(changes, fn change ->
      %{
        country_code: country,
        change_type: change["type"],
        title: change["title"],
        description: change["description"],
        previous_value: change["previous_value"],
        new_value: change["new_value"],
        effective_date: parse_date(change["effective_date"]),
        source_url: change["source_url"],
        detected_at: DateTime.utc_now()
      }
    end)
  end

  defp parse_rss_response(rss_body) when is_binary(rss_body) do
    # Simple RSS parsing - in production use a proper RSS library
    []
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
EOF

# Create Rules Engine Processor
cat > lib/compliance_listener/rules_engine/processor.ex << 'EOF'
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
EOF

echo "Core polling and rules engine files created!"
