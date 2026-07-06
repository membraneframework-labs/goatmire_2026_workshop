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
    # :ivf_file_source --> :ivf_deserializer --> :video_transcoder
    #                                                   |
    #                                                   \/ 
    #                                                :mp4_muxer --> :mp4_file_sink
    #                                                   ^ 
    #                                                   |
    # :mp3_file_source ------------------------> :audio_transcoder
    spec = [
      child(:ivf_file_source, %Membrane.File.Source{location: "assets/bbb_vp8.ivf"})
      |> child(:ivf_deserializer, Membrane.IVF.Deserializer)
      |> child(:video_transcoder, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.H264{stream_structure: :avc1}
        ]
      )
      |> child(:mp4_muxer, Membrane.MP4.Muxer.ISOM)
      |> child(:mp4_file_sink, %Membrane.File.Sink{location: "result.mp4"}),
      child(:mp3_file_source, %Membrane.File.Source{
        location: "assets/bbb.mp3",
        content_format: Membrane.MPEGAudio
      })
      |> child(:audio_transcoder, Membrane.Transcoder)
      |> via_out(:output,
        options: [
          output_stream_format: %Membrane.Transcoder.OutputFormat.AAC{config: :esds}
        ]
      )
      |> get_child(:mp4_muxer)
    ]

    {[spec: spec], %State{}}
  end

  @impl true
  def handle_element_end_of_stream(:mp4_file_sink, _pad, _ctx, state) do
    {[terminate: :normal], state}
  end

  @impl true
  def handle_element_end_of_stream(_element, _pad, _ctx, state) do
    {[], state}
  end
end
