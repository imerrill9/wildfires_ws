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

Optional (for reproducible Docker CLIs):

```bash
asdf plugin add docker || true
asdf plugin add docker-compose || true
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
| `ESRI_INCIDENTS_URL` | ESRI ArcGIS incidents service URL | `https://services9.arcgis.com/RHVPKKiFTONKtxq3/arcgis/rest/services/USA_Wildfires_v1/FeatureServer/0` |
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

### Production
For production deployment, use releases:
```bash
mix release
PHX_SERVER=true bin/wildfires_ws start
```

## API Endpoints

### Health Check
- **GET** `/_health` - Application health status

## WebSocket API

### Connection
Connect to the WebSocket endpoint:
```
ws://localhost:4000/socket/websocket
```

### Topics and Events

#### `fires:lobby` Topic
Subscribe to receive wildfire incident updates:

**Join:**
```json
{
  "event": "phx_join",
  "topic": "fires:lobby",
  "payload": {},
  "ref": 1
}
```

**Events Received:**
- `new_incident` - New wildfire incident detected
- `incident_update` - Existing incident updated
- `incident_resolved` - Incident marked as resolved

**Example Event:**
```json
{
  "event": "new_incident",
  "topic": "fires:lobby",
  "payload": {
    "id": "incident_123",
    "name": "Smith Canyon Fire",
    "location": {
      "lat": 34.0522,
      "lng": -118.2437
    },
    "status": "active",
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "ref": 0
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

### Mailbox Preview
View email previews at `/dev/mailbox` during development.

## Learn More

- [Phoenix Framework](https://www.phoenixframework.org/)
- [Phoenix Channels](https://hexdocs.pm/phoenix/channels.html)
- [asdf Version Manager](https://asdf-vm.com/)
- [ESRI ArcGIS REST API](https://developers.arcgis.com/rest/)
