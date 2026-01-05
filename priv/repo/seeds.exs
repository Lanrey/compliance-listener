# Script for populating the database
alias ComplianceListener.Repo
alias ComplianceListener.Compliance.{Country, EmployeeContract, LawChange, ReviewItem}

# Clear existing data (for development)
Repo.delete_all(ReviewItem)
Repo.delete_all(LawChange)
Repo.delete_all(EmployeeContract)
Repo.delete_all(Country)

# Create countries
countries = [
  %{code: "DE", name: "Germany", region: "Europe", tax_system: "Progressive"},
  %{code: "FR", name: "France", region: "Europe", tax_system: "Progressive"},
  %{code: "GB", name: "United Kingdom", region: "Europe", tax_system: "Progressive"},
  %{code: "ES", name: "Spain", region: "Europe", tax_system: "Progressive"},
  %{code: "IT", name: "Italy", region: "Europe", tax_system: "Progressive"}
]

inserted_countries = Enum.map(countries, fn country_data ->
  {:ok, country} = Repo.insert(%Country{
    code: country_data.code,
    name: country_data.name,
    region: country_data.region,
    tax_system: country_data.tax_system
  })
  country
end)

IO.puts("✓ Created #{length(inserted_countries)} countries")

# Get countries for reference
de = Enum.find(inserted_countries, &(&1.code == "DE"))
fr = Enum.find(inserted_countries, &(&1.code == "FR"))
gb = Enum.find(inserted_countries, &(&1.code == "GB"))

# Create employee contracts
employee_contracts = [
  # Germany
  %{employee_id: "EMP001", employee_name: "Hans Mueller", country_id: de.id, 
    contract_type: "full_time", tax_code: "DE-STD", salary_amount: Decimal.new("65000"),
    salary_currency: "EUR", start_date: ~D[2024-01-15], status: "active"},
  %{employee_id: "EMP002", employee_name: "Anna Schmidt", country_id: de.id,
    contract_type: "full_time", tax_code: "DE-STD", salary_amount: Decimal.new("72000"),
    salary_currency: "EUR", start_date: ~D[2023-06-01], status: "active"},
  %{employee_id: "EMP003", employee_name: "Klaus Weber", country_id: de.id,
    contract_type: "part_time", tax_code: "DE-STD", salary_amount: Decimal.new("35000"),
    salary_currency: "EUR", start_date: ~D[2024-03-10], status: "active"},
  
  # France
  %{employee_id: "EMP004", employee_name: "Marie Dubois", country_id: fr.id,
    contract_type: "full_time", tax_code: "FR-STD", salary_amount: Decimal.new("55000"),
    salary_currency: "EUR", start_date: ~D[2023-09-01], status: "active"},
  %{employee_id: "EMP005", employee_name: "Pierre Martin", country_id: fr.id,
    contract_type: "full_time", tax_code: "FR-STD", salary_amount: Decimal.new("48000"),
    salary_currency: "EUR", start_date: ~D[2024-02-15], status: "active"},
  
  # United Kingdom
  %{employee_id: "EMP006", employee_name: "James Smith", country_id: gb.id,
    contract_type: "full_time", tax_code: "GB-PAYE", salary_amount: Decimal.new("52000"),
    salary_currency: "GBP", start_date: ~D[2023-11-01], status: "active"},
  %{employee_id: "EMP007", employee_name: "Emma Wilson", country_id: gb.id,
    contract_type: "contractor", tax_code: "GB-IR35", salary_amount: Decimal.new("65000"),
    salary_currency: "GBP", start_date: ~D[2024-01-10], status: "active"},
  %{employee_id: "EMP008", employee_name: "Oliver Brown", country_id: gb.id,
    contract_type: "full_time", tax_code: "GB-PAYE", salary_amount: Decimal.new("58000"),
    salary_currency: "GBP", start_date: ~D[2023-07-15], status: "active"}
]

inserted_contracts = Enum.map(employee_contracts, fn contract_data ->
  {:ok, contract} = Repo.insert(%EmployeeContract{
    employee_id: contract_data.employee_id,
    employee_name: contract_data.employee_name,
    country_id: contract_data.country_id,
    contract_type: contract_data.contract_type,
    tax_code: contract_data.tax_code,
    salary_amount: contract_data.salary_amount,
    salary_currency: contract_data.salary_currency,
    start_date: contract_data.start_date,
    status: contract_data.status
  })
  contract
end)

IO.puts("✓ Created #{length(inserted_contracts)} employee contracts")

# Create sample law changes
law_changes = [
  %{country_id: de.id, change_type: "tax_rate", 
    title: "Income Tax Bracket Adjustment",
    description: "Top marginal tax rate increased for high earners",
    previous_value: "42%", new_value: "45%",
    effective_date: ~D[2026-04-01], detected_at: DateTime.utc_now() |> DateTime.truncate(:second)},
  
  %{country_id: fr.id, change_type: "minimum_wage",
    title: "SMIC Increase",
    description: "Minimum wage adjusted for inflation",
    previous_value: "€11.65/hour", new_value: "€12.10/hour",
    effective_date: ~D[2026-01-01], detected_at: DateTime.utc_now() |> DateTime.truncate(:second)},
  
  %{country_id: gb.id, change_type: "social_contribution",
    title: "National Insurance Contribution Adjustment",
    description: "NIC rates modified for Class 1 contributions",
    previous_value: "12%", new_value: "13.25%",
    effective_date: ~D[2026-04-06], detected_at: DateTime.utc_now() |> DateTime.truncate(:second)}
]

inserted_law_changes = Enum.map(law_changes, fn law_change_data ->
  {:ok, law_change} = Repo.insert(%LawChange{
    country_id: law_change_data.country_id,
    change_type: law_change_data.change_type,
    title: law_change_data.title,
    description: law_change_data.description,
    previous_value: law_change_data.previous_value,
    new_value: law_change_data.new_value,
    effective_date: law_change_data.effective_date,
    detected_at: law_change_data.detected_at,
    processed: false
  })
  law_change
end)

IO.puts("✓ Created #{length(inserted_law_changes)} law changes")

# Create review items for German contracts (tax rate change)
de_law_change = Enum.find(inserted_law_changes, &(&1.country_id == de.id))
de_contracts = Enum.filter(inserted_contracts, &(&1.country_id == de.id))

de_reviews = Enum.map(de_contracts, fn contract ->
  {:ok, review} = Repo.insert(%ReviewItem{
    law_change_id: de_law_change.id,
    contract_id: contract.id,
    status: "pending",
    priority: "high",
    reason: "Contract affected by: #{de_law_change.title}"
  })
  review
end)

IO.puts("✓ Created #{length(de_reviews)} review items for German contracts")

# Create review items for GB contracts
gb_law_change = Enum.find(inserted_law_changes, &(&1.country_id == gb.id))
gb_contracts = Enum.filter(inserted_contracts, &(&1.country_id == gb.id))

gb_reviews = Enum.map(gb_contracts, fn contract ->
  {:ok, review} = Repo.insert(%ReviewItem{
    law_change_id: gb_law_change.id,
    contract_id: contract.id,
    status: "pending",
    priority: "high",
    reason: "Contract affected by: #{gb_law_change.title}"
  })
  review
end)

IO.puts("✓ Created #{length(gb_reviews)} review items for UK contracts")

IO.puts("\n✅ Seed data created successfully!")
IO.puts("   - #{length(inserted_countries)} countries")
IO.puts("   - #{length(inserted_contracts)} employee contracts")
IO.puts("   - #{length(inserted_law_changes)} law changes")
IO.puts("   - #{length(de_reviews) + length(gb_reviews)} review items")
