defmodule ColorInverter do
  @moduledoc false
  use Membrane.Filter

  require Membrane.Logger

  def_input_pad :input,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    flow_control: :auto

  def_output_pad :output,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    flow_control: :auto

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  @impl true
  def handle_init(_ctx, _opts) do
    {[], %State{}}
  end

  @impl true
  def handle_buffer(_pad, %Membrane.Buffer{} = buffer, _ctx, state) do
    inverted_frame = invert_frame(buffer.payload)
    buffer = %Membrane.Buffer{buffer | payload: inverted_frame}

    {[broadcast: buffer], state}
  end

  @spec invert_frame(binary()) :: binary()
  defp invert_frame(frame) do
    frame
    |> :binary.bin_to_list()
    |> Enum.map(&(255 - &1))
    |> :binary.list_to_bin()
  end
end
