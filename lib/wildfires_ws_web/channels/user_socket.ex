defmodule WildfiresWsWeb.UserSocket do
  use Phoenix.Socket

  channel "fires:*", WildfiresWsWeb.FiresChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
