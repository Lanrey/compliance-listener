defmodule ComplianceListenerWeb.Router do
  use ComplianceListenerWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Mock Government APIs for demo
  scope "/mock-gov", ComplianceListenerWeb do
    pipe_through :api

    get "/de", MockGovController, :germany
    get "/fr", MockGovController, :france
    get "/gb", MockGovController, :united_kingdom
    get "/rss", MockGovController, :rss_feed
  end

  # Main API
  scope "/api", ComplianceListenerWeb do
    pipe_through :api

    # Review Queue endpoints
    get "/reviews", ReviewController, :index
    get "/reviews/pending", ReviewController, :pending
    get "/reviews/:id", ReviewController, :show
    put "/reviews/:id/complete", ReviewController, :complete

    # Law Changes endpoints
    get "/law-changes", LawChangeController, :index
    get "/law-changes/recent", LawChangeController, :recent

    # Statistics endpoint
    get "/stats", StatsController, :index
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:compliance_listener, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ComplianceListenerWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
