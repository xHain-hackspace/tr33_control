defmodule Tr33Control.Commands do
  alias __MODULE__.{Schemas, Command, Cache, ValueParam, EnumParam, Preset}
  alias __MODULE__.Schemas.{CommandParams, Modifier, WireMessage, TimeSync}

  @command_targets Application.compile_env!(:tr33_control, :targets)
  @commands_topic "command_updates"
  @presets_topic "preset_updates"
  @common_params %CommandParams{} |> Map.from_struct() |> Map.delete(:type_params) |> Map.keys()

  def init() do
    Cache.init_all()

    case get_default_preset() do
      nil ->
        create_command(0, :rainbow)

      %Preset{commands: commands} ->
        Enum.map(commands, &Cache.insert/1)
    end
  end

  ### PubSub #######################################################################

  def subscribe_commands(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @commands_topic)
  def subscribe_presets(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @presets_topic)

  def notify_subscribers(%Command{} = command) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @commands_topic, {:command_update, command})
  end

  def notify_subscribers(%Preset{} = preset) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @presets_topic, {:preset_update, preset})
  end

  def notify_subscribers(:preset_deleted, name) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @presets_topic, {:preset_deleted, name})
  end

  def notify_subscribers(:command_deleted, index) do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @commands_topic, {:command_deleted, index})
  end

  ### Commands ########################################################################################################

  def command_types() do
    %Protobuf.OneOfField{fields: fields} = Schemas.CommandParams.defs(:field, :type_params)

    fields
    |> Enum.map(fn %Protobuf.Field{name: name} -> name end)
  end

  def get_command(index) do
    Cache.get(Command, index)
  end

  def list_commands(opts \\ []) do
    include_empty = Keyword.get(opts, :include_empty, false)

    Cache.all(Command)
    |> Enum.sort_by(fn %Command{} = c -> c.index end)
    |> maybe_fill_commands(include_empty)
  end

  def create_command(index, type, params \\ []) when is_atom(type) and is_number(index) and is_list(params) do
    Command.new(index, type, params)
    |> insert_and_notify()
  end

  def create_command(protobuf) when is_binary(protobuf) do
    Command.new(protobuf)
    |> insert_and_notify()
  end

  def delete_command(index) do
    count = Cache.count(Command)

    if count > 1 do
      {_before_delete, after_deleted} =
        Cache.all(Command)
        |> Enum.split(index)

      after_deleted
      |> tl()
      |> Enum.with_index(index)
      |> Enum.map(fn {%Command{} = command, new_index} ->
        %Command{command | index: new_index}
      end)
      |> Enum.map(&insert_and_notify/1)

      Cache.delete(Command, count - 1)
      notify_subscribers(:command_deleted, index)
    end
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

  def toggle_command_target(index, target) when target in @command_targets do
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

  ### Command Params: EnumParam + ValueParam ###############################################################################

  def list_value_params(%Command{} = command) do
    type_params = Command.type_params(command)

    Command.list_type_field_defs(command)
    |> Enum.map(&ValueParam.new(type_params, &1))
    |> Enum.reject(&is_nil/1)
  end

  def list_enum_params(%Command{} = command) do
    type_params = Command.type_params(command)

    Command.list_type_field_defs(command)
    |> Enum.map(&EnumParam.new(type_params, &1))
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

  def list_common_params() do
    @common_params
  end

  def get_strip_index_options(%Command{targets: [target]}) do
    Application.fetch_env!(:tr33_control, :target_strip_indices)
    |> Map.get(target, [])
    |> Enum.with_index()
  end

  def get_strip_index_options(%Command{}), do: []

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

  def create_preset(name) when is_binary(name) do
    preset =
      case Cache.get(Preset, name) do
        nil -> %Preset{name: name}
        preset -> preset
      end

    %Preset{preset | commands: list_commands()}
    |> Cache.insert()
    |> tap(&notify_subscribers/1)
  end

  def delete_preset(name) do
    Cache.delete(Preset, name)
    notify_subscribers(:preset_deleted, name)
  end

  def load_preset(name) do
    %Preset{commands: commands} = preset = Cache.get(Preset, name)

    previous_count = count_commands()
    new_count = Enum.count(commands)

    if previous_count > new_count do
      (previous_count - 1)..new_count
      |> Enum.map(&delete_command/1)
    end

    commands
    |> Enum.map(&insert_and_notify/1)

    preset
  end

  def list_presets() do
    Cache.all(Preset)
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

    load_preset(name)
    |> then(fn preset -> %Preset{preset | default: true} end)
    |> Cache.insert()
    |> notify_subscribers()
  end

  ### Protobuf ###################################################################################

  def time_sync_binary() do
    time_sync = TimeSync.new(millis: System.os_time(:millisecond))

    WireMessage.new(message: {:time_sync, time_sync}, sequence: 0)
    |> WireMessage.encode()
  end

  def command_binary(%Command{index: index, targets: targets} = command, target, sequence) do
    %Command{params: %CommandParams{} = params} =
      if target in targets do
        command
      else
        Command.disabled(index)
      end

    WireMessage.new(sequence: sequence, message: {:command_params, params})
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
    max = Application.fetch_env!(:tr33_control, :command_max_index)

    case Enum.count(commands) do
      ^max -> commands
      count -> commands ++ Enum.map(count..(max - 1), &Command.disabled/1)
    end
  end
end
