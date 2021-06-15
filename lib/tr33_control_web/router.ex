defmodule Tr33ControlWeb.Router do
  use Tr33ControlWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {Tr33ControlWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Tr33ControlWeb do
    pipe_through :browser

    live "/", ControlLive, :index
    # live "/twang", TwangLive
    # get "/docs", DocsController, :index
    get "/preset/:preset_name", PresetController, :load
  end

  if Mix.env() in [:dev, :test, :prod] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: Tr33ControlWeb.Telemetry
    end
  end
end
