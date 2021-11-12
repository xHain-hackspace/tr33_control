defmodule Tr33ControlWeb.LayoutView do
  use Tr33ControlWeb, :view

  def title do
    Application.get_env(:tr33_control, :title, "Control")
  end
end
