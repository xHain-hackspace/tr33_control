defmodule Tr33ControlWeb.RedirectController do
  use Tr33ControlWeb, :controller
  alias Tr33ControlWeb.Router.Helpers, as: Routes

  def presets(conn, _params) do
    redirect(conn, to: Routes.presets_path(conn, :index))
  end

  def commands(conn, _params) do
    redirect(conn, to: Routes.commands_path(conn, :show, 0))
  end
end
