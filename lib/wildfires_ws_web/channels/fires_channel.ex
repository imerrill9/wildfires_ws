defmodule WildfiresWsWeb.FiresChannel do
  use WildfiresWsWeb, :channel

  alias WildfiresWs.GeoJSON

  @impl true
  def join("fires:incidents", _payload, socket) do
    snapshot = GeoJSON.empty_feature_collection()

    push(socket, "snapshot", snapshot)
    {:ok, socket}
  end
end
