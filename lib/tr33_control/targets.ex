defmodule Tr33Control.Targets do
  alias Tr33Control.Commands.Schemas.TargetMetrics

  @target_configs Application.compile_env!(:tr33_control, :target_configs)
  @active_targets Application.compile_env!(:tr33_control, :active_targets)

  def get_strip_indices_for_target(target) do
    @target_configs
    |> Map.get(target)
    |> case do
      %{strip_indices: strip_indices} -> strip_indices
      _ -> []
    end
  end

  def active_targets() do
    # todo: allow dynamic targets as well (read from registry)
    @active_targets
  end

  def get_target_from_metrics(%TargetMetrics{name: name}) do
    @target_configs
    |> Enum.filter(&match?({_, %{name_regex: _}}, &1))
    |> Enum.filter(fn {_, %{name_regex: regex}} -> Regex.match?(regex, name) end)
    |> case do
      [] -> String.downcase(name) |> String.to_atom()
      [{target, _} | _] -> target
    end
  end
end
