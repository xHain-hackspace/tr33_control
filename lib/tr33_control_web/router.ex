defmodule Tr33ControlWeb.Router do
  use Tr33ControlWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Tr33ControlWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Tr33ControlWeb do
    pipe_through :browser

    get "/", RedirectController, :commands

    live_session :live, on_mount: Tr33ControlWeb.Navbar do
      live "/presets", PresetsLive, :index
      live "/presets/new", PresetsLive, :new
      live "/presets/update", PresetsLive, :update
      live "/presets/delete", PresetsLive, :delete

      live "/commands/:index", CommandsLive, :show
      live "/commands/:index/new", CommandsLive, :new

      live "/status", StatusLive, :index
    end

    get "/presets/:preset_name", PresetController, :load
    get "/rotate_presets", PresetController, :rotate
    get "/off", PresetController, :off
    get "/commands", RedirectController, :commands
  end

  if Mix.env() in [:dev, :test, :prod] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: Tr33ControlWeb.Telemetry
    end
  end
end
