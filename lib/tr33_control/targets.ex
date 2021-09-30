defmodule Tr33Control.Targets do
  @targets Application.compile_env!(:tr33_control, :targets)
  @active_targets Application.compile_env!(:tr33_control, :active_targets)

  def get_targets() do
    @targets
    |> Enum.filter(fn {target, _} -> target in @active_targets end)
    |> Enum.into(%{})
  end
end
