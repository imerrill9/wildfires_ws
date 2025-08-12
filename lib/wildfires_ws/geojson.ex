defmodule WildfiresWs.GeoJSON do
  @moduledoc """
  GeoJSON transformer for converting ESRI features to GeoJSON format.

  Handles transformation of ESRI point geometries to GeoJSON features
  while preserving attributes and building feature collections.
  """

  @doc """
  Returns an empty GeoJSON FeatureCollection.

  ## Examples

      iex> WildfiresWs.GeoJSON.empty_feature_collection()
      %{"type" => "FeatureCollection", "features" => []}
  """
  def empty_feature_collection do
    %{"type" => "FeatureCollection", "features" => []}
  end

  @doc """
  Transforms an ESRI feature to a GeoJSON Feature.

  Converts ESRI point geometry format to GeoJSON Point geometry and preserves
  all attributes. Guards against features missing coordinates or OBJECTID.

  ## ESRI Feature Format

      %{
        "attributes" => %{"OBJECTID" => 123, "NAME" => "Fire Name", ...},
        "geometry" => %{"x" => -120.5, "y" => 38.2}
      }

  ## GeoJSON Feature Format

      %{
        "type" => "Feature",
        "id" => 123,
        "geometry" => %{
          "type" => "Point",
          "coordinates" => [-120.5, 38.2]
        },
        "properties" => %{"NAME" => "Fire Name", ...}
      }

  ## Examples

      iex> esri_feature = %{
      ...>   "attributes" => %{"OBJECTID" => 123, "NAME" => "Fire"},
      ...>   "geometry" => %{"x" => -120.5, "y" => 38.2}
      ...> }
      iex> WildfiresWs.GeoJSON.to_geojson_feature(esri_feature)
      %{
        "type" => "Feature",
        "id" => 123,
        "geometry" => %{"type" => "Point", "coordinates" => [-120.5, 38.2]},
        "properties" => %{"NAME" => "Fire"}
      }

      iex> WildfiresWs.GeoJSON.to_geojson_feature(%{"attributes" => %{}})
      nil
  """
  def to_geojson_feature(%{
        "attributes" => %{"OBJECTID" => objectid} = attributes,
        "geometry" => %{"x" => lon, "y" => lat}
      }) when is_number(lon) and is_number(lat) and is_integer(objectid) do
    # Remove OBJECTID from properties since it becomes the feature ID
    properties = Map.delete(attributes, "OBJECTID")

    %{
      "type" => "Feature",
      "id" => objectid,
      "geometry" => %{
        "type" => "Point",
        "coordinates" => [lon, lat]
      },
      "properties" => properties
    }
  end

  # Guard clause: ignore features missing required fields
  def to_geojson_feature(_esri_feature), do: nil

  @doc """
  Builds a GeoJSON FeatureCollection from a list of GeoJSON Features.

  Filters out any nil features that were rejected by guards.

  ## Examples

      iex> features = [
      ...>   %{"type" => "Feature", "id" => 1, "geometry" => %{}, "properties" => %{}},
      ...>   nil,
      ...>   %{"type" => "Feature", "id" => 2, "geometry" => %{}, "properties" => %{}}
      ...> ]
      iex> WildfiresWs.GeoJSON.feature_collection(features)
      %{
        "type" => "FeatureCollection",
        "features" => [
          %{"type" => "Feature", "id" => 1, "geometry" => %{}, "properties" => %{}},
          %{"type" => "Feature", "id" => 2, "geometry" => %{}, "properties" => %{}}
        ]
      }
  """
  def feature_collection(features) when is_list(features) do
    valid_features = Enum.filter(features, & &1)

    %{
      "type" => "FeatureCollection",
      "features" => valid_features
    }
  end

  @doc """
  Transforms a list of ESRI features to a GeoJSON FeatureCollection.

  Convenience function that combines transformation and collection building.

  ## Examples

      iex> esri_features = [
      ...>   %{
      ...>     "attributes" => %{"OBJECTID" => 1, "NAME" => "Fire1"},
      ...>     "geometry" => %{"x" => -120.5, "y" => 38.2}
      ...>   },
      ...>   %{"attributes" => %{}} # missing OBJECTID, will be filtered out
      ...> ]
      iex> WildfiresWs.GeoJSON.from_esri_features(esri_features)
      %{
      ...>   "type" => "FeatureCollection",
      ...>   "features" => [
      ...>     %{
      ...>       "type" => "Feature",
      ...>       "id" => 1,
      ...>       "geometry" => %{"type" => "Point", "coordinates" => [-120.5, 38.2]},
      ...>       "properties" => %{"NAME" => "Fire1"}
      ...>     }
      ...>   ]
      ...> }
  """
  def from_esri_features(esri_features) when is_list(esri_features) do
    esri_features
    |> Enum.map(&to_geojson_feature/1)
    |> feature_collection()
  end
end
