defmodule Tr33ControlWeb.Navbar do
  use Tr33ControlWeb, :controller

  import Phoenix.LiveView
  import Phoenix.Component

  def on_mount(_, _params, _session, socket) do
    socket =
      assign(socket,
        navbar_content: [
          {"Presets", ~p"/presets"},
          {"Commands", ~p"/commands/0"},
          {"Status", ~p"/status"}
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
