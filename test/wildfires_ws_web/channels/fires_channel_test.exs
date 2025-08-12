defmodule WildfiresWsWeb.FiresChannelTest do
  use WildfiresWsWeb.ChannelCase, async: false

  alias WildfiresWs.IncidentsStore
  alias WildfiresWs.IncidentsPoller
  alias WildfiresWs.Test.FakeArcgisClient

  setup do
    :ets.delete_all_objects(:incidents)
    :ok
  end

  test "join pushes a snapshot of current ETS incidents" do
    :ok = IncidentsStore.put(%{"OBJECTID" => 1, "geometry" => %{}, "properties" => %{}})
    :ok = IncidentsStore.put(%{"OBJECTID" => 2, "geometry" => %{}, "properties" => %{}})

    {:ok, socket} = connect(WildfiresWsWeb.UserSocket, %{})
    {:ok, _, _socket} = subscribe_and_join(socket, WildfiresWsWeb.FiresChannel, "fires:incidents")

    assert_push "snapshot", %{"type" => "FeatureCollection", "features" => features}
    assert features |> Enum.map(& &1["id"]) |> Enum.sort() == [1, 2]

    # No explicit leave needed; channel will be cleaned up by test process
  end

  defp feature(id), do: feature(id, %{"NAME" => "Fire #{id}"})

  defp feature(id, props) do
    %{
      "type" => "Feature",
      "id" => id,
      "geometry" => %{"type" => "Point", "coordinates" => [-120.0, 38.0]},
      "properties" => props
    }
  end

  test "socket receives poller snapshot broadcast on first run" do
    {:ok, socket} = connect(WildfiresWsWeb.UserSocket, %{})
    {:ok, _, _} = subscribe_and_join(socket, WildfiresWsWeb.FiresChannel, "fires:incidents")

    # Initial join triggers a snapshot push; consume it
    assert_push "snapshot", _

    start_supervised!(FakeArcgisClient)
    FakeArcgisClient.push_response([feature(101), feature(102)])

    start_supervised!({IncidentsPoller, poll_interval_ms: 5_000})

    # Expect a snapshot from poller broadcast with the two features
    assert_push "snapshot", %{"features" => features}
    assert features |> Enum.map(& &1["id"]) |> Enum.sort() == [101, 102]
  end

  test "socket receives poller delta broadcast on subsequent run" do
    {:ok, socket} = connect(WildfiresWsWeb.UserSocket, %{})
    {:ok, _, _} = subscribe_and_join(socket, WildfiresWsWeb.FiresChannel, "fires:incidents")

    # Consume channel-initiated snapshot
    assert_push "snapshot", _

    start_supervised!(FakeArcgisClient)
    # First poll: ids 1 and 2
    FakeArcgisClient.push_response([
      feature(1, %{"NAME" => "Alpha"}),
      feature(2, %{"NAME" => "Bravo"})
    ])

    start_supervised!({IncidentsPoller, poll_interval_ms: 5_000})

    # Consume poller snapshot
    assert_push "snapshot", %{"features" => features1}
    assert features1 |> Enum.map(& &1["id"]) |> Enum.sort() == [1, 2]

    # Second poll: update 1, delete 2, add 3
    FakeArcgisClient.push_response([
      feature(1, %{"NAME" => "Alpha Updated"}),
      feature(3, %{"NAME" => "Charlie"})
    ])

    IncidentsPoller.poll_now()

    assert_push "delta", %{added: added, updated: updated, deleted: deleted}

    assert added |> Enum.map(& &1["id"]) == [3]
    assert updated |> Enum.map(& &1["id"]) == [1]
    assert deleted == [2]
  end
end
