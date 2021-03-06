defmodule Tr33Control.Commands do
  require Logger
  alias Ecto.Changeset
  alias Tr33Control.Commands.{Command, UART, Event, Cache, Preset, Modifier}

  @max_index Application.fetch_env!(:tr33_control, :command_max_index)
  @pubsub_silent_period_ms 100

  @topic "#{inspect(__MODULE__)}"

  def init() do
    Cache.init_all()

    default_preset()
    |> load_preset
  end

  def send_to_esp(command, force \\ false)

  def send_to_esp(%Command{index: index} = command, force) when index <= @max_index do
    command
    |> Cache.insert(force)
    |> UART.send()
  end

  def send_to_esp(%Command{} = command, _), do: command

  def send_to_esp(%Event{} = event, force) do
    event
    |> maybe_insert(force)
    |> UART.send()
  end

  ### PubSub #######################################################################

  def subscribe() do
    Phoenix.PubSub.subscribe(Tr33Control.PubSub, @topic)
  end

  def notify_subscribers({Command, key}, force), do: notify_subscribers({:command_update, key}, force)

  def notify_subscribers({Event, key}, force), do: notify_subscribers({:event_update, key}, force)

  def notify_subscribers({Preset, key}, force), do: notify_subscribers({:preset_update, key}, force)

  def notify_subscribers(message, force) do
    now = System.os_time(:millisecond)
    last_notify = Application.get_env(:tr33_control, :pubsub_last_notify, 0)

    if force or now - last_notify > @pubsub_silent_period_ms do
      Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @topic, message)
      Application.put_env(:tr33_control, :pubsub_last_notify, now)
    else
      # Logger.debug("PubSub throttled, message: #{inspect(message)}")
    end
  end

  ### Commands ###############################################################################################

  def new_command!(params) do
    new_command(params)
    |> raise_on_error()
  end

  def new_command(params) when is_map(params) do
    %Command{}
    |> Command.changeset(params)
    |> Changeset.apply_action(:insert)
  end

  def new_command(binary) when is_binary(binary) do
    binary
    |> Command.from_binary()
  end

  def append_empty_command() do
    next_index =
      case list_commands() |> List.last() do
        %Command{index: index} -> index + 1
        nil -> 0
      end

    Command.defaults(next_index)
    |> send_to_esp()
  end

  def list_commands() do
    0..@max_index
    |> Enum.map(&get_command/1)
    |> Enum.reject(&is_nil/1)
  end

  def get_command(index) do
    Cache.get(Command, index)
  end

  def edit_command!(%Command{} = command, params) do
    command
    |> Command.changeset(params)
    |> Changeset.apply_action(:update)
    |> raise_on_error()
  end

  def delete_last_command() do
    case list_commands() |> List.last() do
      %Command{index: index} ->
        Cache.delete(Command, index)
        index

      nil ->
        0
    end
  end

  def swap_commands(%Command{index: index} = command, new_index) when new_index >= 0 and new_index <= @max_index do
    swapped_command = get_command(new_index)

    %Command{swapped_command | index: index}
    |> send_to_esp(true)

    %Command{command | index: new_index}
    |> send_to_esp(true)
  end

  def swap_commands(%Command{} = command, _), do: command

  def clone_command(%Command{} = command, new_index) when new_index >= 0 and new_index <= @max_index do
    %Command{command | index: new_index}
    |> send_to_esp(true)
  end

  def clone_command(%Command{} = command, _), do: command

  ### Modifiers ###############################################################################################

  def create_modifier(%Command{modifiers: modifiers} = command, index) do
    input =
      Command.inputs(command)
      |> Enum.find(&match?(%{index: ^index}, &1))

    modifier = Modifier.from_input(input)

    %Command{command | modifiers: Map.put(modifiers, index, modifier)}
    |> Cache.insert(true)
  end

  def delete_modifier(%Command{modifiers: modifiers} = command, index) do
    %Command{command | modifiers: Map.delete(modifiers, index)}
    |> Cache.insert(true)
  end

  def update_modifier!(%Command{modifiers: modifiers} = command, index, params) when is_number(index) do
    modifier =
      Map.fetch!(modifiers, index)
      |> Modifier.changeset(params)
      |> Ecto.Changeset.apply_action(:insert)
      |> raise_on_error()

    %Command{command | modifiers: Map.put(modifiers, index, modifier)}
    |> Cache.insert(true)
  end

  def apply_modifiers(%Command{modifiers: modifiers} = command) when map_size(modifiers) > 0 do
    if Enum.any?(modifiers, fn {_, %Modifier{period: period}} -> period > 0 end) do
      Enum.reduce(modifiers, command, &Modifier.apply/2)
      |> send_to_esp()
    end
  end

  def apply_modifiers(%Command{} = command) do
    command
  end

  ### Events ###############################################################################################

  def new_event(params) when is_map(params) do
    %Event{}
    |> Event.changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end

  def new_event(binary) when is_binary(binary) do
    binary
    |> Event.from_binary()
  end

  def new_event!(params) do
    new_event(params)
    |> raise_on_error()
  end

  def get_event(type) do
    Cache.get(Event, type)
  end

  def list_events() do
    Cache.all(Event)
  end

  ### Presets ###############################################################################################

  def change_preset(preset, attrs \\ %{}) do
    Preset.changeset(preset, attrs)
  end

  def create_preset(attrs) do
    commands = list_commands()
    events = list_events()

    attrs
    |> get_or_new_preset()
    |> Changeset.put_change(:commands, commands)
    |> Changeset.put_change(:events, events)
    |> Changeset.put_change(:updated_at, NaiveDateTime.utc_now())
    |> Ecto.Changeset.apply_action(:insert)
    |> maybe_insert(true)
    |> maybe_set_current_preset()
  end

  def update_preset!(preset, attrs) do
    preset
    |> change_preset(attrs)
    |> Ecto.Changeset.apply_action(:update)
    |> maybe_insert(true)
    |> raise_on_error()
  end

  def get_preset(name) do
    Cache.get(Preset, name)
  end

  def list_presets() do
    Cache.all(Preset)
  end

  def load_preset(%Preset{commands: commands, events: events, name: name} = preset) do
    set_current_preset(preset)

    Cache.clear(Command)
    Cache.clear(Event)

    (commands ++ events)
    |> Enum.map(&Cache.insert(&1, true))

    UART.resync()
    notify_subscribers({:preset_load, name}, true)

    preset
  end

  def load_preset(name) when is_binary(name) do
    Cache.get(Preset, name)
    |> load_preset()
  end

  def load_preset(nil), do: :noop

  def get_current_preset_name() do
    Application.get_env(:tr33_control, :current_preset)
  end

  def get_current_preset() do
    name = get_current_preset_name()
    Cache.get(Preset, name) || %Preset{}
  end

  def set_current_preset(%Preset{name: name}) do
    Application.put_env(:tr33_control, :current_preset, name)
  end

  def delete_preset(name) do
    Cache.delete(Preset, name)
  end

  def default_preset() do
    presets = list_presets()

    case Enum.find(presets, fn %Preset{default: default} -> default end) do
      %Preset{} = preset ->
        preset

      nil ->
        Enum.sort_by(presets, fn %Preset{updated_at: updated_at} -> NaiveDateTime.to_erl(updated_at) end)
        |> List.last()
    end
  end

  def set_default_preset(name) do
    default_preset() |> update_preset!(%{default: false})

    case get_preset(name) do
      nil -> nil
      preset -> update_preset!(preset, %{default: true})
    end
  end

  ### Misc (to be sorted) ###############################################################################################

  def command_types(), do: Command.types()
  def event_types(), do: Event.types()

  def inputs(%Event{} = event), do: Event.inputs(event)
  def inputs(%Command{} = command), do: Command.inputs(command)

  def modifier_inputs(%Command{} = command) do
    Modifier.inputs_for_command(command)
  end

  defp raise_on_error({:ok, result}), do: result

  defp raise_on_error(error), do: raise(RuntimeError, message: "Could not create: #{inspect(error)}")

  defp maybe_insert(%Event{} = event, force) do
    if Event.persist?(event), do: Cache.insert(event, force)
    event
  end

  defp maybe_insert({:error, _} = response, _), do: response

  defp maybe_insert({:ok, struct} = response, force) do
    Cache.insert(struct, force)
    response
  end

  defp maybe_set_current_preset({:ok, preset} = response) do
    set_current_preset(preset)
    response
  end

  defp maybe_set_current_preset({:error, _} = response), do: response

  defp get_or_new_preset(%{"name" => name} = attr) do
    case Cache.get(Preset, name) do
      nil -> change_preset(%Preset{}, attr)
      preset = %Preset{} -> change_preset(preset)
    end
  end
end
