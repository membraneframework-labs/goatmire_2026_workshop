defmodule WorkshopPipeline do
  @moduledoc false
  use Membrane.Pipeline

  @switch_time Membrane.Time.seconds(15)
  @raw_audio_format %Membrane.Transcoder.OutputFormat.RawAudio{
    sample_format: :s16le,
    sample_rate: 44_100,
    channels: 2
  }

  require Membrane.Logger

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{ended_sinks: MapSet.t(Membrane.Child.name())}

    defstruct ended_sinks: MapSet.new()
  end

  @impl true
  def handle_init(_ctx, _opts) do
    # :ivf_file_source --> :ivf_deserializer --> :video_decoder --> :color_inverter --> :video_stream_switcher
    # :ad_ivf_file_source --> :ad_ivf_deserializer --> :ad_video_decoder ---------------------^
    # :video_stream_switcher --> :pixel_format_converter --> :realtimer --> :sdl_player
    #
    # :mp3_file_source --> :audio_decoder --> :audio_timestamper --> :audio_stream_switcher --> :portaudio_sink
    # :ad_mp3_file_source --> :ad_audio_decoder --> :ad_audio_timestamper ---------^
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
      |> child(:video_stream_switcher, %StreamSwitcher{switch_time: @switch_time})
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
      |> get_child(:video_stream_switcher),
      child(:mp3_file_source, %Membrane.File.Source{
        location: "assets/bbb.mp3",
        content_format: Membrane.MPEGAudio
      })
      |> child(:audio_decoder, Membrane.Transcoder)
      |> via_out(:output, options: [output_stream_format: @raw_audio_format])
      |> child(:audio_timestamper, %Membrane.RawAudioParser{overwrite_pts?: true})
      |> via_in(:main)
      |> child(:audio_stream_switcher, %StreamSwitcher{switch_time: @switch_time})
      |> child(:portaudio_sink, Membrane.PortAudio.Sink),
      child(:ad_mp3_file_source, %Membrane.File.Source{
        location: "assets/ad.mp3",
        content_format: Membrane.MPEGAudio
      })
      |> child(:ad_audio_decoder, Membrane.Transcoder)
      |> via_out(:output, options: [output_stream_format: @raw_audio_format])
      |> child(:ad_audio_timestamper, %Membrane.RawAudioParser{overwrite_pts?: true})
      |> via_in(:ad)
      |> get_child(:audio_stream_switcher)
    ]

    {[spec: spec], %State{}}
  end

  @impl true
  def handle_element_end_of_stream(sink, _pad, _ctx, %State{} = state)
      when sink in [:sdl_player, :portaudio_sink] do
    state = %State{state | ended_sinks: MapSet.put(state.ended_sinks, sink)}

    if MapSet.size(state.ended_sinks) == 2 do
      {[terminate: :normal], state}
    else
      {[], state}
    end
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end
