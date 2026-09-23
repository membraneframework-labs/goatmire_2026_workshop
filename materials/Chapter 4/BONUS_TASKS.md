# Chapter 4 - BONUS Tasks

If you managed to finish the main task and are up for a challenge, then these
BONUS tasks are for you. The second one works both with and without the first one.

## BONUS Task - Stream from the browser

Replace the files with a live source. The main video and audio should come
from your camera and microphone, sent from the browser to the pipeline with
WebRTC. The ad branches stay as they are.

To do so:
- replace the IVF and MP3 sources of the main streams with a single
  `Boombox.Bin` with a WebRTC input at `ws://localhost:8829`,
- decode both its streams and pass them through the rest of the pipeline as
  before: video through `ColorInverter` and the switcher, audio through
  the timestamper and the switcher.

Run the pipeline, open `http://localhost:8000/webrtc_from_browser.html`, click
_Connect_ and allow the browser to use your camera and microphone. Then open
`http://localhost:8000/webrtc_to_browser.html` in another tab and click _Connect_
there too. You should see yourself with inverted colors, hear yourself with a
small delay, and see the ad after 15 seconds. The stream ends when you close
the sender page.

### Hints
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

## BONUS B O N U S Task - Stream to a co-attendee

So far both the pipeline and the browser were running on your machine. Now let
somebody else join in. Pair up with a co-attendee: they will connect to your
pipeline from their laptop, over the workshop Wi-Fi, and you will connect to
theirs.

Your pipeline listens for the browser on `localhost` only, which nobody else
can reach. To make it available to the network:
- bind the WebRTC signaling servers to all network interfaces by changing the
  host in their URLs from `localhost` to `0.0.0.0`,
- find out the IP address of your machine on the Wi-Fi network,
- give the address to your co-attendee.

Your co-attendee runs their own `run_pipeline.exs`, opens their own copy of
`webrtc_to_browser.html` at `http://localhost:8000` and, before clicking
_Connect_, replaces `localhost` in the _Boombox URL_ field with your IP address,
for example `ws://192.168.1.42:8830`. They should see the stream from your
pipeline. If you did the previous BONUS task, they can also
open `webrtc_from_browser.html` the same way, point it at port `8829` and send
you their camera and microphone instead of yours.

Then swap roles.

### Hints
<details>
<summary><b>How do I find my IP address?</b></summary>

On macOS run `ipconfig getifaddr en0` (or check _System Settings > Wi-Fi > Details_).
On Linux run `ip addr` and look for the address of your wireless interface,
usually starting with `192.168.` or `10.`.
</details>

<details>
<summary><b>Why does each of us serve the pages ourselves?</b></summary>

The pages could be loaded from your machine as well, at `http://YOUR_IP:8000`,
and it would work for the player page. But browsers allow a page to use the
camera only on a secure origin, and a plain HTTP page on a LAN address is not
one. Loading the sender page from the co-attendee's own `localhost` avoids the
problem. What matters is only where the _Boombox URL_ points to.
</details>

<details>
<summary><b>The page says "Connecting..." and nothing happens</b></summary>

Check, in this order:
- the pipeline is running and its signaling URLs use `0.0.0.0`,
- both laptops are on the same Wi-Fi network and the IP address is right,
- your firewall lets Elixir accept incoming connections. macOS may show a
  prompt asking about it the first time, click _Allow_.

Some conference networks isolate the clients from each other. If nothing helps,
one of you can share a hotspot from a phone and both connect to it.
</details>

<details>
<summary><b>Signaling works but there is no video</b></summary>

Signaling is only the first step. The media itself flows over a separate
connection, and the peers find each other by exchanging ICE candidates, that is
the addresses they can be reached at. The pipeline advertises all the addresses
of your machine, including the Wi-Fi one, so on the same network this should
work out of the box. If one of you is connected to a VPN, disconnect it, as VPN
addresses may get picked first and they are unreachable for the other side.
</details>
