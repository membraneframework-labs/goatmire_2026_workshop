# Chapter 4 - Real-time streaming with WebRTC

In this chapter you'll take the pipeline from Chapter 3 out of the desktop window
and into the browser. First you'll send its output to a web page with WebRTC,
then you'll replace the video files with your own camera and microphone. At the
end you'll have a small live streaming service with an ad break in it.

This file contains a detailed and pretty lengthy theoretical introduction and
explanation of the tasks - a more concise version can be found in
[TLDR.md](./TLDR.md).

## Theory overview

### WebRTC

WebRTC (Web Real-Time Communication) is a set of protocols that lets two peers,
usually browsers, send audio and video to each other with very low delay. It's
what powers video calls in the browser. A Membrane pipeline can be one of the
peers too - it can receive a stream from a browser, process it and send a stream
back.

A few things happen before any media flows:

- **Signaling.** The peers have to agree on what they will send, in which
  codecs, and how to reach each other. They do it by exchanging messages: an
  _SDP offer_, an _SDP answer_ and _ICE candidates_ (the network addresses each
  peer can be reached at). WebRTC does not say _how_ these messages should be
  delivered - that's up to the application. In this chapter a plain WebSocket
  connection between the browser and the pipeline is used for that.
- **Connection.** Once the peers know each other's addresses, they set up an
  encrypted connection and start sending media over it in small packets (RTP).

WebRTC also decides which codecs may be used. Audio is sent as **Opus** and
video as **VP8** or **H264**. This means the raw video and audio produced by
your pipeline have to be encoded before they can be sent, and the media coming
from the browser has to be decoded before you can work with it. Sounds like a
lot of work, but you already know an element that does exactly this.

### Live streams

In Chapter 3 you learned that a file can be read much faster than it should be
played, so a `Membrane.Realtimer` was needed to slow it down. A camera is
different - it produces a frame every 1/30 of a second and there is no way to
ask it for frames faster than that. Such a stream is called _live_: its pace is
dictated by the outside world.

This has two consequences for your pipeline:

- Nothing has to slow the stream down. A realtimer is not needed - in fact it
  would only add delay.
- Nothing can slow the stream down either. The source pushes buffers whenever
  they arrive (remember `:push` flow control?). If an element downstream is not
  ready to take them, they have to wait somewhere. Membrane keeps them in a
  queue in front of the first pad working in _pull_ mode, called a _toilet_. The
  toilet has a limited capacity and when it overflows, the pipeline crashes -
  on purpose, since otherwise the memory would grow without limit. You will meet
  the toilet in Task 4.2.

### Bins

