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
