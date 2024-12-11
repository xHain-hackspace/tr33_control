defmodule Tr33Control.Commands do
  alias Tr33Control.Commands.Schemas.FirmwareConfig
  alias Tr33Control.{ESP, ColorManager}
  alias __MODULE__.{Schemas, Command, Cache, ValueParam, EnumParam, StringParam, ColorParam, Preset}

  alias __MODULE__.Schemas.{
    CommandParams,
    Modifier,
    WireMessage,
    TimeSync,
    JoystickEvent,
    ColorPaletteRequest,
    FadeOutEvent
  }

  @command_blacklist Application.compile_env!(:tr33_control, :command_blacklist)
  @command_priority Application.compile_env!(:tr33_control, :command_priority)
  @commands_topic "command_updates"
  @presets_topic "preset_updates"
  @common_params %CommandParams{} |> Map.from_struct() |> Map.delete(:type_params) |> Map.keys()
  @command_max_count Application.compile_env!(:tr33_control, :command_max_count)

  def init() do
    Cache.init_all()

    notify_subscribers(:preset_update)

    case get_default_preset() do
      nil -> create_command(0, :rainbow)
      %Preset{name: name} -> load_preset(name)
    end
  end

  ### PubSub #######################################################################

  def subscribe_commands(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @commands_topic)
  def subscribe_presets(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @presets_topic)

  def notify_subscribers(%Command{} = command) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @commands_topic, {:command_update, command})
  end

  def notify_subscribers(:preset_update) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @presets_topic, :preset_update)
  end

  def notify_subscribers(:preset_loaded, name) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @presets_topic, {:preset_loaded, name})
  end

  def notify_subscribers(:command_deleted, index) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @commands_topic, {:command_deleted, index})
  end

  ### Commands ########################################################################################################

  def list_command_types() do
    %Protobuf.OneOfField{fields: fields} = Schemas.CommandParams.defs(:field, :type_params)

    all =
      fields
      |> Enum.map(fn %Protobuf.Field{name: name} -> name end)
      |> Enum.reject(&(&1 in @command_blacklist))

    prio =
      @command_priority
      |> Enum.filter(&(&1 in all))

    Enum.uniq(prio ++ all)
  end

  def get_command(index) do
    case Cache.get(Command, index) do
      nil -> Command.disabled(index)
      %Command{} = command -> command
    end
  end

  def list_commands(opts \\ []) do
    include_empty = Keyword.get(opts, :include_empty, false)

    Cache.all(Command)
    |> Enum.sort_by(fn %Command{} = c -> c.index end)
    |> maybe_fill_commands(include_empty)
  end

  def create_command(index, type, params \\ []) when is_atom(type) and is_number(index) and is_list(params) do
    if(index < @command_max_count) do
      Command.new(index, type, params)
      |> Map.put(:targets, ESP.active_targets())
      |> insert_and_notify()
    else
      :noop
    end
  end

  def create_command(protobuf) do
    Command.new(protobuf)
    |> Map.put(:targets, ESP.active_targets())
    |> insert_and_notify()
  end

  def delete_commands(indices) when is_list(indices) do
    old_count = count_commands()
    new_count = old_count - length(indices)

    if new_count > 0 do
      for index <- indices do
        Cache.delete(Command, index)
      end

      list_commands()
      |> Enum.with_index()
      |> Enum.map(fn {command, index} ->
        %Command{command | index: index} |> insert_and_notify()
      end)

      for index <- new_count..(old_count - 1) do
        Cache.delete(Command, index)
        notify_subscribers(:command_deleted, index)
      end
    else
      :noop
    end
  end

  def delete_command(index), do: delete_commands([index])

  def all_off() do
    indices = 0..(count_commands() - 2) |> Enum.to_list()
    delete_commands(indices)
    update_command_param(0, :enabled, false)
  end

  def update_command_type(index, type) when is_atom(type) do
    get_command(index)
    |> Command.new_type_params(type)
    |> insert_and_notify()
  end

  def update_command_param(index, name, value) when name in @common_params do
    command = %Command{} = get_command(index)

    new_params = Map.replace!(command.params, name, value)

    %Command{command | params: new_params}
    |> insert_and_notify()
  end

  def update_command_param(index, name, value) do
    command = %Command{} = get_command(index)

    type = Command.type(command)
    new_type_params = command |> Command.type_params() |> Map.replace!(name, value)
    new_params = %CommandParams{command.params | type_params: {type, new_type_params}}

    %Command{command | params: new_params}
    |> insert_and_notify()
  end

  def toggle_command_target(index, target) do
    command = %Command{} = get_command(index)

    new_targets =
      if Enum.member?(command.targets, target) do
        List.delete(command.targets, target)
      else
        [target | command.targets]
      end

    %Command{command | targets: new_targets}
    |> insert_and_notify()
  end

  def count_commands() do
    Cache.count(Command)
  end

  def swap_commands(index1, index2) when index1 >= 0 and index2 >= 0 do
    count = count_commands()

    if index1 < count and index2 < count do
      command1 = get_command(index1)
      command2 = get_command(index2)

      %Command{command1 | index: index2} |> insert_and_notify()
      %Command{command2 | index: index1} |> insert_and_notify()
    end
  end

  def swap_commands(_index1, _index2) do
    :noop
  end

  def clone_command(index) when is_number(index) do
    :noop
  end

  def get_command_hash(index, target) do
    case get_command(index) do
      %Command{params: %CommandParams{enabled: false}} -> ""
      %Command{targets: targets, params: %CommandParams{hash: hash}} -> if target in targets, do: hash, else: ""
    end
  end

  ### Command Params: EnumParam + ValueParam ###############################################################################

  def list_value_params(%Command{} = command) do
    type_params = Command.type_params(command)

    Command.list_type_field_defs(command)
    |> Enum.map(&ValueParam.new(type_params, &1, command))
    |> Enum.reject(&is_nil/1)
  end

  def list_enum_params(%Command{} = command) do
    type_params = Command.type_params(command)

    Command.list_type_field_defs(command)
    |> Enum.map(&EnumParam.new(type_params, &1))
    |> Enum.reject(&is_nil/1)
  end

  def list_string_params(%Command{} = command) do
    type_params = Command.type_params(command)

    Command.list_type_field_defs(command)
    |> Enum.map(&StringParam.new(type_params, &1))
    |> Enum.reject(&is_nil/1)
  end

  def get_common_value_param(%Command{} = command, name) do
    Command.get_field_def(name)
    |> then(&ValueParam.new(command.params, &1))
  end

  def get_common_enum_param(%Command{} = command, name) do
    Command.get_field_def(name)
    |> then(&EnumParam.new(command.params, &1))
  end

  def get_common_color_params(%Command{} = command) do
    field_names = [:color_1, :color_2]

    if Tr33Control.ColorManager.command_supported?(command) do
      Enum.map(field_names, fn name ->
        Command.get_field_def(name)
        |> then(&ColorParam.new(command.params, &1))
      end)
    else
      []
    end
  end

  def list_common_params() do
    @common_params
  end

  def get_command_type_param(%Command{} = command) do
    EnumParam.new(:command_type, Command.type(command), list_command_types())
  end

  def get_strip_index_param(%Command{targets: [target], params: %CommandParams{} = params}) do
    case Tr33Control.ESP.get_strip_indices_for_target(target) do
      [] -> nil
      [0] -> nil
      options -> EnumParam.new(:strip_index, params.strip_index, options)
    end
  end

  def get_strip_index_param(%Command{}), do: nil

  ### Modifiers ###################################################################################

  def list_modifier_names(%Command{} = command) do
    common =
      list_common_params()
      |> Enum.filter(&(&1 in [:brightness, :color_palette, :strip_index]))

    type =
      command
      |> list_value_params()
      |> Enum.map(fn %ValueParam{name: name} -> name end)

    common ++ type
  end

  def get_modifier_params(%Command{params: %CommandParams{modifiers: modifiers}} = command) do
    modifiers
    |> Enum.sort_by(fn %Modifier{field_index: i} -> i end)
    |> Enum.map(fn modifier ->
      name = modifier_name(command, modifier)

      field_defs = Command.list_modifier_field_defs()
      enum_params = Enum.map(field_defs, &EnumParam.new(modifier, &1)) |> Enum.reject(&is_nil/1)
      value_params = Enum.map(field_defs, &ValueParam.new(modifier, &1)) |> Enum.reject(&is_nil/1)

      {name, enum_params, value_params}
    end)
  end

  def get_modifier(%Command{params: %CommandParams{} = params}, field_index) when is_number(field_index) do
    params.modifiers
    |> Enum.find(&match?(%Modifier{field_index: ^field_index}, &1))
  end

  def get_modifier(%Command{} = command, name) when is_atom(name) do
    field_index = modifier_field_index(command, name)
    get_modifier(command, field_index)
  end

  def add_modifier(%Command{params: %CommandParams{} = params} = command, name) when is_atom(name) do
    field_index = modifier_field_index(command, name)

    case get_modifier(command, field_index) do
      nil ->
        modifiers = [%Modifier{field_index: field_index} | params.modifiers]
        update_command_param(command.index, :modifiers, modifiers)

      %Modifier{} ->
        command
    end
  end

  def update_modifier(%Command{params: %CommandParams{} = params} = command, name, fields) when is_map(fields) do
    field_index = modifier_field_index(command, name)

    modifiers =
      params.modifiers
      |> Enum.map(fn
        %Modifier{field_index: ^field_index} = modifier -> Map.merge(modifier, fields)
        modifier -> modifier
      end)

    update_command_param(command.index, :modifiers, modifiers)
  end

  def delete_modifier(%Command{params: %CommandParams{} = params} = command, name) when is_atom(name) do
    to_delete = get_modifier(command, name)

    modifiers =
      params.modifiers
      |> List.delete(to_delete)

    update_command_param(command.index, :modifiers, modifiers)
  end

  def modifier_name(%Command{} = command, %Modifier{field_index: field_index}) do
    command
    |> list_modifier_names()
    |> Enum.at(field_index)
  end

  ### Presets ###############################################################################

  # topo: better error handling
  def create_preset(""), do: :noop

  def create_preset(name) when is_binary(name) do
    preset =
      case Cache.get(Preset, name) do
        nil -> %Preset{name: name}
        preset -> preset
      end

    preset =
      %Preset{preset | commands: list_commands()}
      |> Cache.insert()

    notify_subscribers(:preset_update)

    preset
  end

  def delete_preset(name) do
    Cache.delete(Preset, name)
    notify_subscribers(:preset_update)
  end

  def load_preset(name) do
    %Preset{commands: commands} = preset = Cache.get(Preset, name)

    previous_count = count_commands()
    new_count = Enum.count(commands)

    if previous_count > new_count do
      (previous_count - 1)..new_count
      |> Enum.into([])
      |> delete_commands()
    end

    commands
    |> Enum.map(&insert_and_notify/1)

    notify_subscribers(:preset_loaded, name)

    preset
  end

  def clone_preset(name) do
    preset = Cache.get(Preset, name)

    new_name =
      case String.split(name, "_") |> Enum.reverse() do
        [_] ->
          "#{name}_2"

        [maybe_int | rest] ->
          case Integer.parse(maybe_int) do
            {int, ""} -> "#{rest |> Enum.reverse() |> Enum.join("_")}_#{int + 1}"
            _ -> "#{name}_2"
          end
      end

    preset =
      %Preset{preset | name: new_name}
      |> Cache.insert()

    notify_subscribers(:preset_update)
    preset
  end

  def list_presets() do
    Cache.all(Preset)
  end

  def rotate_preset() do
    presets = list_presets()
    current_index = Application.get_env(:tr33_control, :preset_rotate_index, 0)
    next_index = rem(current_index + 1, Enum.count(presets))
    %Preset{name: next_name} = Enum.at(presets, next_index)
    Application.put_env(:tr33_control, :preset_rotate_index, next_index)
    load_preset(next_name)
  end

  def get_default_preset() do
    Cache.all(Preset)
    |> Enum.find(fn %Preset{} = preset -> preset.default end)
  end

  def set_default_preset(name) do
    get_default_preset()
    |> case do
      nil -> :noop
      preset -> %Preset{preset | default: false} |> Cache.insert()
    end

    preset =
      load_preset(name)
      |> then(fn preset -> %Preset{preset | default: true} end)
      |> Cache.insert()

    notify_subscribers(:preset_update)
    preset
  end

  ### FirmwareConfig ###################################################################################

  def set_firmware_config(calibration_fastled, calibration_custom, gamma_correction) do
    %FirmwareConfig{
      calibration_fastled: calibration_fastled,
      calibration_custom: calibration_custom,
      gamma_correction: gamma_correction
    }
    |> ESP.broadcast_firmware_config()
  end

  ### Protobuf ###################################################################################

  def time_sync_binary() do
    time_sync = TimeSync.new(millis: System.os_time(:millisecond))

    WireMessage.new(message: {:time_sync, time_sync})
    |> WireMessage.encode()
  end

  def command_binary(%Command{index: index, targets: targets} = command, target) do
    %Command{params: %CommandParams{} = params} =
      if target in targets do
        command
      else
        Command.disabled(index)
      end

    WireMessage.new(message: {:command_params, params})
    |> WireMessage.encode()
  end

  def joystick_event_binary(%Tr33Control.Joystick{} = joystick) do
    joystick_event =
      JoystickEvent.new(
        x: joystick.x,
        y: joystick.y,
        button1: joystick.button1,
        button2: joystick.button2,
        button3: joystick.button3,
        button4: joystick.button4
      )

    WireMessage.new(message: {:joystick_event, joystick_event})
    |> WireMessage.encode()
  end

  def color_palette_request_binary(palette) do
    request = ColorPaletteRequest.new(color_palette: palette)

    WireMessage.new(message: {:color_palette_request, request})
    |> WireMessage.encode()
  end

  def firmware_config_binary(%FirmwareConfig{} = config) do
    WireMessage.new(message: {:firmware_config, config})
    |> WireMessage.encode()
  end

  def event_binary(%FadeOutEvent{} = event) do
    WireMessage.new(message: {:fade_out_event, event})
    |> WireMessage.encode()
  end

  ### Helpers ###################################################################################

  defp modifier_field_index(%Command{} = command, name) do
    {_, index} =
      command
      |> list_modifier_names()
      |> Enum.with_index()
      |> Enum.find(&match?({^name, _}, &1))

    index
  end

  defp insert_and_notify(%Command{} = command) do
    command
    |> Cache.insert()
    |> tap(&notify_subscribers/1)
  end

  defp maybe_fill_commands(commands, false), do: commands

  defp maybe_fill_commands(commands, true) do
    0..(@command_max_count - 1)
    |> Enum.map(fn index ->
      case Enum.find(commands, &match?(%Command{index: ^index}, &1)) do
        nil -> Command.disabled(index)
        %Command{} = command -> command
      end
    end)
  end
end
