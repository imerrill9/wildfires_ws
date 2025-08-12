defmodule WildfiresWs.IncidentsStoreTest do
  use ExUnit.Case, async: true

  alias WildfiresWs.IncidentsStore

  setup do
    :ets.delete_all_objects(:incidents)
    :ok
  end

  test "put inserts by OBJECTID and sets id" do
    :ok = IncidentsStore.put(%{"OBJECTID" => 42, "properties" => %{}, "geometry" => %{}})
    assert IncidentsStore.count() == 1

    [feature] = IncidentsStore.get_all()
    assert feature["id"] == 42
    assert feature["OBJECTID"] == 42
  end

  test "put without OBJECTID returns error" do
    assert {:error, :missing_objectid} = IncidentsStore.put(%{"geometry" => %{}})
    assert IncidentsStore.count() == 0
  end
end
