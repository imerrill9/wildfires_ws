defmodule WildfiresWs.GeoJSON do
  def empty_feature_collection do
    %{"type" => "FeatureCollection", "features" => []}
  end
end
