# WildfiresWs

A Phoenix WebSocket application that polls ESRI ArcGIS services for wildfire incidents and broadcasts updates to connected clients in real-time.

## Prerequisites

### asdf Version Manager
This project uses [asdf](https://asdf-vm.com/) for managing Elixir and Erlang versions.

1. Install asdf: https://asdf-vm.com/guide/getting-started.html
2. Install the required plugins:
   ```bash
   asdf plugin add erlang
   asdf plugin add elixir
   ```
3. Install the versions specified in `.tool-versions`:
   ```bash
   asdf install
   ```

The project pins:

```
erlang 28.0
elixir 1.18.4-otp-28
```

### Ensure your shell uses asdf (not Homebrew)

- Verify your shell resolves to asdf shims:
  ```bash
  which elixir
  # => $HOME/.asdf/shims/elixir
  asdf current
  elixir -v
  ```
- If `which elixir` points to Homebrew (e.g., `/opt/homebrew/bin/elixir`), either unlink or uninstall the brew formulas and ensure asdf is initialized in your shell (e.g., in `~/.zshrc`):
  ```bash
  # Prefer unlink to test quickly
  brew unlink elixir erlang
  # Ensure asdf is initialized and shims take precedence
  echo '. "$HOME/.asdf/asdf.sh"' >> ~/.zshrc
  echo '. "$HOME/.asdf/completions/asdf.bash"' >> ~/.zshrc  # harmless on zsh
  exec $SHELL -l
  ```
  Note: asdf manages the CLIs; you still need a running Docker Engine (Docker Desktop or Colima).

### Dependencies
Install project dependencies:
```bash
mix deps.get
```

## Environment Variables

Copy `.env.sample` to `.env` and configure the following variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `ESRI_INCIDENTS_URL` | ESRI ArcGIS incidents service URL | `https://services9.arcgis.com/RHVPKKiFTONKtxq3/arcgis/rest/services/USA_Wildfires_v1/FeatureServer/0/query` |
| `POLL_INTERVAL_MS` | Polling interval in milliseconds | `30000` (30 seconds) |
| `PORT` | Server port | `4000` |
| `SECRET_KEY_BASE` | Phoenix secret key (generate with `mix phx.gen.secret`) | Required for production |

## Running the Application

### Development
Start the Phoenix server:
```bash
mix phx.server
```

Or start with interactive Elixir shell:
```bash
iex -S mix phx.server
```

The application will be available at [`localhost:4000`](http://localhost:4000).

### UI
Visiting `/` displays a map of current wildfire locations. It loads an initial snapshot and receives live updates over the `fires:incidents` WebSocket topic.

## API Endpoints

### Health Check
- **GET** `/_health` - Application health status

### Incidents
- **GET** `/api/incidents` - Returns the current wildfire incidents as a GeoJSON FeatureCollection
  - Content-Type: `application/geo+json`
  - Example shape:
    ```json
    {
      "type": "FeatureCollection",
      "features": [
        {
          "type": "Feature",
          "id": 123,
          "geometry": { "type": "Point", "coordinates": [-120.5, 38.2] },
          "properties": { "NAME": "Fire Name" }
        }
      ]
    }
    ```

## WebSocket API

### Connection
Connect to the WebSocket endpoint:
```
ws://localhost:4000/socket/websocket
```

### Topics and Events

#### `fires:incidents` topic
Subscribe to receive wildfire incident updates:

- On join, the server pushes a `snapshot` event with the full FeatureCollection.
- On subsequent polls, clients receive `delta` events describing changes.

**Join:**
```json
{
  "event": "phx_join",
  "topic": "fires:incidents",
  "payload": {},
  "ref": 1
}
```

**Events Received:**
- `snapshot` (first join and first poller run):
  ```json
  {
    "event": "snapshot",
    "topic": "fires:incidents",
    "payload": {
      "type": "FeatureCollection",
      "features": [
        { "type": "Feature", "id": 1, "geometry": { "type": "Point", "coordinates": [-120.0, 38.0] }, "properties": { "NAME": "Alpha" } }
      ]
    }
  }
  ```
- `delta` (subsequent updates):
  ```json
  {
    "event": "delta",
    "topic": "fires:incidents",
    "payload": {
      "added": [ { "type": "Feature", "id": 3, "geometry": { "type": "Point", "coordinates": [-120.0, 38.0] }, "properties": { "NAME": "Charlie" } } ],
      "updated": [ { "type": "Feature", "id": 1, "geometry": { "type": "Point", "coordinates": [-120.0, 38.0] }, "properties": { "NAME": "Alpha Updated" } } ],
      "deleted": [2]
    }
  }
  ```

## Docker

### Build Image
```bash
docker build -t wildfires_ws .
```

### Run with Docker Compose
```bash
docker compose up
```

Or build and run in one command:
```bash
docker compose up --build
```

## Development

### Live Dashboard
In development, access the Phoenix LiveDashboard at `/dev/dashboard` for real-time metrics and debugging.

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html)
- [asdf Version Manager](https://asdf-vm.com/)
- [ESRI ArcGIS REST API](https://developers.arcgis.com/rest/)
