defmodule Tr33Control.Joystick do
  use GenServer
  require Logger

  @joystick_silver "Mega World USB Game Controllers"
  @joystick_black "Saitek PLC Cyborg Force Rumble Pad"
  @joysticks [@joystick_silver, @joystick_black]

  defstruct name: "", device: "", x: 0, y: 0, button1: false, button2: false, button3: false, button4: false

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  def state() do
    case Process.whereis(__MODULE__) do
      pid when is_pid(pid) -> GenServer.call(__MODULE__, :state)
      _ -> nil
    end
  end

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, "joystick")

  def maybe_notify_subscribers(state, state), do: :noop
  def maybe_notify_subscribers(new_state, _old_state), do: notify_subscribers(new_state)

  def notify_subscribers(state) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, "joystick", {:joystick_update, state})
  end

  def toggle_debug() do
    current = Application.get_env(:tr33_control, :joystick_debug, false)
    Application.put_env(:tr33_control, :joystick_debug, not current)
  end

  def init(_) do
    # InputEvent.enumerate()
    # |> Enum.find(fn {_, %InputEvent.Info{name: name}} -> name in @joysticks end)
    # |> case do
    #   nil ->
    #     debug_log("No joystick found")
    #     notify_subscribers(nil)
    #     :ignore

    #   {device, %InputEvent.Info{name: name}} ->
    #     Logger.info("#{__MODULE__}: Found joystick on device #{inspect(device)}")
    #     {:ok, _pid} = InputEvent.start_link(device)
    #     Logger.info("#{__MODULE__}: Listening on #{device} for joystick commands")
    #     state = %__MODULE__{device: device, name: name}
    #     notify_subscribers(state)
    #     {:ok, state}
    # end
    {:ok, %{}}
  end

  def handle_call(:state, _from, state) do
    {:reply, state, state}
  end

  def handle_info({:input_event, _, joystick_events}, state = %__MODULE__{}) when is_list(joystick_events) do
    state =
      joystick_events
      |> tap(fn event -> debug_log("Received joystick event #{inspect(event)}") end)
      |> Enum.reduce(state, &handle_joystick_event/2)
      |> tap(&maybe_notify_subscribers(&1, state))

    {:noreply, state}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  def terminate(reason, _state) do
    Logger.error("#{__MODULE__}: terminating, reason: #{inspect(reason)}")
    reason
  end

  # Silver Joystick
  defp handle_joystick_event({:ev_abs, :abs_x, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | x: value + 128}
  end

  defp handle_joystick_event({:ev_abs, :abs_y, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | y: 127 - value}
  end

  defp handle_joystick_event({:ev_key, :btn_trigger, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | button1: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_thumb, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | button2: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_thumb2, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | button3: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_top, value}, %__MODULE__{name: @joystick_silver} = state) do
    %__MODULE__{state | button4: int_to_boolean(value)}
  end

  # Black Joystick
  defp handle_joystick_event({:ev_abs, :abs_x, value}, %__MODULE__{name: @joystick_black, x: x} = state) do
    if abs(value - x) > 1 do
      %__MODULE__{state | x: value}
    else
      state
    end
  end

  defp handle_joystick_event({:ev_abs, :abs_y, value}, %__MODULE__{name: @joystick_black, y: y} = state) do
    if abs(value - y) > 1 do
      %__MODULE__{state | y: 255 - value}
    else
      state
    end
  end

  defp handle_joystick_event({:ev_key, :btn_trigger, value}, %__MODULE__{name: @joystick_black} = state) do
    %__MODULE__{state | button1: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_thumb, value}, %__MODULE__{name: @joystick_black} = state) do
    %__MODULE__{state | button2: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_thumb2, value}, %__MODULE__{name: @joystick_black} = state) do
    %__MODULE__{state | button3: int_to_boolean(value)}
  end

  defp handle_joystick_event({:ev_key, :btn_top, value}, %__MODULE__{name: @joystick_black} = state) do
    %__MODULE__{state | button4: int_to_boolean(value)}
  end

  defp handle_joystick_event(event, state) do
    debug_log("Unhandled joystick event #{inspect(event)}")
    state
  end

  defp int_to_boolean(0), do: false
  defp int_to_boolean(1), do: true

  defp debug_log(message) do
    if Application.get_env(:tr33_control, :joystick_debug, false) do
      Logger.debug("#{__MODULE__}: #{message}")
    end
  end
end
