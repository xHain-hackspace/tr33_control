defmodule Tr33Control.ESP do
  use Supervisor
  require Logger

  alias Tr33Control.ESP.{UDP, UART}

  @pubsub_topic "esp"

  @udp_registry :udp_targets

  ### Supervisor ##############################################

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def children() do
    Supervisor.which_children(__MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children =
      [
        {Registry, [keys: :unique, name: @udp_registry]}
        # Tr33Control.ESP.Poller
        # UART
      ] ++ udp_children()

    Supervisor.init(children, strategy: :one_for_one)
  end

  ### External API ###########################################

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @pubsub_topic)

  def handle_udp_sequence(address, _port, sequence) do
    case Registry.lookup(@udp_registry, address) do
      [{pid, _target}] ->
        GenServer.cast(pid, {:sequence, sequence})

      _ ->
        "#{__MODULE__}: Can't handle squence message, #{inspect(address)} is not registered. Trying to reconnect"
        |> Logger.info()

        udp_reconnect()
    end
  end

  def udp_reconnect() do
    for %{id: child_id} <- udp_children() do
      Supervisor.restart_child(__MODULE__, child_id)
    end
  end

  def time_sync() do
    Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @pubsub_topic, :time_sync)
  end

  ### Helper ##########################################

  defp process_name(host) do
    {:via, Registry, {@udp_registry, host}}
  end

  def udp_children() do
    targets = Application.fetch_env!(:tr33_control, :targets)
    hosts = Application.fetch_env!(:tr33_control, :target_hosts)

    targets
    |> Enum.flat_map(fn target ->
      hosts
      |> Map.get(target, [])
      |> Enum.map(fn host ->
        %{
          id: host,
          start: {UDP, :start_link, [{target, host, process_name(host)}]}
        }
      end)
    end)
  end
end
