defmodule Tr33Control.ESP.UDPSupervisor do
  use DynamicSupervisor
  require Logger

  alias Tr33Control.ESP.UDP
  alias Tr33Control.Commands.Schemas.TargetMetrics

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_child(ip, target_metrics = %TargetMetrics{}) do
    Logger.info("#{__MODULE__}: Starting UDP child for #{inspect(ip)}")
    spec = {UDP, {ip, target_metrics}}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def children() do
    DynamicSupervisor.which_children(__MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
