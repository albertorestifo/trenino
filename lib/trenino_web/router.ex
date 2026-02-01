defmodule TreninoWeb.Router do
  use TreninoWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TreninoWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Health check endpoint - returns 200 only when app is fully ready
  # Shutdown endpoint for graceful desktop app termination
  scope "/api", TreninoWeb do
    pipe_through :api

    get "/health", HealthController, :index
    post "/shutdown", HealthController, :shutdown
  end

  scope "/", TreninoWeb do
    pipe_through :browser

    live_session :default, on_mount: TreninoWeb.NavHook, layout: {TreninoWeb.Layouts, :app} do
      live "/", ConfigurationListLive
      live "/configurations/:config_id", ConfigurationEditLive
      live "/simulator/config", SimulatorConfigLive
      live "/trains", TrainListLive
      live "/trains/:train_id", TrainEditLive
      live "/trains/:train_id/scripts/new", ScriptEditLive
      live "/trains/:train_id/scripts/:script_id", ScriptEditLive
      live "/firmware", FirmwareLive
    end
  end

  scope "/api", TreninoWeb.Api do
    pipe_through :api

    resources "/trains", TrainApiController, only: [:index, :show] do
      resources "/scripts", ScriptController, only: [:index, :create]
    end

    resources "/scripts", ScriptController, only: [:show, :update, :delete]
    get "/outputs", OutputApiController, :index
    get "/simulator/endpoints", SimulatorApiController, :endpoints
    get "/simulator/value", SimulatorApiController, :value
  end
end
