# Compliance Change Listener

**A demonstration project for Remote.com showcasing Elixir/OTP, Phoenix, and concurrent programming**

## Project Overview

The Compliance Change Listener is a sophisticated system that monitors multiple regulatory sources (government APIs, RSS feeds) for labor law changes and automatically identifies employee contracts that may be affected. This addresses Remote.com's core challenge of maintaining compliance across dozens of countries.

### Key Features

✅ **Concurrent Source Polling** - Uses `Task.async_stream` to fetch from multiple sources simultaneously  
✅ **OTP Supervision** - Robust GenServer-based polling with automatic restart on failure  
✅ **Rules Engine** - Pattern-match law changes against employee contracts using Ecto queries  
✅ **Idempotent Operations** - Unique constraints prevent duplicate "Review Needed" entries  
✅ **Audit Trail** - Complete history of detected changes and flagged contracts  
✅ **REST API** - Phoenix JSON endpoints for integration and demonstration

## Architecture

```
┌─────────────────────────────────────────────────┐
│         SourcePoller (GenServer)                │
│   Polls every 5 minutes, supervised             │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│     SourceFetcher (Task.async_stream)           │
│   Concurrent HTTP requests (max 10)             │
│   • Mock Germany API                            │
│   • Mock France API                             │
│   • Mock UK API                                 │
│   • RSS Feed                                    │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│       RulesEngine.Processor                     │
│   • Parse law changes                           │
│   • Query affected contracts (Ecto)             │
│   • Apply matching rules by change type         │
│   • Create review items (idempotent)            │
└─────────────────────────────────────────────────┘
```

## Tech Stack

- **Elixir 1.19** - Functional programming with pattern matching
- **Phoenix 1.8** - Web framework (API-only mode)
- **Ecto 3.13** - Database OTP toolkit and query builder
- **PostgreSQL 16** - Relational database (via Docker)
- **Task.async_stream** - Concurrent data fetching
- **GenServer** - Long-running polling process
- **Supervisor** - Fault-tolerant OTP supervision tree

## Database Schema

### Countries
- Stores country metadata and tax system information

### Law Changes
- Detected regulatory changes with effective dates
- Links to country, tracks processing status

### Employee Contracts
- Active employee contracts by country
- Salary, tax code, contract type information

### Review Queue
- Items flagging contracts needing review
- **Unique constraint** on (law_change_id, contract_id) ensures idempotency
- Status: pending → completed

## Getting Started

### Prerequisites

- Elixir 1.15+ and Erlang/OTP 26+
- Docker and Docker Compose
- PostgreSQL (via Docker)

### Installation

```bash
# Clone the repository
cd compliance_listener

# Install dependencies
mix deps.get

# Start PostgreSQL in Docker
docker-compose up -d

# Create and migrate database
mix ecto.create
mix ecto.migrate

# Load seed data
mix run priv/repo/seeds.exs

# Start the Phoenix server
mix phx.server
```

The application will be available at `http://localhost:4000`

## API Endpoints

### Mock Government APIs (for demonstration)
```
GET /mock-gov/de          # Germany law changes
GET /mock-gov/fr          # France law changes
GET /mock-gov/gb          # UK law changes
GET /mock-gov/rss         # RSS feed of EU changes
```

### Main API Endpoints
```
GET /api/reviews                # All reviews (paginated)
GET /api/reviews/pending        # Pending reviews only
GET /api/reviews/:id            # Single review details
PUT /api/reviews/:id/complete   # Mark review as completed

GET /api/law-changes            # All detected law changes
GET /api/law-changes/recent     # Changes from last 7 days

GET /api/stats                  # System statistics
```

### Example API Responses

