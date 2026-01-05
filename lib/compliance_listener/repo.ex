defmodule ComplianceListener.Repo do
  use Ecto.Repo,
    otp_app: :compliance_listener,
    adapter: Ecto.Adapters.Postgres
end
