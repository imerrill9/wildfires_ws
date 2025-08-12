defmodule WildfiresWs.IncidentsPoller do
  @moduledoc """
  GenServer that polls for wildfire incidents and broadcasts changes.

  Fetches incidents as GeoJSON Features, computes diffs against ETS store,
  and broadcasts snapshot/delta events.
  """

  use GenServer
  require Logger

  alias WildfiresWs.ArcgisClient
  alias WildfiresWs.GeoJSON
  alias WildfiresWs.IncidentsStore

  @default_poll_interval_ms 30_000

  ## Client API

  @doc """
  Starts the incidents poller GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Triggers an immediate poll for incidents.
  """
  def poll_now do
    GenServer.cast(__MODULE__, :poll)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    poll_interval_ms = Keyword.get(opts, :poll_interval_ms, @default_poll_interval_ms)

    state = %{
      poll_interval_ms: poll_interval_ms,
      first_run: true,
      last_poll_at: nil,
      next_poll_timer_ref: nil
    }

    # Schedule immediate poll
    Process.send_after(self(), :poll, 0)

    Logger.info("IncidentsPoller started with poll interval: #{poll_interval_ms}ms")
    {:ok, state}
  end

  @impl true
  def handle_info(:poll, state) do
    case poll_and_process() do
      {:ok, event_data} ->
        broadcast_event(event_data, state.first_run)

      {:error, reason} ->
        Logger.error("Failed to poll incidents: #{inspect(reason)}")
    end

    # Schedule next poll
    next_ref = Process.send_after(self(), :poll, state.poll_interval_ms)

    {:noreply,
     %{state | first_run: false, last_poll_at: DateTime.utc_now(), next_poll_timer_ref: next_ref}}
  end

  @impl true
  def handle_cast(:poll, state) do
    send(self(), :poll)
    {:noreply, state}
  end

  ## Private Functions

  defp poll_and_process do
    client_mod = Application.get_env(:wildfires_ws, :arcgis_client, ArcgisClient)

    case client_mod.fetch_all_incidents() do
      {:ok, features} ->
        Logger.debug("Fetched #{length(features)} features")
        geojson_features = transform_features(features)

        {added, updated, deleted} = compute_diffs(geojson_features)

        # Update ETS store
        update_ets_store(added, updated, deleted)

        {:ok,
         %{
           added: added,
           updated: updated,
           deleted: deleted,
           all_features: geojson_features
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp transform_features(features) when is_list(features) do
    features
    |> Enum.map(&normalize_to_geojson_feature/1)
    |> Enum.filter(& &1)
  end

  # Accepts either a GeoJSON Feature or an ESRI feature and returns a GeoJSON Feature
  defp normalize_to_geojson_feature(%{"type" => "Feature"} = feature) do
    # Ensure the Feature has a stable id; prefer existing id, else OBJECTID from properties
    case feature do
      %{"id" => id} when not is_nil(id) ->
        feature

      _ ->
        objectid = get_in(feature, ["properties", "OBJECTID"])
        if is_integer(objectid), do: Map.put(feature, "id", objectid), else: feature
    end
  end

  defp normalize_to_geojson_feature(%{"attributes" => _attrs, "geometry" => _geom} = esri_feature) do
    GeoJSON.to_geojson_feature(esri_feature)
  end

  defp normalize_to_geojson_feature(_), do: nil

  defp compute_diffs(new_features) do
    # Get current features from ETS as a map keyed by id
    current_features_map =
      IncidentsStore.get_all()
      |> Map.new(fn feature -> {feature["id"], feature} end)

    # Convert new features to map keyed by id
    new_features_map = Map.new(new_features, fn feature -> {feature["id"], feature} end)

    # Get all IDs
    current_ids = MapSet.new(Map.keys(current_features_map))
    new_ids = MapSet.new(Map.keys(new_features_map))

    # Compute added and deleted
    added_ids = MapSet.difference(new_ids, current_ids)
    deleted_ids = MapSet.difference(current_ids, new_ids)

    # Compute updated (present in both but with differences)
    common_ids = MapSet.intersection(current_ids, new_ids)

    updated_ids =
      common_ids
      |> Enum.filter(fn id ->
        current_feature = current_features_map[id]
        new_feature = new_features_map[id]
        feature_changed?(current_feature, new_feature)
      end)
      |> MapSet.new()

    # Build result lists
    added = added_ids |> Enum.map(&new_features_map[&1]) |> Enum.sort_by(& &1["id"])
    updated = updated_ids |> Enum.map(&new_features_map[&1]) |> Enum.sort_by(& &1["id"])
    deleted = deleted_ids |> Enum.to_list() |> Enum.sort()

    {added, updated, deleted}
  end

  defp feature_changed?(current_feature, new_feature) do
    # Compare maps excluding storage-only keys
    drop_keys = ["id", "OBJECTID"]
    current_comparable = Map.drop(current_feature, drop_keys)
    new_comparable = Map.drop(new_feature, drop_keys)

    current_comparable != new_comparable
  end

  defp update_ets_store(added, updated, deleted) do
    # Add new features
    Enum.each(added, fn feature ->
      # IncidentsStore expects OBJECTID field for put/1
      feature_with_objectid = Map.put(feature, "OBJECTID", feature["id"])
      IncidentsStore.put(feature_with_objectid)
    end)

    # Update existing features
    Enum.each(updated, fn feature ->
      feature_with_objectid = Map.put(feature, "OBJECTID", feature["id"])
      IncidentsStore.put(feature_with_objectid)
    end)

    # Delete removed features
    Enum.each(deleted, fn id ->
      :ets.delete(:incidents, id)
    end)

    Logger.info("ETS updated: +#{length(added)} ~#{length(updated)} -#{length(deleted)}")
  end

  defp broadcast_event(event_data, true = _first_run) do
    # First run: broadcast snapshot with full FeatureCollection
    snapshot = GeoJSON.feature_collection(event_data.all_features)

    case Jason.encode(snapshot) do
      {:ok, _} ->
        WildfiresWsWeb.Endpoint.broadcast!("fires:incidents", "snapshot", snapshot)
        Logger.info("Broadcasted snapshot with #{length(event_data.all_features)} features")

      {:error, encode_error} ->
        Logger.error("Failed to encode snapshot to JSON: #{inspect(encode_error)}")
    end
  end

  defp broadcast_event(event_data, false = _first_run) do
    # Subsequent runs: broadcast delta if there are changes
    %{added: added, updated: updated, deleted: deleted} = event_data

    if length(added) > 0 or length(updated) > 0 or length(deleted) > 0 do
      delta = %{
        added: added,
        updated: updated,
        # Send as array of IDs to keep payload small
        deleted: deleted
      }

      # Test JSON encoding before broadcasting
      case Jason.encode(delta) do
        {:ok, _json_string} ->
          WildfiresWsWeb.Endpoint.broadcast!("fires:incidents", "delta", delta)

          Logger.info(
            "Broadcasted delta: +#{length(added)} ~#{length(updated)} -#{length(deleted)}"
          )

        {:error, encode_error} ->
          Logger.error("Failed to encode delta to JSON: #{inspect(encode_error)}")
      end
    else
      Logger.debug("No changes detected, skipping delta broadcast")
    end
  end

  ## Public metrics API

  @doc """
  Returns health/telemetry metrics for the poller.

  - last_poll_at: ISO8601 string or nil
  - next_poll_in_ms: integer milliseconds until next poll (0 if not scheduled)
  - incident_count: integer number of incidents currently stored
  """
  def metrics do
    GenServer.call(__MODULE__, :metrics)
  end

  @impl true
  def handle_call(:metrics, _from, state) do
    next_ms =
      case state.next_poll_timer_ref do
        nil ->
          0

        ref ->
          case Process.read_timer(ref) do
            false -> 0
            value when is_integer(value) and value >= 0 -> value
          end
      end

    reply = %{
      last_poll_at:
        if(state.last_poll_at, do: DateTime.to_iso8601(state.last_poll_at), else: nil),
      next_poll_in_ms: next_ms,
      incident_count: IncidentsStore.count()
    }

    {:reply, reply, state}
  end
end
