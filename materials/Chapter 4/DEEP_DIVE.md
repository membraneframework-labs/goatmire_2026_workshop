# Chapter 4 - Real-time streaming with WebRTC

In this chapter you'll take the pipeline from Chapter 3 out of the desktop window
and into the browser by sending its output to a web page with WebRTC. In the
BONUS tasks you'll replace the video files with your own camera and microphone
and let a co-attendee watch your stream, ending up with a small live streaming
service with an ad break in it.

This file contains a detailed and pretty lengthy theoretical introduction and
explanation of the task - a more concise version can be found in
[README.md](./README.md). If you finished the main task and are looking for a challenge,
take a look at [BONUS_TASKS.md](./BONUS_TASKS.md)

## Theory overview

### WebRTC

WebRTC (Web Real-Time Communication) is a set of protocols that lets two peers,
usually browsers, send audio and video to each other with very low delay. It's
what powers video calls in the browser. A Membrane pipeline can be one of the
peers too - it can receive a stream from a browser, process it and send a stream
back to that browser or forward it to another peer.

A few things happen before any media flows:

- **Signaling.** The peers have to agree on what they will send, in which
  codecs, and how to reach each other. They do it by exchanging messages: an
  _SDP offer_, an _SDP answer_ and _ICE candidates_ (the network addresses each
  peer can be reached at). WebRTC standard does not specify _how_ these messages should be
  delivered - that's up to the application. In this chapter a plain WebSocket
  connection between the browser and the pipeline is used for that.
- **Connection.** Once the peers know each other's addresses, they set up an
  encrypted connection and start sending media over it in small packets (RTP).

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
  the toilet in the BONUS tasks.

### Bins

So far you've been building the pipeline out of _elements_. Membrane has one
more kind of component: a [`Membrane.Bin`](https://membrane-core.hexdocs.pm/Membrane.Bin.html).
A bin is a group of elements (and possibly other bins) packed into a single
component. From the outside it looks just like an element - it has pads and you
link it in the spec the same way. On the inside it has its own children and its
own spec. Bins are the way to reuse a piece of a pipeline as a whole.

The component you'll use in this chapter is a bin:
[`Boombox.Bin`](https://hexdocs.pm/boombox/Boombox.Bin.html) from
[Boombox](https://github.com/membraneframework/boombox), a tool built on top of
Membrane for moving media between different formats and protocols: files, HLS,
RTMP, RTSP, WebRTC and more. You tell it where the media should come from or go
to, and it builds the right chain of elements for that protocol inside itself.
The same two pads work whether the other end is a file, an RTMP server or a
WebRTC peer.

## The task

Continue with your project from Chapter 3. If your solution doesn't work, you can
fall back on the `chapter-3-checkpoint` branch, which contains ours. The final
solution of this chapter can be found on the `chapter-4-checkpoint` branch.

### Building blocks

The dependencies you'll need in this chapter are already listed in `mix.exs`:

```elixir
  defp deps do
    [
      ...
      # Chapter 4 deps
      {:boombox, "~> 0.3.0"},
      {:bandit, "~> 1.12"}
    ]
```

- `:boombox` - Brings a lot of Membrane plugins with it, including the WebRTC one, and provides:
  * [`Boombox.Bin`](https://hexdocs.pm/boombox/Boombox.Bin.html) - A bin that works
    as a sink or as a source, depending on which option you set. With the `:output`
    option set, it is a sink: you link its `:input` pads and it sends whatever it
    receives to the given destination. With the `:input` option set, it is a source:
    it reads from the given destination and you link its `:output` pads. Both pads
    are _dynamic_, they are created when you link them. There can be one pad for
    audio and one for video, and you say which is which with the `:kind` pad option:

    ```elixir
    child(:my_video_source, MyVideoSource)
    |> via_in(:input, options: [kind: :video])
    |> child(:boombox, %Boombox.Bin{output: {:webrtc, "ws://localhost:8830"}})
    ```

    A WebRTC endpoint is described with the `{:webrtc, url}` tuple. With a `ws://`
    URL, Boombox starts a WebSocket server on the given port and waits for a browser
    to connect and do the signaling. The pipeline will start working when the browser
    connects, and Boombox will report the end of its work by sending the
    `:processing_finished` notification to its parent.
- `:bandit` - [Bandit](https://hexdocs.pm/bandit) is an HTTP server, which serves
  the web pages together with [Plug](https://hexdocs.pm/plug), which comes with it.

### Serving the web pages

You'll need two web pages. Both come from the Boombox repository and are already
in the `assets/` directory of the project:

- [`webrtc_to_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_to_browser.html) -
  connects to `ws://localhost:8830` and plays the stream it receives.
- [`webrtc_from_browser.html`](https://github.com/membraneframework/boombox/blob/master/examples/data/webrtc_from_browser.html) -
  connects to `ws://localhost:8829` and sends the camera and microphone.

They are plain HTML files with a bit of JavaScript doing the signaling described
above. Browsers allow a page to use the camera only when it comes from a secure
origin, and `localhost` counts as one, so the pages will be served over HTTP.

The project already contains the `AssetsServer` module (see `lib/assets_server.ex`),
a Plug that serves the files from the `assets/` directory with Bandit. Nothing
starts it yet, so add it to the children of the application's supervisor in
`lib/goatmire_2026_workshop/application.ex`:

```elixir
children = [
  {AssetsServer, port: 8000}
]
```

`Plug.Static` serves the files under `http://localhost:8000/`. The server is
started together with the application, so it's up whenever you run
`mix run run_pipeline.exs`, and it prints the addresses of both pages on startup.

### Task - Send the stream to the browser

Your task is to play the output of the pipeline from Chapter 3 in the
browser instead of the SDL window and the speakers.

To do so:
- remove `Membrane.SDL.Player` and `Membrane.PortAudio.Sink` along with
  everything that was there only for them,
- send the output of both `StreamSwitcher`s to a single `Boombox.Bin` with a
  WebRTC output at `ws://localhost:8830`,
- make the pipeline terminate when Boombox reports that it has finished.

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
when it has sent everything it received. Notifications are the way children talk
to the pipeline: it receives them in the
[`handle_child_notification/4`](https://membrane-core.hexdocs.pm/Membrane.Pipeline.html#c:handle_child_notification/4)
callback, together with the name of the child that sent them. Handle this one
there and return the `:terminate` action. Other notifications can be ignored:

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
<summary><b>Nothing happens after I run the pipeline</b></summary>

That's expected. Boombox waits for a browser to connect before it starts
sending media. Open the page and click _Connect_.
</details>
