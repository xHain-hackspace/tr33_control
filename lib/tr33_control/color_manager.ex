defmodule Tr33Control.ColorManager do
  use GenServer
  require Logger

  alias Tr33Control.Commands
  alias Tr33Control.Commands.Command
  alias Tr33Control.ColorManager.CommandConfig

  @command_max_count Application.compile_env!(:tr33_control, :command_max_count)
  @enabled_for_commands [:pixel_func]

  defmodule State do
    defstruct [:configs]
  end

  # Public API
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def command_supported?(%Command{} = command) do
    Command.type(command) in @enabled_for_commands
  end

  # GenServer callbacks
  def init(_) do
    configs = 0..@command_max_count |> Enum.map(fn index -> {index, CommandConfig.new()} end) |> Enum.into(%{})
    state = %State{configs: configs}

    :timer.send_interval(1000, :update)

    {:ok, state}
  end

  def handle_info(:update, %State{} = state) do
    configs =
      Commands.list_commands()
      |> Enum.filter(&command_supported?/1)
      |> Enum.reduce(state.configs, fn %Command{index: index}, state_acc ->
        Map.update!(state_acc, index, fn config -> CommandConfig.maybe_change_colors(config, index) end)
      end)

    {:noreply, %State{state | configs: configs}}
  end
end
