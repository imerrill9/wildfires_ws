defmodule WildfiresWsWeb.Router do
  use WildfiresWsWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :browser do
    plug :accepts, ["html"]
  end

  pipeline :health do
    plug :accepts, ["json"]
  end

  scope "/api", WildfiresWsWeb do
    pipe_through :api
    get "/incidents", IncidentsController, :index
  end

  scope "/", WildfiresWsWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/", WildfiresWsWeb do
    pipe_through :health

    get "/_health", HealthController, :show
  end

  # Enable LiveDashboard in development
  if Application.compile_env(:wildfires_ws, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: WildfiresWsWeb.Telemetry
    end
  end
end
