defmodule WildfiresWsWeb.FiresChannel do
  use WildfiresWsWeb, :channel

  alias WildfiresWs.GeoJSON
  alias WildfiresWs.IncidentsStore

  @impl true
  def join("fires:incidents", _payload, socket) do
    # Per Phoenix guidelines, push after join completes
    send(self(), :after_join)
    {:ok, socket}
  end

  @impl true
  def handle_info(:after_join, socket) do
    snapshot =
      IncidentsStore.get_all()
      |> GeoJSON.feature_collection()

    push(socket, "snapshot", snapshot)
    {:noreply, socket}
  end
end
