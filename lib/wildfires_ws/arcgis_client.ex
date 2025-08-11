defmodule WildfiresWs.ArcgisClient do
  @moduledoc """
  ArcGIS client for fetching wildfire incident data using Req.

  Handles pagination and retry logic for robust data fetching from ESRI services.
  """

  require Logger

  @default_esri_url "https://services9.arcgis.com/RHVPKKiFTONKtxq3/arcgis/rest/services/USA_Wildfires_v1/FeatureServer/0/query"
  @page_size 1000
  @max_retries 3
  @base_backoff_ms 1000

  @doc """
  Fetches all wildfire incidents from the ArcGIS service with pagination.

  Uses the ESRI_INCIDENTS_URL environment variable or falls back to the default URL.
  Handles pagination automatically until all records are retrieved or the transfer limit is exceeded.

  Returns a list of ESRI features as maps in their raw ESRI schema format.

  ## Examples

      iex> WildfiresWs.ArcgisClient.fetch_all_incidents()
      {:ok, [%{"attributes" => %{"OBJECTID" => 1, ...}, "geometry" => %{...}}, ...]}

      iex> WildfiresWs.ArcgisClient.fetch_all_incidents()
      {:error, :timeout}
  """
  def fetch_all_incidents do
    url = System.get_env("ESRI_INCIDENTS_URL", @default_esri_url)
    fetch_all_incidents_recursive(url, 0, [])
  end

  defp fetch_all_incidents_recursive(url, offset, accumulated_features) do
    params = %{
      f: "json",
      where: "1=1",
      outFields: "*",
      returnGeometry: true,
      outSR: 4326,
      resultOffset: offset,
      resultRecordCount: @page_size
    }

    case fetch_with_retry(url, params) do
      {:ok, response} ->
        features = Map.get(response, "features", [])
        exceeded_limit = Map.get(response, "exceededTransferLimit", false)

        new_accumulated = accumulated_features ++ features

        if exceeded_limit and length(features) == @page_size do
          # More data available, continue pagination
          Logger.info(
            "Fetched #{length(features)} features at offset #{offset}, continuing pagination"
          )

          fetch_all_incidents_recursive(url, offset + @page_size, new_accumulated)
        else
          # No more data or reached the end
          Logger.info("Completed fetching incidents. Total features: #{length(new_accumulated)}")
          {:ok, new_accumulated}
        end

      {:error, reason} ->
        Logger.error("Failed to fetch incidents after retries: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_with_retry(url, params, attempt \\ 1) do
    case make_request(url, params) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} when attempt < @max_retries ->
        if retryable_error?(reason) do
          backoff_ms = @base_backoff_ms * :math.pow(2, attempt - 1)

          Logger.warning(
            "Request failed (attempt #{attempt}/#{@max_retries}): #{inspect(reason)}. Retrying in #{backoff_ms}ms"
          )

          Process.sleep(round(backoff_ms))
          fetch_with_retry(url, params, attempt + 1)
        else
          {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp make_request(url, params) do
    case Req.get(url, params: params, receive_timeout: 30_000) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, decoded} ->
            case Map.get(decoded, "error") do
              nil -> {:ok, decoded}
              error -> {:error, {:esri_error, error}}
            end

          {:error, reason} ->
            {:error, {:json_decode_error, reason}}
        end

      {:ok, %Req.Response{status: status, body: body}} when status >= 500 ->
        {:error, {:http_error, status, body}}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport_error, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp retryable_error?({:http_error, status, _}) when status >= 500, do: true
  defp retryable_error?(:timeout), do: true
  defp retryable_error?({:transport_error, _}), do: true
  defp retryable_error?(_), do: false
end
