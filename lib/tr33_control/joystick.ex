defmodule Tr33Control.Joystick do
  use GenServer
  require Logger
  alias Tr33Control.Commands.{Event, Command, Inputs}
  alias Tr33Control.Commands

  # @joystick_name "Mega World USB Game Controllers"
  @joystick_name "Saitek PLC Cyborg Force Rumble Pad"

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :joystick_debug, false)
    Application.put_env(:tr33_control, :joystick_debug, not current)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def init(_) do
    InputEvent.enumerate()
    |> Enum.find(&match?({_, %InputEvent.Info{name: @joystick_name}}, &1))
    |> case do
      nil ->
        debug_log("Joystick #{inspect(@joystick_name)} not found")
        :ignore

      {input_device, _} ->
        Logger.info("#{__MODULE__}: Found joystick on device #{inspect(input_device)}")
        result = InputEvent.start_link(input_device)

        Logger.info(
          "#{__MODULE__}: Trying to listen on #{input_device} for joystick commands, result: #{inspect(result)}"
        )

        {:ok, %{}}
    end
  end

  def handle_info({:input_event, _, joystick_events}, state) when is_list(joystick_events) do
    joystick_events
    |> Enum.map(fn event ->
      debug_log("Received joystick event #{inspect(event)}")
      event
    end)
    |> Enum.each(&handle_joystick_event/1)

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.error("#{__MODULE__}: terminating, reason: #{inspect(reason)}")
    reason
  end

  # command
  defp handle_joystick_event({:ev_key, :btn_trigger, 1}) do
    if Commands.get_current_preset_name() == "twang" do
      Commands.new_event!(%{type: :joystick, data: [0, 160]})
      |> Commands.send_to_esp()
    else
      Commands.get_event(:update_settings)
      |> Map.update(:data, [], &iterate(&1, 0, Inputs.ColorPalette))
      |> Commands.send_to_esp()
    end
  end

  defp handle_joystick_event({:ev_key, :btn_trigger, 0}) do
    if Commands.get_current_preset_name() == "twang" do
      Commands.new_event!(%{type: :joystick, data: [0, 0]})
      |> Commands.send_to_esp()
    end
  end

  defp handle_joystick_event({:ev_abs, name, value})
       when name in [:abs_x, :abs_y, :abs_hat0x, :abs_hat0y] do
    # todo
    # if Commands.get_current_preset_name() == "joystick" do
    #   case Commands.list_commands() |> Enum.find(fn %Command{type: type} -> type == :mapped_shape end) do
    #     nil ->
    #       :noop

    #     command ->
    #       Map.update(command, :data, [], &update_mapped_shape_data(&1, name, value))
    #       |> Commands.send_to_esp()
    #   end
    # end

    # if Commands.get_current_preset_name() == "twang" do
    #   twang_event(name, value)
    #   |> Commands.send_to_esp()
    # end
  end

  @change_preset_commands [{:ev_key, :btn_base5, 1}, {:ev_key, :btn_top, 1}]
  defp handle_joystick_event(event) when event in @change_preset_commands do
    if Commands.get_current_preset_name() == "twang" do
      Commands.load_preset("joystick")
    else
      if Commands.get_current_preset_name() == "joystick" do
        Application.get_env(:tr33_control, :preset_before_joystick, "twang")
        |> Commands.load_preset()
      else
        Application.put_env(:tr33_control, :preset_before_joystick, Commands.get_current_preset_name())
        Commands.load_preset("twang")
      end
    end
  end

  defp handle_joystick_event(event), do: debug_log("Unhandled joystick event #{inspect(event)}")

  defp debug_log(message) do
    if Application.get_env(:tr33_control, :joystick_debug, false) do
      Logger.debug("#{__MODULE__}: #{message}")
    end
  end

  defp iterate(data, index, enum) do
    List.update_at(data, index, fn value ->
      next = value + 1

      case enum.__enum_map__() |> Keyword.values() |> Enum.member?(next) do
        true -> next
        false -> 0
      end
    end)
  end

  defp interate_num(data, index, incr) when incr > 0 do
    List.update_at(data, index, fn
      v when v > 255 - incr -> 0
      v -> v + incr
    end)
  end

  defp interate_num(data, index, incr) when incr < 0 do
    List.update_at(data, index, fn
      v when v < 0 - incr -> 255
      v -> v + incr
    end)
  end

  defp interate_num(data, _, _), do: data

  defp update_mapped_shape_data(data, :abs_hat0x, joystick_value) do
    interate_num(data, 1, joystick_value * 15)
  end

  defp update_mapped_shape_data(data, :abs_x, joystick_value) do
    List.update_at(data, 2, &smooth_jitter(&1, joystick_value))
  end

  defp update_mapped_shape_data(data, :abs_y, joystick_value) do
    List.update_at(data, 3, &smooth_jitter(&1, joystick_value))
  end

  defp update_mapped_shape_data(data, :abs_hat0y, joystick_value) do
    interate_num(data, 4, joystick_value * -10)
  end

  defp twang_event(:abs_y, value) do
    Commands.new_event!(%{type: :joystick, data: [255 - value, 0]})
  end

  # defp twang_event(:abs_hat0y, value) do
  #   Commands.new_event!(%{type: :joystick, data: [max(value * -1, -126)]})
  # end

  # defp twang_event(_, _), do: %Event{type: :beat}

  defp smooth_jitter(current, new) when abs(new - current) > 1, do: new
  defp smooth_jitter(current, _), do: current
end
