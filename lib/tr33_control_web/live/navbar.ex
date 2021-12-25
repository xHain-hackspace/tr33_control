defmodule Tr33ControlWeb.Navbar do
  import Phoenix.LiveView

  alias Tr33ControlWeb.Router.Helpers, as: Routes

  def on_mount(_, _params, _session, socket) do
    socket =
      assign(socket,
        navbar_content: [
          {"Presets", Routes.presets_path(socket, :index)},
          {"Commands", Routes.commands_path(socket, :show, 0)},
          {"Status", Routes.status_path(socket, :index)}
        ]
      )

    socket =
      attach_hook(socket, :set_navbar_active_path, :handle_params, fn
        _params, url, socket ->
          socket =
            socket
            |> assign(navbar_active_path: URI.parse(url).path)

          {:cont, socket}
      end)

    {:cont, socket}
  end
end
