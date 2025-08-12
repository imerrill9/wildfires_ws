defmodule WildfiresWs.IncidentsPollerTest do
  use ExUnit.Case, async: false

  alias WildfiresWs.IncidentsStore
  alias WildfiresWs.IncidentsPoller
  alias WildfiresWs.Test.FakeArcgisClient

  setup do
    # Ensure fake client process is running and ETS is clean for each test
    start_supervised!(FakeArcgisClient)
    :ets.delete_all_objects(:incidents)
    FakeArcgisClient.reset()
    :ok
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

  defp wait_until(fun, timeout_ms \\ 500, interval_ms \\ 10) do
    start = System.monotonic_time(:millisecond)
    do_wait_until(fun, start, timeout_ms, interval_ms)
  end

  defp do_wait_until(fun, start_ms, timeout_ms, interval_ms) do
    if fun.() do
      :ok
    else
      if System.monotonic_time(:millisecond) - start_ms > timeout_ms do
        flunk("condition not met within #{timeout_ms}ms")
      else
        Process.sleep(interval_ms)
        do_wait_until(fun, start_ms, timeout_ms, interval_ms)
      end
    end
  end

  test "first poll populates ETS with features" do
    FakeArcgisClient.push_response([feature(1), feature(2)])

    start_supervised!({IncidentsPoller, poll_interval_ms: 1_000})

    # Wait for the immediate poll
    :ok = wait_until(fn -> IncidentsStore.count() == 2 end)

    ids = IncidentsStore.get_all() |> Enum.map(& &1["id"]) |> Enum.sort()
    assert ids == [1, 2]
  end

  test "subsequent poll applies added, updated, and deleted changes to ETS" do
    # Initial dataset: ids 1 and 2
    FakeArcgisClient.push_response([
      feature(1, %{"NAME" => "Alpha"}),
      feature(2, %{"NAME" => "Bravo"})
    ])

    start_supervised!({IncidentsPoller, poll_interval_ms: 5_000})
    :ok = wait_until(fn -> IncidentsStore.count() == 2 end)

    # Next dataset: id 1 updated, id 2 deleted, id 3 added
    FakeArcgisClient.push_response([
      feature(1, %{"NAME" => "Alpha Updated"}),
      feature(3, %{"NAME" => "Charlie"})
    ])

    IncidentsPoller.poll_now()

    # Wait specifically for presence of id 3 to ensure the second poll completed
    :ok =
      wait_until(fn ->
        IncidentsStore.get_all() |> Enum.any?(fn f -> f["id"] == 3 end)
      end)

    features_by_id =
      IncidentsStore.get_all()
      |> Map.new(fn f -> {f["id"], f} end)

    assert Map.keys(features_by_id) |> Enum.sort() == [1, 3]
    assert get_in(features_by_id[1], ["properties", "NAME"]) == "Alpha Updated"
    assert get_in(features_by_id[3], ["properties", "NAME"]) == "Charlie"
  end

  test "no-op poll leaves ETS unchanged" do
    FakeArcgisClient.push_response([feature(10)])
    start_supervised!({IncidentsPoller, poll_interval_ms: 5_000})
    :ok = wait_until(fn -> IncidentsStore.count() == 1 end)

    FakeArcgisClient.push_response([feature(10)])
    IncidentsPoller.poll_now()

    :ok = wait_until(fn -> IncidentsStore.count() == 1 end)
    ids = IncidentsStore.get_all() |> Enum.map(& &1["id"]) |> Enum.sort()
    assert ids == [10]
  end
end
