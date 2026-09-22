# Chapter 4 - Real-time streaming with WebRTC

[DEEP_DIVE.md](./DEEP_DIVE.md) goes over everything in detail - this file will be more concise
and won't explain everything step by step. If you feel like you understand
everything needed for this chapter then this version should suffice, however if
you are ever unsure about something, it's probably explained in the deep dive.

## Task

Continue with your project from Chapter 3, or fall back on the
`chapter-3-checkpoint` branch if it doesn't work. The final solution is on
`chapter-4-checkpoint`. If you finished the main task and are looking for a
challenge, take a look at [BONUS_TASKS.md](./BONUS_TASKS.md).

The deps you'll need are already in `mix.exs`, and the two example pages from
the Boombox repository,
[`webrtc_to_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_to_browser.html)
and
[`webrtc_from_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_from_browser.html),
are already in `assets/`. Serve them over HTTP by starting the `AssetsServer`
from `lib/assets_server.ex`: add it to the children in
`lib/goatmire_2026_workshop/application.ex`:

```elixir
children = [
  {AssetsServer, port: 8000}
]
```

The component you'll use is [`Boombox.Bin`](https://hexdocs.pm/boombox/Boombox.Bin.html).
It's a sink when you set its `:output` option and a source when you set `:input`.
It has one dynamic pad per direction, up to one for audio and one for video,
chosen with the `kind: :audio | :video` pad option. A WebRTC endpoint is
`{:webrtc, "ws://localhost:PORT"}` - Boombox starts a WebSocket signaling server
on that port and waits for a browser to connect. It handles encoding and
decoding on its own.

### Send the stream to the browser

Replace `Membrane.SDL.Player` and `Membrane.PortAudio.Sink` with a single
`Boombox.Bin{output: {:webrtc, "ws://localhost:8830"}}`. Link the video switcher
to it with `via_in(:input, options: [kind: :video])` and the audio switcher with
`via_in(:input, options: [kind: :audio])` and `get_child/1`.

Key points:

- Drop the `I420` converter and `Membrane.Realtimer`. Boombox takes raw video in
  any pixel format and paces a non-live stream itself.
- Terminate the pipeline in `handle_child_notification/4` when Boombox sends
  `:processing_finished`. Ignore other notifications.

Run `mix run run_pipeline.exs`, open `http://localhost:8000/webrtc_to_browser.html`
and click _Connect_. Unmute the player to hear the audio.
