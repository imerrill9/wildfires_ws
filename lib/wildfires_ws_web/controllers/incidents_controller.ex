defmodule WildfiresWsWeb.IncidentsController do
  use WildfiresWsWeb, :controller

  alias WildfiresWs.IncidentsStore
  alias WildfiresWs.GeoJSON

  def index(conn, _params) do
    incidents = IncidentsStore.get_all()

    geojson = GeoJSON.feature_collection(incidents)

    conn
    |> put_resp_content_type("application/geo+json")
    |> json(geojson)
  end
end
