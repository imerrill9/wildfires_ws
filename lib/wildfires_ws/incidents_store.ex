defmodule WildfiresWs.IncidentsStore do
  @moduledoc """
  ETS-backed store for wildfire incident data.

  Stores incidents as GeoJSON Feature maps keyed by id.
  """

  @doc """
  Stores a feature map in the incidents ETS table.

  The feature_map should contain an "id" key which will be used as the ETS key.
  The feature is stored as-is since it's already in GeoJSON Feature format.

  ## Examples

      iex> feature = %{"id" => 123, "properties" => %{}, "geometry" => %{}}
      iex> WildfiresWs.IncidentsStore.put(feature)
      :ok
  """
  def put(feature_map) when is_map(feature_map) do
    id = Map.get(feature_map, "id")

    if id do
      :ets.insert(:incidents, {id, feature_map})
      :ok
    else
      {:error, :missing_id}
    end
  end

  @doc """
  Retrieves all stored incident features as a list.

  ## Examples

      iex> WildfiresWs.IncidentsStore.get_all()
      [%{"id" => 123, ...}, ...]
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
