defmodule Tr33Control.Homeassistant do
  use GenServer
  require Logger

  alias Homeassistant.Devices.Select
  alias Tr33Control.Commands.Preset
  alias Tr33Control.Commands

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    select =
      %Select{
        name: "Tr33 Presets"
      }
      |> update_options()

    Select.subscribe(select)
    Commands.subscribe_presets()

    {:ok, select}
  end

  def handle_info(:preset_update, select) do
    select = update_options(select)

    {:noreply, select}
  end

  def handle_info({:preset_loaded, preset_name}, select) do
    Select.set_state(select, preset_name)

    {:noreply, select}
  end

  def handle_info({:homeassistant_command, _, preset_name}, select) do
    Commands.load_preset(preset_name)
    {:noreply, select}
  end

  def handle_info(data, socket) do
    Logger.warning("#{__MODULE__}: Unhandled info #{inspect(data)}")
    {:noreply, socket}
  end

  defp update_options(%Select{} = select) do
    options =
      Commands.list_presets()
      |> Enum.map(fn %Preset{name: name} -> name end)

    select = %Select{select | options: options}

    Select.configure(select)

    select
  end
end
