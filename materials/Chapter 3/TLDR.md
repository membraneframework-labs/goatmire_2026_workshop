# Chapter 3 - Timestamps and flow control in Membrane - TLDR

[README.md](./README.md) goes over everything in detail - this file will be more concise
and won't explain everything step by step. If you feel like you understand
everything needed for this chapter then this version should suffice, however if
you are ever unsure about something, it's probably explained in the README.

## Tasks

There are three tasks, each built on top of the previous one. Start from the `chapter-2-checkpoint`
branch, the final solution is on `chapter-3-checkpoint`.

Add these deps to `mix.exs` and run `mix deps.get`:

```elixir
      # Chapter 3 deps
      {:membrane_realtimer_plugin, "~> 0.11.1"},
      {:membrane_sdl_plugin, "~> 0.18.8"},
      {:membrane_portaudio_plugin, "~> 0.19.6"},
      {:membrane_raw_audio_parser_plugin, "~> 0.5.0"}
```

### Task 3.1 - Play the video in real time

Replace the MP4 muxing with playback on screen and drop the audio branch for now.
The output of `ColorInverter` should end up in
[`Membrane.SDL.Player`](https://membrane-sdl-plugin.hexdocs.pm/Membrane.SDL.Player.html),
played at natural speed.

You will need to use the following elements:
- `Membrane.SDL.Player` - it accepts only `I420` raw video, so put another
  `Membrane.Transcoder` after `ColorInverter` with
  `output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :I420}`.
- [`Membrane.Realtimer`](https://membrane-realtimer-plugin.hexdocs.pm/Membrane.Realtimer.html)
  releases each buffer when its timestamp comes, so the video plays at its
  natural speed. Put it right before the player.
  
Remember to terminate the pipeline when the player reports end of stream.

### Task 3.2 - Insert an ad

Write a `StreamSwitcher` filter with `:main` and `:ad` input pads and one
`:output` pad. It takes a `switch_time` option (a `Membrane.Time` value) and:

1. forwards `:main` up to and including the first buffer with `pts >= switch_time`,
2. forwards `:ad` until it ends,
3. forwards `:main` again from where it was paused,
4. ends the output when both inputs have ended. If `:main` ends before the
   switch time, switch to `:ad` right away and end after it.

Key points:

- **Flow control.** Declare all pads with `flow_control: :manual`. In
  `handle_demand/5` return `demand: {active_pad, 1}` for the currently active
  input only - one buffer at a time, so nothing arrives from `:main` after
  you've switched to `:ad`. Return `redemand: :output` along with every
  buffer you send and whenever the active pad changes, otherwise
  `handle_demand/5` won't be called again.
- **Timestamps.** Output timeline must be continuous, or the Realtimer will
  stall. At each switch compute an offset so the first buffer of the new
  segment lands one frame after the last buffer sent, and add it to `pts` (and `dts`) of
  every buffer of that segment.
- **Stream format.** Forward the first one received, assert the other pad's is
  the same.
- **End of stream.** `handle_end_of_stream/3` is called per pad. Track which
  pads have ended.

Plug it in right after `ColorInverter`. The ad branch reads `assets/ad_vp8.ivf`
and decodes it the same way as the main video (deserializer and `Transcoder`
to `RGB` raw video) - it is guaranteed to have the same stream format as the
main stream. Use `via_in/2` to link the branches to the `:main` and `:ad` pads.

### Task 3.3 - Bring the audio back

Add an audio branch: read `assets/bbb.mp3`, decode it to raw audio with
`Membrane.Transcoder`, pass it through its own `StreamSwitcher` (same
`switch_time`) and play it with
[`Membrane.PortAudio.Sink`](https://membrane-portaudio-plugin.hexdocs.pm/Membrane.PortAudio.Sink.html).
The ad audio is in `assets/ad.mp3` - decode it the same way and link it to the
`:ad` pad.

A few things to consider:
- MP3 buffers have no timestamps, so put
  [`Membrane.RawAudioParser`](https://membrane-raw-audio-parser-plugin.hexdocs.pm/Membrane.RawAudioParser.html)
  with `overwrite_pts?: true` between each decoder and the switcher - it
  computes `pts` from the amount of audio that flowed through.
- Both audio inputs must have the same stream format. Pin it in both
  `Transcoder`s, they will resample if needed:

  ```elixir
  %Membrane.Transcoder.OutputFormat.RawAudio{
    sample_format: :s16le,
    sample_rate: 44_100,
    channels: 2
  }
  ```
- The sink demands in bytes. Declare `demand_unit: :buffers` on the switcher's
  output pad, so Membrane knows that it needs to convert between units.
- Terminate the pipeline only after both `:sdl_player` and `:portaudio_sink`
  reported end of stream.

The pipeline can be run the same way as in the previous tasks, with
`mix run run_pipeline.exs`.
