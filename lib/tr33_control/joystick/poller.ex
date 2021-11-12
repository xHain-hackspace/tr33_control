defmodule Tr33Control.Joystick.Poller do
  use GenServer
  require Logger

  @poll_interval 5_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(_) do
    :timer.send_interval(@poll_interval, :poll)
    {:ok, %{}}
  end

  def handle_info(:poll, state) do
    Supervisor.restart_child(Tr33Control.Supervisor, Tr33Control.Joystick)
    {:noreply, state}
  end
end
