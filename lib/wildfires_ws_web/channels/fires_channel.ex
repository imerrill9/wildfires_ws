defmodule WildfiresWsWeb.FiresChannel do
  use WildfiresWsWeb, :channel

  alias WildfiresWs.GeoJSON
  alias WildfiresWs.IncidentsStore

  @impl true
  def join("fires:incidents", _payload, socket) do
    snapshot =
      IncidentsStore.get_all()
      |> GeoJSON.feature_collection()

    push(socket, "snapshot", snapshot)
    {:ok, socket}
  end
end
