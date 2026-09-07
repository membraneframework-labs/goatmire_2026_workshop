defmodule WorkshopPipeline do
  @moduledoc """
  This is a generated template for a Membrane.Pipeline. Uncomment the snippets as necessary.
  """
  use Membrane.Pipeline

  @switch_time Membrane.Time.seconds(15)
  @raw_audio_format %Membrane.Transcoder.OutputFormat.RawAudio{
    sample_format: :s16le,
    sample_rate: 44_100,
    channels: 2
  }

  require Membrane.Logger

  defmodule State do
    # Using this struct is not strictly necessary, but it's considered a good practice
    # and is strongly encouraged. Having a state with static fields with defined
    # typespecs adds robustness to the codebase and can prevent many bugs.
    @moduledoc false

    # When you add new fields to the struct remember to add them to this spec too.
    @type t :: %__MODULE__{ended_sinks: MapSet.t(Membrane.Child.name())}

    defstruct ended_sinks: MapSet.new()
  end

  # -----------------
  # --- CALLBACKS ---
  # -----------------
  # These callbacks have been ordered as they are usually being executed in the lifecycle
  # of a typical Membrane component - see https://hexdocs.pm/membrane_core/components_lifecycle.html.
  # Most of them are optional and have default implementations, which are present here as commented out code.
  # Any exceptions to this rule are mentioned above the relevant callbacks.

  # By default this callback will return with state set to an empty map %{},
  # however we recommend using a dedicated State struct.
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

  # @impl true
  # def handle_setup(_ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_playing(_ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_info(message, _ctx, state) do
  #   Membrane.Logger.warning("""
  #   Received message but no handle_info callback has been specified. Ignoring.
  #   Message: #{inspect(message)}\
  #   """)
  #
  #   {[], state}
  # end

  # @impl true
  # def handle_child_setup_completed(_child, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_child_terminated(_child, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_child_playing(_child, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_element_start_of_stream(_element, _pad, _ctx, state) do
  #   {[], state}
  # end

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

  # @impl true
  # def handle_child_notification(notification, element, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_crash_group_down(_group_name, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_call(message, _ctx, state) do
  #   {[], state}
  # end

  # @impl true
  # def handle_terminate_request(_ctx, state) do
  #   {[terminate: :normal], state}
  # end

  # This callback doesn't have a default implementation, but will be called only 
  # if a `:start_timer` action has been executed. For more information and examples 
  # of timer usage see https://hexdocs.pm/membrane_core/timer.html.
  # @impl true
  # def handle_tick(timer_id, context, state) do
  #   ...
  # end

  # This callback doesn't have a default implementation and will be called only if 
  # a child removes it's own dynamic pad. If not implemented, the bin will crash. 
  # @impl true
  # handle_child_pad_removed(element, pad, ctx, state) do
  #   ...
  # end
end
