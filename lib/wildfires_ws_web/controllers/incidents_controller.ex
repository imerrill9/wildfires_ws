defmodule WildfiresWsWeb.IncidentsController do
  use WildfiresWsWeb, :controller

  alias WildfiresWs.IncidentsStore

  def index(conn, _params) do
    incidents = IncidentsStore.get_all()

    geojson = %{
      type: "FeatureCollection",
      features: incidents
    }

    conn
    |> put_resp_content_type("application/geo+json")
    |> json(geojson)
  end
end
