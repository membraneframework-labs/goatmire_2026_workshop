defmodule WorkshopPipeline do
  @moduledoc false
  use Membrane.Pipeline

  @switch_time Membrane.Time.seconds(15)

  require Membrane.Logger

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{}

    defstruct []
  end

  @impl true
  def handle_init(_ctx, _opts) do
    # :ivf_file_source --> :ivf_deserializer --> :video_decoder --> :color_inverter --> :stream_switcher
    # :ad_ivf_file_source --> :ad_ivf_deserializer --> :ad_video_decoder ---------------------^
    # :stream_switcher --> :pixel_format_converter --> :realtimer --> :sdl_player
    spec = [
      child(:ivf_file_source, %Membrane.File.Source{location: "assets/bbb_vp8.ivf"})
      |> child(:ivf_deserializer, Membrane.IVF.Deserializer)
      |> child(:video_decoder, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :RGB}
        ]
      )
      |> child(:color_inverter, ColorInverter)
      |> via_in(:main)
      |> child(:stream_switcher, %StreamSwitcher{switch_time: @switch_time})
      |> child(:pixel_format_converter, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :I420}
        ]
      )
      |> child(:realtimer, Membrane.Realtimer)
      |> child(:sdl_player, Membrane.SDL.Player),
      child(:ad_ivf_file_source, %Membrane.File.Source{location: "assets/ad_vp8.ivf"})
      |> child(:ad_ivf_deserializer, Membrane.IVF.Deserializer)
      |> child(:ad_video_decoder, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :RGB}
        ]
      )
      |> via_in(:ad)
      |> get_child(:stream_switcher)
    ]

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
