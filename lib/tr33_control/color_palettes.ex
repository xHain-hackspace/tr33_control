defmodule Tr33Control.ColorPalettes do
  use GenServer
  require Logger

  alias Tr33Control.Commands.Schemas.{ColorPaletteResponse, ColorPalette}

  alias Tr33Control.ESP

  defstruct palettes: %{}

  @interval 1_000
  @all_palettes ColorPalette.atoms()

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__}])
  end

  def update_palettes() do
    GenServer.cast(__MODULE__, :fetch_palette)
  end

  def handle_color_palette_response(%ColorPaletteResponse{} = response) do
    GenServer.cast(__MODULE__, {:color_palette_response, response})
  end

  def color_from_palette(palette, color_index) do
    GenServer.call(__MODULE__, {:color_from_palette, palette, color_index})
  end

  def init(_) do
    palettes =
      :code.priv_dir(:tr33_control)
      |> Path.join("color_palettes.bin")
      |> File.read()
      |> case do
        {:ok, data} ->
          Logger.info("Found persisted color palettes. Loading...")
          :erlang.binary_to_term(data)

        {:error, _} ->
          %{}
      end

    state = %__MODULE__{
      palettes: palettes
    }

    {:ok, state}
  end

  def handle_call({:color_from_palette, palette, color_index}, _from, %__MODULE__{} = state) do
    reply =
      case Map.fetch(state.palettes, palette) do
        {:ok, colors} ->
          Enum.at(colors, color_index)

        :error ->
          Logger.warn("#{__MODULE__} Palette does not exist: #{inspect(palette)}")
          {0, 0, 0}
      end

    {:reply, reply, state}
  end

  def handle_cast({:color_palette_response, %ColorPaletteResponse{} = response}, %__MODULE__{} = state) do
    Logger.info("Received color palette #{inspect(response.color_palette)}")

    color_tuples =
      response.colors
      |> Enum.map(fn int ->
        <<red::8, green::8, blue::8>> = <<int::24>>
        {red, green, blue}
      end)

    new_palettes = Map.put(state.palettes, response.color_palette, color_tuples)

    {:noreply, %__MODULE__{state | palettes: new_palettes}}
  end

  def handle_cast(:fetch_palette, state) do
    send(self(), :fetch_palette)
    # reset palettes
    {:noreply, %__MODULE__{state | palettes: %{}}}
  end

  def handle_info(:fetch_palette, state) do
    @all_palettes
    |> Enum.reject(&Map.has_key?(state.palettes, &1))
    |> case do
      [palette | _] ->
        send_color_palette_request(palette)
        :timer.send_after(@interval, :fetch_palette)

      [] ->
        path = Path.join(["priv", "color_palettes.bin"])
        Logger.info("All color palettes received. Persisting to #{path}")
        content = :erlang.term_to_binary(state.palettes)
        File.write!(path, content)
    end

    {:noreply, state}
  end

  def send_color_palette_request(palette) do
    {pid, _} =
      ESP.list_targets()
      |> Enum.random()

    Logger.info("Requesting color palette #{inspect(palette)}")
    ESP.UDP.color_palette_request(pid, palette)
  end
end
