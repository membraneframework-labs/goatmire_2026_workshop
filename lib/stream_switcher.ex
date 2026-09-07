defmodule StreamSwitcher do
  @moduledoc """
  Forwards buffers from the `:main` input until `switch_time` is reached, then forwards
  buffers from the `:ad` input until it ends, then resumes forwarding `:main` from the frame
  at which it was paused. If `:main` ended before the ad, the output ends with the ad.

  Timestamps of the output stream are shifted at each switch so that the output timeline
  is continuous.

  Only the currently active input is demanded from, so the inactive stream is not pulled ahead.

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
            pending_main_buffers: [Buffer.t()],
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
                  pending_main_buffers: [],
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
  def handle_demand(:output, size, :buffers, _ctx, %State{active: active} = state) do
    {[demand: {active, size}], state}
  end

  @impl true
  def handle_buffer(:main, %Buffer{} = buffer, _ctx, %State{active: :main} = state) do
    if state.ad_eos? or buffer.pts < state.switch_time do
      forward(buffer, state)
    else
      state = %State{state | pending_main_buffers: [buffer]}
      switch_to(:ad, state)
    end
  end

  @impl true
  def handle_buffer(:ad, %Buffer{} = buffer, _ctx, %State{active: :ad} = state) do
    forward(buffer, state)
  end

  @impl true
  def handle_buffer(:main, %Buffer{} = buffer, _ctx, %State{active: :ad} = state) do
    {[], %State{state | pending_main_buffers: state.pending_main_buffers ++ [buffer]}}
  end

  @impl true
  def handle_buffer(:ad, _buffer, _ctx, %State{active: :main} = state) do
    {[], state}
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
    state = %State{state | active: pad, offset: nil}

    {buffer_actions, state} =
      case pad do
        :main ->
          flush_pending_buffers(state)

        :ad ->
          {[], state}
      end

    {buffer_actions ++ [redemand: :output], state}
  end

  defp flush_pending_buffers(%State{} = state) do
    Enum.flat_map_reduce(
      state.pending_main_buffers,
      %State{state | pending_main_buffers: []},
      &forward/2
    )
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
