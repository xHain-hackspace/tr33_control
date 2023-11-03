defmodule Tr33Control.ESP do
  use Supervisor
  require Logger

  alias Tr33Control.ESP.{UDP, UDPSupervisor}
  alias Tr33Control.Commands.Schemas.{TargetMetrics, FirmwareConfig}

  @pubsub_topic "esp"
  @udp_registry :udp_targets
  @target_configs Application.compile_env!(:tr33_control, :target_configs)

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
      [{pid, _}] ->
        UDP.handle_metrics(pid, tm)

      _ ->
        # todo: notify subscribers that a new target has been discovered
        {:ok, _pid} = UDPSupervisor.start_child(from_ip, tm)
    end
  end

  def register_target(ip) do
    {:ok, _pid} = Registry.register(@udp_registry, ip, :foo)
  end

  def list_targets() do
    UDPSupervisor.children()
    |> Enum.map(fn {_, pid, _, [UDP]} -> {pid, UDP.get_metrics(pid)} end)
    |> maybe_add_mock_targets(Application.fetch_env!(:tr33_control, :add_mock_targets))
  end

  def active_targets() do
    list_targets()
    |> Enum.map(fn {_pid, %TargetMetrics{} = tm} -> get_target_from_metrics(tm) end)
    |> Enum.uniq()
  end

  def get_strip_indices_for_target(target) do
    list_targets()
    |> Enum.find(fn {_pid, %TargetMetrics{} = tm} -> get_target_from_metrics(tm) == target end)
    |> case do
      {_, %TargetMetrics{max_strip_index: nil}} ->
        []

      {_, %TargetMetrics{max_strip_index: max_strip_index}} ->
        0..max_strip_index
        |> Enum.into([])

      nil ->
        Logger.warning("#{__MODULE__}: could not find active process for target: #{inspect(target)}")
        []
    end
  end

  def get_target_from_metrics(%TargetMetrics{name: name}) do
    @target_configs
    |> Enum.filter(&match?({_, %{name_regex: _}}, &1))
    |> Enum.filter(fn {_, %{name_regex: regex}} -> Regex.match?(regex, name) end)
    |> case do
      [] -> String.downcase(name) |> String.to_atom()
      [{target, _} | _] -> target
    end
  end

  def maybe_add_mock_targets([], true) do
    for n <- 1..2 do
      {nil,
       %TargetMetrics{
         name: "test_target_#{n}",
         fps: 42,
         wifi_strength: 23,
         version: DateTime.utc_now() |> DateTime.to_unix() |> Integer.to_string(),
         hashes: [],
         max_strip_index: 1
       }}
    end
  end

  def maybe_add_mock_targets(targets, _), do: targets

  def broadcast_firmware_config(%FirmwareConfig{} = config) do
    list_targets()
    |> Enum.map(fn {pid, _} -> UDP.send_firmware_config(pid, config) end)
  end
end
