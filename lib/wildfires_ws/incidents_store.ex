defmodule WildfiresWs.IncidentsStore do
  @moduledoc """
  ETS-backed store for wildfire incident data.

  Stores incidents as GeoJSON Feature maps keyed by OBJECTID.
  """

  @doc """
  Stores a feature map in the incidents ETS table.

  The feature_map should contain an "OBJECTID" key which will be used as the ETS key.
  The stored feature will have its "id" set to the OBJECTID value to conform to GeoJSON Feature format.

  ## Examples

      iex> feature = %{"OBJECTID" => 123, "properties" => %{}, "geometry" => %{}}
      iex> WildfiresWs.IncidentsStore.put(feature)
      :ok
  """
  def put(feature_map) when is_map(feature_map) do
    object_id = Map.get(feature_map, "OBJECTID")

    if object_id do
      # Ensure the feature has "id" set to OBJECTID for GeoJSON compliance
      feature_with_id = Map.put(feature_map, "id", object_id)
      :ets.insert(:incidents, {object_id, feature_with_id})
      :ok
    else
      {:error, :missing_objectid}
    end
  end

  @doc """
  Retrieves all stored incident features as a list.

  ## Examples

      iex> WildfiresWs.IncidentsStore.get_all()
      [%{"id" => 123, "OBJECTID" => 123, ...}, ...]
  """
  def get_all do
    :incidents
    |> :ets.tab2list()
    |> Enum.map(fn {_key, feature} -> feature end)
  end

  @doc """
  Returns the count of stored incidents.

  ## Examples

      iex> WildfiresWs.IncidentsStore.count()
      42
  """
  def count do
    :ets.info(:incidents, :size)
  end
end
