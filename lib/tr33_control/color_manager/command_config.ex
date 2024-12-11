defmodule Tr33Control.ColorManager.CommandConfig do
  require Logger
  alias Tint.{HSV, Lab, RGB}
  alias Tr33Control.Commands
  alias Tr33Control.Commands.{ValueParam, Command}

  defstruct enabled: false,
            color_1: nil,
            color_2: nil,
            change_interval: 60_000,
            last_change: 0,
            color_distance: 20,
            command_index: nil

  def new() do
    %__MODULE__{}
  end

  def maybe_change_colors(%__MODULE__{change_interval: 0} = config, _index) do
    config
  end

  def maybe_change_colors(%__MODULE__{} = config, index) do
    if System.os_time(:millisecond) - config.last_change > config.change_interval do
      change_colors(config, index)
    else
      config
    end
  end

  def change_colors(%__MODULE__{} = config, index) do
    command = Commands.get_command(index)

    config
    |> set_colors()
    |> set_command_colors(command)
    |> set_last_changed()
  end

  defp set_colors(%__MODULE__{} = config) do
    color_1 = random_color()
    color_2 = random_color_with_distance(color_1, config.color_distance)

    Logger.debug("Color 1: #{inspect(color_1)}, Color 2: #{inspect(color_2)}")

    %__MODULE__{config | color_1: color_1, color_2: color_2}
  end

  @min_saturation 60
  defp random_color() do
    hue = Enum.random(0..359)
    saturation = Enum.random(@min_saturation..100) / 100.0
    value = 1

    Tint.HSV.new(hue, saturation, value)
  end

  @tolerance 0.1
  @max_attempts 1000
  defp random_color_with_distance(color_1, target_distance, attempts \\ @max_attempts)

  defp random_color_with_distance(_, _, 0) do
    Logger.error("ColorManger: Max attempts exceeded")
    random_color()
  end

  defp random_color_with_distance(%HSV{} = color_1, target_distance, attempts) do
    color_2 = random_color()

    color_1_lab = Tint.to_lab(color_1)
    color_2_lab = Tint.to_lab(color_2)

    distance = Lab.ciede2000_distance(color_1_lab, color_2_lab)
    # Logger.debug("Color distance: #{distance}, tolerance: #{@tolerance * target_distance}")

    if abs(distance - target_distance) > @tolerance * target_distance do
      random_color_with_distance(color_1, target_distance, attempts - 1)
    else
      color_2
    end
  end

  defp set_last_changed(%__MODULE__{} = config) do
    %__MODULE__{config | last_change: System.os_time(:millisecond)}
  end

  defp set_command_colors(%__MODULE__{} = config, %Command{index: index}) do
    Commands.update_command_param(index, :color_1, color_to_binary(config.color_1))
    Commands.update_command_param(index, :color_2, color_to_binary(config.color_2))
    config
  end

  defp color_to_binary(%Tint.HSV{} = color) do
    %RGB{} = rgb = Tint.to_rgb(color)
    <<rgb.red, rgb.green, rgb.blue>>
  end

  @min_distance 5
  @max_distance 100
  defp set_color_distance(%__MODULE__{} = config, %Command{} = command) do
    %ValueParam{value: color_distance} = Commands.get_common_value_param(command, :color_distance)
    scaled = color_distance / 255.0 * (@max_distance - @min_distance) + @min_distance
    %__MODULE__{config | color_distance: scaled}
  end
end
