defmodule ComplianceListenerWeb.MockGovController do
  use ComplianceListenerWeb, :controller

  @doc """
  Mock Government API endpoint for Germany
  Returns simulated regulatory changes
  """
  def germany(conn, _params) do
    changes = [
      %{
        id: "DE-2026-001",
        type: "tax_rate",
        title: "Income Tax Bracket Adjustment",
        description: "Top marginal tax rate increased from 42% to 45% for annual income above €60,000",
        previous_value: "42%",
        new_value: "45%",
        effective_date: "2026-04-01",
        published_at: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      %{
        id: "DE-2026-002",
        type: "social_contribution",
        title: "Pension Contribution Rate Change",
        description: "Employee pension contribution rate increased",
        previous_value: "9.3%",
        new_value: "9.6%",
        effective_date: "2026-07-01",
        published_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]

    json(conn, %{country: "DE", changes: changes})
  end

  @doc """
  Mock Government API endpoint for France
  """
  def france(conn, _params) do
    changes = [
      %{
        id: "FR-2026-001",
        type: "minimum_wage",
        title: "SMIC Increase",
        description: "Minimum wage adjusted for inflation",
        previous_value: "€11.65/hour",
        new_value: "€12.10/hour",
        effective_date: "2026-01-01",
        published_at: DateTime.utc_now() |> DateTime.add(-86400 * 30) |> DateTime.to_iso8601()
      }
    ]

    json(conn, %{country: "FR", changes: changes})
  end

  @doc """
  Mock Government API endpoint for United Kingdom
  """
  def united_kingdom(conn, _params) do
    changes = [
      %{
        id: "UK-2026-001",
        type: "tax_rate",
        title: "National Insurance Contribution Adjustment",
        description: "NIC rates modified for Class 1 contributions",
        previous_value: "12%",
        new_value: "13.25%",
        effective_date: "2026-04-06",
        published_at: DateTime.utc_now() |> DateTime.add(-86400 * 15) |> DateTime.to_iso8601()
      },
      %{
        id: "UK-2026-002",
        type: "holiday_entitlement",
        title: "Bank Holiday Addition",
        description: "Additional public holiday introduced",
        previous_value: "8 days",
        new_value: "9 days",
        effective_date: "2026-12-28",
        published_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
    ]

    json(conn, %{country: "GB", changes: changes})
  end

  @doc """
  Mock RSS Feed endpoint
  Returns an RSS feed of regulatory changes
  """
  def rss_feed(conn, _params) do
    rss_content = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>EU Labor Law Updates</title>
        <link>http://localhost:4000/mock-gov/rss</link>
        <description>European Union labor law changes</description>
        <item>
          <title>Spain: Paid Leave Extension</title>
          <link>http://example.com/es-2026-001</link>
          <description>Parental leave extended from 16 to 20 weeks</description>
          <pubDate>#{DateTime.utc_now() |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")}</pubDate>
          <guid>ES-2026-001</guid>
        </item>
        <item>
          <title>Italy: Remote Work Regulations</title>
          <link>http://example.com/it-2026-001</link>
          <description>New framework for hybrid and remote work arrangements</description>
          <pubDate>#{DateTime.utc_now() |> DateTime.add(-86400 * 7) |> Calendar.strftime("%a, %d %b %Y %H:%M:%S GMT")}</pubDate>
          <guid>IT-2026-001</guid>
        </item>
      </channel>
    </rss>
    """

    conn
    |> put_resp_content_type("application/rss+xml")
    |> send_resp(200, rss_content)
  end
end