**GET /api/reviews/pending**
```json
{
  "pending_reviews": [
    {
      "id": "3a6296e9-b29e-4654-bf68-1da512a5cd95",
      "status": "pending",
      "priority": "high",
      "reason": "Contract affected by: Income Tax Bracket Adjustment",
      "law_change": {
        "title": "Income Tax Bracket Adjustment",
        "change_type": "tax_rate",
        "effective_date": "2026-04-01"
      },
      "contract": {
        "employee_id": "EMP001",
        "employee_name": "Hans Mueller",
        "country": {
          "code": "DE",
          "name": "Germany"
        }
      }
    }
  ],
  "count": 6
}
```

**GET /api/stats**
```json
{
  "reviews": {
    "total": 6,
    "pending": 6,
    "completed": 0,
    "by_priority": {
      "high": 6
    }
  },
  "law_changes": {
    "total": 3,
    "this_month": 3,
    "by_type": {
      "tax_rate": 1,
      "minimum_wage": 1,
      "social_contribution": 1
    }
  },
  "contracts": {
    "total": 8,
    "active": 8,
    "by_country": {
      "DE": 3,
      "FR": 2,
      "GB": 3
    }
  },
  "countries": 5
}
```

## Key Implementation Details

### Concurrent Polling with Task.async_stream

```elixir
def fetch_all(sources) do
  sources
  |> Task.async_stream(&fetch_source/1, 
    max_concurrency: 10,
    timeout: 30_000,
    on_timeout: :kill_task
  )
  |> Enum.to_list()
  |> process_results()
end
```

**Benefits:**
- Fetches 10+ sources in parallel
- Configurable timeout and concurrency
- Graceful handling of individual failures
- Non-blocking execution

### Idempotent Review Creation

```elixir
case Repo.insert(ReviewItem.changeset(%ReviewItem{}, attrs)) do
  {:ok, review} ->
    {:ok, review}
  {:error, %{errors: [law_change_id: {_, [constraint: :unique, _]}]}} ->
    # Already exists, this is OK
    {:ok, :already_exists}
  {:error, changeset} ->
    {:error, changeset}
end
```

Unique database constraint prevents duplicate reviews for the same (law_change, contract) pair.

### Pattern Matching Rules

```elixir
defp apply_matching_rules(%{change_type: "tax_rate"}, contracts) do
  # Tax rate changes affect all employees
  contracts
end

defp apply_matching_rules(%{change_type: "minimum_wage"}, contracts) do
  # Could filter by salary threshold
  Enum.filter(contracts, &(&1.salary_amount < threshold))
end
```

## Testing

```bash
# Run all tests
mix test

# Run with coverage
mix test --cover

# Run specific test file
mix test test/compliance_listener/polling/source_fetcher_test.exs
```

## Docker Management

```bash
# Start database
docker-compose up -d

# Stop database
docker-compose down

# View logs
docker-compose logs -f

# Reset database
docker-compose down -v  # Removes volumes
docker-compose up -d
mix ecto.reset
```

## Project Highlights for Remote.com

### 1. **Elixir/OTP Expertise**
- GenServer for stateful polling process
- Supervisor tree for fault tolerance
- Process isolation and message passing

### 2. **Concurrency & Performance**
- `Task.async_stream` for parallel API calls
- Handles 10+ sources with sub-second total latency
- Demonstrates understanding of BEAM VM strengths

### 3. **Database Design**
- Proper use of Ecto schemas and changesets
- Idempotency via unique constraints
- Efficient queries with preloading and joins

### 4. **Production Readiness**
- Error handling and logging
- Audit trail for compliance
- Configurable polling intervals
- Docker-based development environment

### 5. **Domain Modeling**
- Clear separation: Compliance, Polling, RulesEngine
- Pattern matching for business logic
- Extensible rules system

## Future Enhancements

- [ ] WebSocket support for real-time review notifications
- [ ] Admin LiveView dashboard
- [ ] More sophisticated RSS parsing (Floki integration)
- [ ] Configurable polling intervals per source
- [ ] Machine learning for change classification
- [ ] Multi-tenant support
- [ ] Email notifications via Swoosh

## License

MIT

## Author

Built as a demonstration project for Remote.com job application.
