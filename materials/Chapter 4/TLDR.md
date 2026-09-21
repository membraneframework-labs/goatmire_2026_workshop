# Chapter 4 - Real-time streaming with WebRTC - TLDR

[README.md](./README.md) goes over everything in detail - this file will be more concise
and won't explain everything step by step. If you feel like you understand
everything needed for this chapter then this version should suffice, however if
you are ever unsure about something, it's probably explained in the README.

## Tasks

There are three tasks, Task 4.2 is optional (marked with a star) and Task 4.3
works with or without it. Continue with your project from Chapter 3, or fall
back on the `chapter-3-checkpoint` branch if it doesn't work. The final solution
is on `chapter-4-checkpoint`.

Add these deps to `mix.exs` and run `mix deps.get`:

```elixir
      # Chapter 4 deps
      {:boombox, github: "membraneframework/boombox", branch: "update-transcoder"},
      {:bandit, "~> 1.12"}
```

Copy the two example pages from the Boombox repository into `assets/`:
[`webrtc_to_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_to_browser.html)
and
[`webrtc_from_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_from_browser.html).
Serve them over HTTP with Bandit from `run_pipeline.exs`, before the pipeline is started:

```elixir
defmodule AssetsServer do
  use Plug.Builder

  plug(Plug.Static, at: "/", from: "assets")
  plug(:not_found)

  def not_found(conn, _opts), do: Plug.Conn.send_resp(conn, 404, "Not found")
end

{:ok, _server} = Bandit.start_link(plug: AssetsServer, port: 8000)
```

The component you'll use is [`Boombox.Bin`](https://hexdocs.pm/boombox/Boombox.Bin.html).
It's a sink when you set its `:output` option and a source when you set `:input`.
It has one dynamic pad per direction, up to one for audio and one for video,
chosen with the `kind: :audio | :video` pad option. A WebRTC endpoint is
`{:webrtc, "ws://localhost:PORT"}` - Boombox starts a WebSocket signaling server
on that port and waits for a browser to connect. It handles encoding and
decoding on its own.

### Task 4.1 - Send the stream to the browser

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

### Task 4.2* - Stream from the browser

Replace the IVF and MP3 sources of the main streams with a single
`Boombox.Bin{input: {:webrtc, "ws://localhost:8829"}}`. Take video from it with
`via_out(:output, options: [kind: :video])` and audio with
`via_out(:output, options: [kind: :audio])` and `get_child/1`. The existing
`Membrane.Transcoder`s decode the incoming Opus and VP8/H264.

Key points:

- The camera must send the same resolution as the ad, 480x270. In
  `webrtc_from_browser.html` set
  `mediaConstraints = { video: { width: { exact: 480 }, height: { exact: 270 } }, audio: true }`.
- The input is live, so while the ad plays the main streams pile up in the
  [toilets](https://membrane-core.hexdocs.pm/Membrane.ChildrenSpec.html#via_in/3)
  in front of the switchers' `:main` pads. The default capacity of 200
  buffers is not enough for a 14-second ad. Set
  `via_in(:main, toilet_capacity: 5000)` on both links.
- The pipeline ends when the sender page disconnects.

Run the pipeline, open `http://localhost:8000/webrtc_from_browser.html`, click
_Connect_ and allow camera access, then open
`http://localhost:8000/webrtc_to_browser.html` and click _Connect_.

### Task 4.3 - Stream to a co-attendee

Let a co-attendee connect to your pipeline over the Wi-Fi network, then swap roles.

- Change the host in the signaling URLs from `localhost` to `0.0.0.0`, so the
  servers accept connections from the network.
- Find your IP address (`ipconfig getifaddr en0` on macOS, `ip addr` on Linux)
  and give it to your co-attendee.
- They run their own `run_pipeline.exs`, open `http://localhost:8000/webrtc_to_browser.html`
  and put `ws://YOUR_IP:8830` in the _Boombox URL_ field before clicking _Connect_.
  With Task 4.2 done, they can also open `webrtc_from_browser.html` with
  `ws://YOUR_IP:8829` and send you their camera.

The pages are served from each laptop's own `localhost` because the camera works
only on a secure origin. If the connection fails, check the firewall, make sure
you are on the same network and turn off VPNs.
