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
