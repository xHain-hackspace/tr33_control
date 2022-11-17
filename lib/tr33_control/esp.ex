defmodule Tr33Control.ESP do
  use Supervisor
  require Logger

  alias Tr33Control.ESP.{UDP, UDPSupervisor}
  alias Tr33Control.Commands.Schemas.TargetMetrics

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
    children = [
      {Registry, [keys: :unique, name: @udp_registry]},
      UDPSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  ### External API ###########################################

  def subscribe(), do: Phoenix.PubSub.subscribe(Tr33Control.PubSub, @pubsub_topic)
  def notify_subscribers(message), do: Phoenix.PubSub.broadcast!(Tr33Control.PubSub, @pubsub_topic, message)

  def send_connection_states() do
    notify_subscribers(:send_state)
  end

  def time_sync(), do: notify_subscribers(:time_sync)

  def resync(), do: notify_subscribers(:resync)

  def handle_metrics(from_ip, %TargetMetrics{} = tm) do
    case Registry.lookup(@udp_registry, from_ip) do
      [{pid, :udp}] ->
        UDP.handle_metrics(pid, tm)

      _ ->
        {:ok, _pid} = UDPSupervisor.start_child(from_ip, tm)
    end
  end

  def register_target(ip) do
    {:ok, _pid} = Registry.register(@udp_registry, ip, :udp)
  end
end
