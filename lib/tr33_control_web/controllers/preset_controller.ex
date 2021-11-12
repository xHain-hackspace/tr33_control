defmodule Tr33ControlWeb.PresetController do
  use Tr33ControlWeb, :controller
  require Logger

  def test(conn, _) do
    conn
    |> send_resp(200, "")
  end

  def load(conn, %{"preset_name" => preset_name}) do
    Tr33Control.Commands.load_preset(preset_name)

    conn
    |> send_resp(200, "")
  end
end
