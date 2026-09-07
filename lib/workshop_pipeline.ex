defmodule WorkshopPipeline do
  @moduledoc false
  use Membrane.Pipeline

  require Membrane.Logger

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  @impl true
  def handle_init(_ctx, _opts) do
    # :ivf_file_source --> :ivf_deserializer --> :video_decoder --> :color_inverter
    #   --> :pixel_format_converter --> :realtimer --> :sdl_player
    spec =
      child(:ivf_file_source, %Membrane.File.Source{location: "assets/bbb_vp8.ivf"})
      |> child(:ivf_deserializer, Membrane.IVF.Deserializer)
      |> child(:video_decoder, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :RGB}
        ]
      )
      |> child(:color_inverter, ColorInverter)
      |> child(:pixel_format_converter, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :I420}
        ]
      )
      |> child(:realtimer, Membrane.Realtimer)
      |> child(:sdl_player, Membrane.SDL.Player)

    {[spec: spec], %State{}}
  end

  @impl true
  def handle_element_end_of_stream(:sdl_player, _pad, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end
