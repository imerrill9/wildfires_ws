defmodule WildfiresWsWeb.HealthController do
  use WildfiresWsWeb, :controller

  alias WildfiresWs.IncidentsPoller

  def show(conn, _params) do
    metrics = IncidentsPoller.metrics()

    json(conn, %{
      status: "ok",
      last_poll_at: metrics.last_poll_at,
      next_poll_in_ms: metrics.next_poll_in_ms,
      incident_count: metrics.incident_count
    })
  end
end
