defmodule StreamSwitcher do
  @moduledoc """
  Forwards buffers from the `:main` input up to and including the first buffer with
  `pts >= switch_time`, then forwards buffers from the `:ad` input until it ends, then resumes
  forwarding `:main` from where it was paused. If `:main` ended before the ad, the output ends
  with the ad.

  Timestamps of the output stream are shifted at each switch so that the output timeline
  is continuous.

  Only the currently active input is demanded from, one buffer at a time, so the inactive
  stream is never pulled ahead and no buffer arrives after the active input has changed.

  Both inputs must carry the same stream format. It is sent to the output only once, when
  received for the first time; a differing format on the other input raises.
  """
  use Membrane.Filter

  alias Membrane.{Buffer, Time}

  def_input_pad :main,
    accepted_format: _any,
    flow_control: :manual,
    demand_unit: :buffers

  def_input_pad :ad,
    accepted_format: _any,
    flow_control: :manual,
    demand_unit: :buffers

  def_output_pad :output,
    accepted_format: _any,
    flow_control: :manual,
    demand_unit: :buffers

  def_options switch_time: [
                spec: Time.t(),
                inspector: &Time.inspect/1,
                description: "Timestamp of the `:main` stream at which the ad is inserted."
              ]

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            switch_time: Time.t(),
            stream_format: struct() | nil,
            active: :main | :ad,
            main_eos?: boolean(),
            ad_eos?: boolean(),
            offset: Time.t() | nil,
            # Assumes constant frame rate: the duration of the last frame is estimated
            # from the gap between it and the frame before it.
            last_frame: {pts :: Time.t(), estimated_duration :: Time.t()} | nil
          }

    @enforce_keys [:switch_time]
    defstruct @enforce_keys ++
                [
                  stream_format: nil,
                  active: :main,
                  main_eos?: false,
                  ad_eos?: false,
                  offset: nil,
                  last_frame: nil
                ]
  end

  @impl true
  def handle_init(_ctx, opts) do
    {[], %State{switch_time: opts.switch_time}}
  end

  @impl true
  def handle_stream_format(_pad, stream_format, _ctx, %State{stream_format: nil} = state) do
    {[stream_format: {:output, stream_format}], %State{state | stream_format: stream_format}}
  end

  @impl true
  def handle_stream_format(
        _pad,
        stream_format,
        _ctx,
        %State{stream_format: stream_format} = state
      ) do
    {[], state}
  end

  @impl true
  def handle_stream_format(pad, stream_format, _ctx, %State{} = state) do
    raise """
    Stream format received on pad #{inspect(pad)} differs from the one received previously.
    Both input pads of #{inspect(__MODULE__)} must carry the same stream format.
    Previously received: #{inspect(state.stream_format)}
    Received now: #{inspect(stream_format)}
    """
  end

  @impl true
  def handle_demand(:output, _size, :buffers, _ctx, %State{active: active} = state) do
    {[demand: {active, 1}], state}
  end

  @impl true
  def handle_buffer(:main, %Buffer{} = buffer, _ctx, %State{active: :main} = state) do
    {buffer_actions, state} = forward(buffer, state)

    {next_actions, state} =
      if state.ad_eos? or buffer.pts < state.switch_time do
        {[redemand: :output], state}
      else
        switch_to(:ad, state)
      end

    {buffer_actions ++ next_actions, state}
  end

  @impl true
  def handle_buffer(:ad, %Buffer{} = buffer, _ctx, %State{active: :ad} = state) do
    {buffer_actions, state} = forward(buffer, state)
    {buffer_actions ++ [redemand: :output], state}
  end

  @impl true
  def handle_end_of_stream(:main, _ctx, %State{} = state) do
    maybe_terminate(%State{state | main_eos?: true})
  end

  @impl true
  def handle_end_of_stream(:ad, _ctx, %State{} = state) do
    maybe_terminate(%State{state | ad_eos?: true})
  end

  defp maybe_terminate(state) do
    cond do
      state.main_eos? and state.ad_eos? -> {[end_of_stream: :output], state}
      state.main_eos? -> switch_to(:ad, state)
      true -> switch_to(:main, state)
    end
  end

  defp switch_to(pad, %State{} = state) do
    {[redemand: :output], %State{state | active: pad, offset: nil}}
  end

  defp forward(%Buffer{} = buffer, %State{offset: nil} = state) do
    offset =
      case state.last_frame do
        nil -> 0
        {last_pts, estimated_duration} -> last_pts + estimated_duration - buffer.pts
      end

    forward(buffer, %State{state | offset: offset})
  end

  defp forward(%Buffer{pts: pts, dts: dts} = buffer, %State{offset: offset} = state) do
    out_pts = pts + offset
    out_dts = dts && dts + offset
    buffer = %Buffer{buffer | pts: out_pts, dts: out_dts}

    estimated_duration =
      case state.last_frame do
        nil -> 0
        {last_pts, _estimated_duration} -> out_pts - last_pts
      end

    {[buffer: {:output, buffer}], %State{state | last_frame: {out_pts, estimated_duration}}}
  end
end
