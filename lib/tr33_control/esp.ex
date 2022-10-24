defmodule Tr33Control.ESP do
  use Supervisor
  require Logger

  alias Tr33Control.ESP.{UDP}

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
        {Registry, [keys: :unique, name: @udp_registry]},
        Tr33Control.ESP.Poller
        # UART
      ] ++ udp_children()

    Supervisor.init(children, strategy: :one_for_one)
  end

  ### External API ###########################################

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @pubsub_topic)
  def notify_subscribers(message), do: Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @pubsub_topic, message)

  def reconnect() do
    for %{id: child_id} <- udp_children() do
      Supervisor.restart_child(__MODULE__, child_id)
    end
  end

  def send_connection_states() do
    notify_subscribers(:send_state)
    reconnect()
  end

  def time_sync(), do: notify_subscribers(:time_sync)

  def resync(), do: notify_subscribers(:resync)

  def handle_metrics(from_ip, metrics) do
    case Registry.lookup(@udp_registry, from_ip) do
      [{_pid, _target}] -> :noop
      _ -> reconnect()
    end

    notify_subscribers({:metrics, from_ip, metrics})
  end

  ### Helper ##########################################

  defp process_name(host) do
    {:via, Registry, {@udp_registry, host}}
  end

  def udp_children() do
    Tr33Control.Targets.get_targets()
    |> Enum.flat_map(fn {target, %{hosts: hosts}} ->
      hosts
      |> Enum.map(fn host ->
        %{
          id: host,
          start: {UDP, :start_link, [{target, host, process_name(host)}]}
        }
      end)
    end)
  end
end