So far you've been building the pipeline out of _elements_. Membrane has one
more kind of component: a [`Membrane.Bin`](https://membrane-core.hexdocs.pm/Membrane.Bin.html).
A bin is a group of elements (and possibly other bins) packed into a single
component. From the outside it looks just like an element - it has pads and you
link it in the spec the same way. On the inside it has its own children and its
own spec. Bins are the way to reuse a piece of a pipeline as a whole.

The component you'll use in this chapter, `Boombox.Bin`, is a bin. It hides the
whole WebRTC machinery - the signaling, the connection, the RTP packaging and
the encoding or decoding - behind two pads.

### Boombox

[Boombox](https://github.com/membraneframework/boombox) is a tool built on top of
Membrane for moving media between different formats and protocols: files, HLS,
RTMP, RTSP, WebRTC and more. It can be used from the command line, as a plain
Elixir function, or as a Membrane component:
[`Boombox.Bin`](https://hexdocs.pm/boombox/Boombox.Bin.html). That's the form
you'll use.

`Boombox.Bin` can work as a sink or as a source, depending on which option you
set:

- With the `:output` option set, it is a sink. You link its `:input` pads and it
  sends whatever it receives to the given destination.
- With the `:input` option set, it is a source. It reads from the given
  destination and you link its `:output` pads.

Both pads are _dynamic_: they are created when you link them. There can be one
pad for audio and one for video, and you say which is which with the `:kind`
pad option:

```elixir
child(:my_video_source, MyVideoSource)
|> via_in(:input, options: [kind: :video])
|> child(:boombox, %Boombox.Bin{output: {:webrtc, "ws://localhost:8830"}})
```

A WebRTC destination is described with the `{:webrtc, url}` tuple. With a
`ws://` URL, Boombox starts a WebSocket server on the given port and waits for
a browser to connect and do the signaling. The pipeline will start working when
the browser connects, and Boombox will report the end of its work by sending
the `:processing_finished` notification to its parent.

Notifications are the way children talk to the pipeline. A pipeline receives
them in the [`handle_child_notification/4`](https://membrane-core.hexdocs.pm/Membrane.Pipeline.html#c:handle_child_notification/4)
callback, which gets the notification and the name of the child that sent it.

## The tasks

This chapter consists of two tasks that are built on top of each other:

1. [Task 4.1](#task-41---send-the-stream-to-the-browser) - send the output of the pipeline to the browser.
2. [Task 4.2](#task-42---stream-from-the-browser) - use the camera and microphone from the browser as the input.

Start from the `chapter-3-checkpoint` branch, which contains the solution to Chapter 3.
The final solution can be found on the `chapter-4-checkpoint` branch.

### Building blocks

Add this dependency to `mix.exs` and run `mix deps.get`:

```elixir
  defp deps do
    [
      ...
      # Chapter 4 deps
      {:boombox, github: "membraneframework/boombox", branch: "update-transcoder"}
    ]
```

Boombox brings a lot of Membrane plugins with it, including the WebRTC one and
a small web server ([Bandit](https://hexdocs.pm/bandit) with
[Plug](https://hexdocs.pm/plug)), which you'll use to serve the web pages.

You'll also need two web pages. Both come from the Boombox repository and you
can copy them to the `assets/` directory of the project:

- [`webrtc_to_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_to_browser.html) -
  connects to `ws://localhost:8830` and plays the stream it receives.
- [`webrtc_from_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_from_browser.html) -
  connects to `ws://localhost:8829` and sends the camera and microphone.

They are plain HTML files with a bit of JavaScript doing the signaling described
above. Browsers allow a page to use the camera only when it comes from a secure
origin, and `localhost` counts as one, so the pages will be served over HTTP.

### Task 4.1 - Send the stream to the browser

Your first task is to play the output of the pipeline from Chapter 3 in the
browser instead of the SDL window and the speakers.

To do so:
- remove `Membrane.SDL.Player` and `Membrane.PortAudio.Sink` along with
  everything that was there only for them,
- send the output of both `StreamSwitcher`s to a single `Boombox.Bin` with a
  WebRTC output at `ws://localhost:8830`,
- make the pipeline terminate when Boombox reports that it has finished,
- serve the `assets/` directory over HTTP from `run_pipeline.exs`, so that you
  can open the page in the browser.

Run the pipeline, open `http://localhost:8000/webrtc_to_browser.html` and click
_Connect_. You should see the color-inverted Big Buck Bunny with sound, and the
ad after 15 seconds. The video element on the page starts muted, so unmute it
in the player controls to hear the audio.

#### Hints
<details>
<summary><b>How do I link two branches to one Boombox?</b></summary>

The same way you linked two branches to the `StreamSwitcher` in Chapter 3: the
first branch creates the child and the second one refers to it with `get_child/1`.
Set the `:kind` pad option on each link:

```elixir
|> via_in(:input, options: [kind: :video])
|> child(:webrtc_output, %Boombox.Bin{output: {:webrtc, "ws://localhost:8830"}}),
...
|> via_in(:input, options: [kind: :audio])
|> get_child(:webrtc_output)
```
</details>

<details>
<summary><b>What about the pixel format converter and the Realtimer?</b></summary>

You don't need them anymore. `Boombox.Bin` accepts raw video in any pixel
format and raw audio - it has `Membrane.Transcoder` inside and will encode the
streams into what WebRTC needs. It also knows that a stream coming from a file
is not live, so it paces it itself.
</details>

<details>
<summary><b>How do I know when to terminate the pipeline?</b></summary>

`Boombox.Bin` sends the `:processing_finished` notification to the pipeline
when it has sent everything it received. Handle it in
`handle_child_notification/4` and return the `:terminate` action there. Other
notifications can be ignored:

```elixir
@impl true
def handle_child_notification(:processing_finished, :webrtc_output, _ctx, state) do
  {[terminate: :normal], state}
end

@impl true
def handle_child_notification(_notification, _child, _ctx, state) do
  {[], state}
end
```

The `handle_element_end_of_stream/4` callback is no longer the right place - the
sinks it was watching are gone.
</details>

<details>
<summary><b>How do I serve the page?</b></summary>

Put this at the top of `run_pipeline.exs`, before the pipeline is started:

```elixir
defmodule AssetsServer do
  use Plug.Builder

  plug(Plug.Static, at: "/", from: "assets")
  plug(:not_found)

  def not_found(conn, _opts), do: Plug.Conn.send_resp(conn, 404, "Not found")
end

{:ok, _server} = Bandit.start_link(plug: AssetsServer, port: 8000)
```

`Plug.Static` serves the files from the `assets/` directory under
`http://localhost:8000/`. The server runs inside the same script, so it stops
together with the pipeline.
</details>

<details>
<summary><b>Nothing happens after I run the pipeline</b></summary>

That's expected. Boombox waits for a browser to connect before it starts
sending media. Open the page and click _Connect_.
</details>

### Task 4.2 - Stream from the browser

Now replace the files with a live source. The main video and audio should come
from your camera and microphone, sent from the browser to the pipeline with
WebRTC. The ad branches stay as they are.

To do so:
- replace the IVF and MP3 sources of the main streams with a single
  `Boombox.Bin` with a WebRTC input at `ws://localhost:8829`,
- decode both its streams and pass them through the rest of the pipeline as
  before: video through `ColorInverter` and the switcher, audio through
  the timestamper and the switcher,
- serve the second page too, so you can open it from the browser.

Run the pipeline, open `http://localhost:8000/webrtc_from_browser.html`, click
_Connect_ and allow the browser to use your camera and microphone. Then open
`http://localhost:8000/webrtc_to_browser.html` in another tab and click _Connect_
there too. You should see yourself with inverted colors, hear yourself with a
small delay, and see the ad after 15 seconds. The stream ends when you close
the sender page.

#### Hints
<details>
<summary><b>How do I get audio and video out of one Boombox?</b></summary>

Just like with the input pads, but on the output side. The video branch starts
the child and the audio branch refers to it:

```elixir
child(:webrtc_input, %Boombox.Bin{input: {:webrtc, "ws://localhost:8829"}})
|> via_out(:output, options: [kind: :video])
|> child(:video_decoder, Membrane.Transcoder)
...
get_child(:webrtc_input)
|> via_out(:output, options: [kind: :audio])
|> child(:audio_decoder, Membrane.Transcoder)
```

Boombox outputs the streams as they come from the browser, encoded in Opus and
VP8 or H264. The `Membrane.Transcoder`s you already have will decode them, you
only need to point them at the new source.
</details>

<details>
<summary><b>The switcher complains that the stream formats differ</b></summary>

The camera sends video in a different resolution than the ad, which is
480x270. Both inputs of the switcher must have the same stream format, and
rescaling in the pipeline would cost CPU. It's easier to ask the browser for the
right resolution. In `webrtc_from_browser.html`, change the constraints passed
to `getUserMedia` so that the camera is requested at exactly 480x270:

```javascript
const mediaConstraints = { video: { width: { exact: 480 }, height: { exact: 270 } }, audio: true };
```

Leave a note at the top of the file saying that it was modified and why.
</details>

<details>
<summary><b>The pipeline crashes during the ad with a toilet overflow</b></summary>

Read the error carefully - it says the toilet in front of the `:main` pad of the
switcher has overflowed. While the ad is playing, the switcher does not demand
anything from `:main`. In Chapter 3 that was fine: the file source simply
stopped reading. Now the source is live and keeps pushing, so all the frames
recorded during the ad wait in the toilet. The default capacity is 200 buffers,
and during a 14-second ad a camera produces several hundred frames, and the microphone even more audio chunks.

Raise the capacity on the link into the `:main` pads:

```elixir
|> via_in(:main, toilet_capacity: 5000)
```

Note what this means for the viewer: after the ad, the stream continues from
the moment it was paused, so it is 14 seconds behind the camera. That's the
price of not losing any frames. A different design could drop the frames
instead - think about how you would change `StreamSwitcher` to do that.
</details>

<details>
<summary><b>The pipeline terminates as soon as I close a tab</b></summary>

That's correct. Closing the sender page ends the input stream, Boombox on the
output side sends what is left and reports `:processing_finished`. Closing the
player page closes the output connection, which ends the processing too.
</details>
