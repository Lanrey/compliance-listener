defmodule ComplianceListener.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Define polling sources
    sources = [
      %{type: :api, url: "http://localhost:4000/mock-gov/de", country_code: "DE"},
      %{type: :api, url: "http://localhost:4000/mock-gov/fr", country_code: "FR"},
      %{type: :api, url: "http://localhost:4000/mock-gov/gb", country_code: "GB"},
      %{type: :rss, url: "http://localhost:4000/mock-gov/rss", country_code: nil}
    ]

    children = [
      ComplianceListenerWeb.Telemetry,
      ComplianceListener.Repo,
      {DNSCluster, query: Application.get_env(:compliance_listener, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ComplianceListener.PubSub},
      # Start the polling GenServer
      {ComplianceListener.Polling.SourcePoller, sources},
      # Start to serve requests, typically the last entry
      ComplianceListenerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ComplianceListener.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ComplianceListenerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
