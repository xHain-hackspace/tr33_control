defmodule Tr33Control.Commands.Cache do
  require Logger
  alias Tr33Control.Commands
  alias Tr33Control.Commands.{Command, Preset}

  @all_cache_keys [Command, Preset]

  def init_all() do
    Enum.map(@all_cache_keys, &init/1)
  end

  def init(Command) do
  end

  def init(Preset) do
    if File.exists?(presets_persist_file()) do
      Logger.info("Loading persisted presets from #{inspect(presets_persist_file())}")
      File.read!(presets_persist_file()) |> :erlang.binary_to_term()
      Cachex.load!(Preset, presets_persist_file())
      Enum.map(@all_cache_keys, &migrate/1)
    else
      Logger.warn("No preset persist file found #{inspect(presets_persist_file())}")
    end
  end

  def clear_all() do
    Enum.map(@all_cache_keys, &clear/1)
  end

  def clear(key) do
    Cachex.clear!(key)
  end

  def insert(%Command{index: index} = command) do
    command
    |> Command.encode()
    |> tap(&Cachex.put!(Command, index, &1))
  end

  def insert(%Preset{name: name} = preset) do
    Cachex.put!(Preset, name, preset)
    Cachex.dump!(Preset, presets_persist_file())
    preset
  end

  def get(cache, key) when cache in @all_cache_keys do
    Cachex.get!(cache, key)
  end

  def all(cache) when cache in @all_cache_keys do
    query = Cachex.Query.create(true, :value)

    cache
    |> Cachex.stream!(query)
    |> Enum.into([])
  end

  def count(cache) when cache in @all_cache_keys do
    Cachex.count!(cache)
  end

  def delete(cache, key) when cache in @all_cache_keys do
    res = Cachex.take(cache, key)
    res
  end

  defp presets_persist_file() do
    Application.fetch_env!(:tr33_control, :cache_persist_dir) |> Path.join("presets2.bin")
  end

  defp migrate(Preset = cache) do
    all(cache)
    |> Enum.map(&struct!(Preset, Map.delete(&1, :__struct__)))
    |> Enum.map(fn %Preset{commands: commands} = preset ->
      commands =
        commands
        |> Enum.map(&struct!(Command, Map.drop(&1, [:__struct__])))
        |> Enum.map(&migrate_command/1)

      %Preset{preset | commands: commands}
    end)
    |> Enum.map(&insert/1)
  end

  defp migrate(_), do: :noop

  defp migrate_command(%Command{encoded: nil} = command) do
    Logger.error("Error loading command. Nil encoding: #{inspect(command)}")
    Commands.Command.new(command.index, :single_color)
  end

  defp migrate_command(%Command{encoded: encoded} = command) do
    %Command{command | params: Commands.Schemas.CommandParams.decode(encoded)}
  end

  # defp migrate_target(%Command{target: "all"} = command), do: %Command{command | target: :all}
  # defp migrate_target(%Command{target: nil} = command), do: %Command{command | target: :all}
  # defp migrate_target(%Command{} = command), do: command
end
