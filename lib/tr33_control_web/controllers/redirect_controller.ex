defmodule Tr33ControlWeb.RedirectController do
  use Tr33ControlWeb, :controller

  def presets(conn, _params) do
    redirect(conn, to: ~p"/presets")
  end

  def commands(conn, _params) do
    redirect(conn, to: ~p"/commands/0")
  end
end
