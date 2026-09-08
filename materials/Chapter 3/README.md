# Chapter 3 - Timestamps and flow control in Membrane

In this chapter you'll learn how Membrane keeps track of _time_ - what timestamps
are, how they flow through the pipeline and how components decide _how fast_
the media should flow. You will then put this knowledge to use by turning the
pipeline from Chapter 2 into a real-time player with an ad-insertion feature.

This file contains a detailed and pretty lengthy theoretical introduction and
explanation of the tasks - a more concise version can be found in
[TLDR.md](./TLDR.md).

## Theory overview

### Timestamps

Handling time is the key to handling multimedia! In most cases it's crucial to process and deliver
data at the desired time.
Each [`Membrane.Buffer`](https://membrane-core.hexdocs.pm/Membrane.Buffer.html) can be assigned:
* **PTS** - _presentation timestamp_, stored in the `pts` field - it tells you when to _present_ a given chunk of multimedia,
* **DTS** - _decoding timestamp_, stored in the `dts` field - it tells you when to _decode_ a given chunk of multimedia.

Both are expressed with [`Membrane.Time`](https://membrane-core.hexdocs.pm/Membrane.Time.html).

These two might differ in some scenarios, especially when so called _B-frames_ are used in video codecs.
A B-frame is encoded relative to frames that are presented both before and after it. As a result,
some frames have to be decoded earlier than they are presented, so that the frames which depend on
them can be decoded in time.

Timestamps of media chunks (like video frames or chunks of audio samples) are usually stored in
multimedia containers (like MP4) - e.g. a plain H264 stream does not contain any timestamps.
Sometimes both PTS and DTS are present, sometimes only one of them, and sometimes none of them -
in most cases it depends on the phase of multimedia processing (e.g. right after reading an .mp4 file
with [`Membrane.File.Source`](https://membrane-file-plugin.hexdocs.pm/Membrane.File.Source.html) we
obviously won't have any of them available - they will appear only after demuxing).

Missing timestamps can be restored to some extent, provided that the stream has a constant
sampling rate. Then every chunk carries its own duration - the number of samples divided by the
sampling rate - and the timestamp of a chunk is just the sum of the durations of all the chunks
before it. What can't be restored is the offset of the whole stream, i.e. at which point in time it
starts - if that information is simply not there, the restored timestamps usually start from zero.
For audio the sampling rate is constant by nature, and that's what elements like
[`Membrane.RawAudioParser`](https://membrane-raw-audio-parser-plugin.hexdocs.pm/Membrane.RawAudioParser.html)
rely on - with its `overwrite_pts?` option set to `true`, it computes the `pts` of every buffer it
passes through. For video the same trick works only if the frame rate is constant - with a variable
frame rate there's no way to tell how long a frame should be displayed without a timestamp.
That's why, on the contrary, the corresponding option of
[`Membrane.H264.Parser`](https://membrane-h264-plugin.hexdocs.pm/Membrane.H264.Parser.html) is called
`generate_best_effort_timestamps` - you have to provide the frame rate yourself, and the docs warn
that the generated timestamps may be inaccurate and get out of sync with other media.

Sometimes timestamps need to dictate the speed of processing, and sometimes they don't.
For example, when you need to transcode a video provided as an .mp4 file and save it into another
.mp4 file, you probably would like to do it as fast as possible. This class of scenarios is referred
to as "offline processing".
On the contrary, when the media is meant to be consumed as it flows - displayed to the user or sent to
another peer - each chunk has to be delivered at the time its timestamp says. This is called
"online processing".
Sometimes the pacing comes for free, because the source itself is "online" - a camera producing a
single frame every 1/30 of a second delivers its stream at exactly the speed at which it should be
displayed.
But when the source is a file, it can be read much faster than the media should be played, and
without any pacing the viewer would see all the frames almost at once, which wouldn't make any sense.
In such a case the stream has to be artificially slowed down to "real time" based on its timestamps.
That's what so called "realtimers" do, and Membrane provides one as the
[`Membrane.Realtimer`](https://membrane-realtimer-plugin.hexdocs.pm/Membrane.Realtimer.html)
element from the `membrane_realtimer_plugin` package.

### Flow control


## The tasks

This chapter consists of three tasks that are built on top of each other:

1. [Task 3.1](#task-31---play-the-video-in-real-time) - play the video on screen, in real time.
2. [Task 3.2](#task-32---insert-an-ad) - write a custom element that inserts an ad into the video stream.
3. [Task 3.3](#task-33---bring-the-audio-back) - play audio through the speakers and insert an ad into it too.

Start from the `chapter-2-checkpoint` branch, which contains the solution to Chapter 2.
The final solution can be found on the `chapter-3-checkpoint` branch.

### Building blocks

This time you'll need to add the plugins to `mix.exs` yourself. Here are the
ones you'll need for all three tasks:

```elixir
  defp deps do
    [
      ...
      # Chapter 3 deps
      {:membrane_realtimer_plugin, "~> 0.11.1"},
      {:membrane_sdl_plugin, "~> 0.18.8"},
      {:membrane_portaudio_plugin, "~> 0.19.6"},
      {:membrane_raw_audio_parser_plugin, "~> 0.5.0"}
    ]
```

Remember to run `mix deps.get` after adding them.

- `:membrane_realtimer_plugin` - Plugin that provides a single component:
  * [`Membrane.Realtimer`](https://membrane-realtimer-plugin.hexdocs.pm/Membrane.Realtimer.html) - A filter that holds every buffer until its timestamp
    is reached and only then passes it on. In other words, it makes the stream
    flow in real time, instead of as fast as the upstream can produce it.
- `:membrane_sdl_plugin` - Plugin for displaying video with the SDL library:
  * [`Membrane.SDL.Player`](https://membrane-sdl-plugin.hexdocs.pm/Membrane.SDL.Player.html) - A sink that opens a window and draws the raw video
    frames it receives. It accepts only raw video in the `I420` pixel format.
- `:membrane_portaudio_plugin` - Plugin for playing and capturing audio with the PortAudio library:
  * [`Membrane.PortAudio.Sink`](https://membrane-portaudio-plugin.hexdocs.pm/Membrane.PortAudio.Sink.html) - A sink that plays received raw audio through the
    default audio device.
- `:membrane_raw_audio_parser_plugin` - Plugin for dealing with raw audio streams:
  * [`Membrane.RawAudioParser`](https://membrane-raw-audio-parser-plugin.hexdocs.pm/Membrane.RawAudioParser.html) - A filter that, among other things, can compute
    timestamps of raw audio buffers based on their size and the audio format,
    which is exactly what you need if the stream doesn't have timestamps yet.

### Task 3.1 - Play the video in real time

Your first task is to display the video processed by the pipeline from Chapter 2
on the screen, instead of saving it to an MP4 file.

To do so:
- remove the audio branch (the MP3 source and its transcoder) and the MP4 muxing
  part (the H264 transcoder, the muxer and the file sink) from the pipeline - you
  won't need them in this task, but don't worry, the audio will come back in [Task 3.3](#task-33---bring-the-audio-back),
- send the output of `ColorInverter` to `Membrane.SDL.Player`,
- make sure the video is played at its natural speed.

When you run the pipeline, a window with the (color-inverted) Big Buck Bunny
should appear, playing at 25 frames per second. Once the video finishes, the
pipeline should terminate on its own - you did that in Chapter 2 already, just
make sure it still happens for the right element.

#### Hints
<details>
<summary><b>The player crashes because of the pixel format</b></summary>

`ColorInverter` works on raw video in the `RGB` pixel format, while `Membrane.SDL.Player`
accepts only `I420`. Put another `Membrane.Transcoder` between them with
`output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :I420}` -
it will convert the pixel format for you.
</details>

<details>
<summary><b>The video plays way too fast</b></summary>

The file source reads the file as fast as it can, and the decoder decodes as
fast as it can. Nothing in the pipeline knows how fast the video _should_ be
played - that's what `Membrane.Realtimer` is for. Its job is to
release each buffer only when its timestamp says so. Put it right before the
player, so that everything before it (decoding, color inversion, pixel format
conversion) can still work ahead of time.
</details>

### Task 3.2 - Insert an ad

Now for the main dish of this chapter. You will write a custom element that,
at a given moment, pauses the main video, plays a second video (the "ad")
and then resumes the main video from where it stopped.

The ad is located in `assets/ad_vp8.ivf`. It's a 14-second video in exactly the
same format as `assets/bbb_vp8.ivf` - VP8 in an IVF container, 480x270, 25 frames per second.

The element, let's call it `StreamSwitcher`, should:
- have two input pads - `:main` and `:ad` - and one output pad,
- have an option with the timestamp of the `:main` stream at which the ad should be inserted (see [`Membrane.Time`](https://membrane-core.hexdocs.pm/Membrane.Time.html)),
- forward buffers from `:main` up to and including the first one whose timestamp is at or past the switch time,
- then forward all buffers from `:ad` until it ends,
- then go back to forwarding `:main` from where it was paused, so that no frames are lost,
- end the output stream when both inputs have ended. If `:main` ends before the ad is being played, the switch should happen immediately afterwards, and the stream should end after the ad.

Then add a second branch to the pipeline that reads and decodes the ad, and
plug both branches into the `StreamSwitcher`. The switcher goes right after
`ColorInverter` - this way the ad, unlike the main video, won't have its colors inverted.

#### Hints
<details>
<summary><b>How to create an element?</b></summary>

Take a look at `ColorInverter` from Chapter 2 - it's a filter too. The element
you're about to write will have more pads and more state, but the shape is the same:
`use Membrane.Filter`, define pads with `def_input_pad`/`def_output_pad`,
define options with `def_options` and implement callbacks. You can also generate
a skeleton with:

```bash
mix membrane.gen.filter StreamSwitcher
```

Since the two inputs will carry the same kind of stream, `accepted_format: _any`
on all pads will do.
</details>

<details>
<summary><b>How do I decide which input to read from?</b></summary>

This is where _flow control_ comes in. If you leave the pads in the default
`:auto` flow control mode, Membrane will happily deliver buffers from both
inputs to your element as they come and you'd have to buffer the whole inactive
stream in memory yourself.

Instead, declare all the pads with `flow_control: :manual`. In this mode nothing
arrives on an input pad until your element asks for it with the
[`:demand` action](https://membrane-core.hexdocs.pm/Membrane.Element.Action.html#t:demand/0),
and you get to decide from which pad to demand. Keep track of which input is
currently _active_ and, whenever the downstream element asks you for data in the
[`handle_demand/5`](https://membrane-core.hexdocs.pm/Membrane.Element.WithOutputPads.html#c:handle_demand/5)
callback, demand from the active pad only.

Demand exactly one buffer at a time, regardless of how much was demanded from
you. This way at most one buffer is on its way, and since you demand the next
one only after you've handled the previous one, you always know which pad it
will come from - no buffer can arrive from `:main` after you've decided to
switch to `:ad`.

Membrane won't call `handle_demand/5` again by itself after you've sent a buffer.
Return the [`:redemand` action](https://membrane-core.hexdocs.pm/Membrane.Element.Action.html#t:redemand/0)
along with every buffer you send and whenever the active pad changes, so that
`handle_demand/5` is called again and you can demand the next buffer.

See the [flow control guide](https://membrane-core.hexdocs.pm/06_flow_control.html)
for the details of the `:manual` mode.
</details>

<details>
<summary><b>When exactly should I switch?</b></summary>

Compare the `pts` (presentation timestamp) of each buffer coming from `:main`
with the switch time from the options. Forward the buffer as usual and, if its
`pts` is at or past the switch time, mark `:ad` as the active pad - the next
demand will go there. No buffer needs to be held back, so there's nothing to
store apart from which pad is active.
</details>

<details>
<summary><b>The ad plays fine, but the video "jumps" or freezes after the switch</b></summary>

Remember `Membrane.Realtimer` from the previous task? It releases buffers based
on their timestamps, and the timestamps of the ad start from zero again, while
the main video, once resumed, continues from the switch time. From the
Realtimer's point of view the stream jumps back and forth in time.

The output of your switcher should have a continuous timeline. Keep the
timestamp of the last buffer you sent and, at each switch, compute an offset
which you'll add to the timestamps of every buffer of the new segment, so that
its first frame lands right after the last frame you sent. Don't forget about
`dts`, if the buffers have one.
</details>

<details>
<summary><b>What about stream formats?</b></summary>

Every input pad will receive a stream format (see
[`handle_stream_format/4`](https://membrane-core.hexdocs.pm/Membrane.Element.WithInputPads.html#c:handle_stream_format/4)).
Since both inputs carry the same kind of stream, it's enough to forward the
first stream format you receive and only assert that the other one is the
same. Raising an error with a descriptive message is a perfectly fine way to
handle a mismatch - it's a misconfiguration of the pipeline, not something the
element can recover from.
</details>

<details>
<summary><b>Where is the end of stream coming from?</b></summary>

[`handle_end_of_stream/3`](https://membrane-core.hexdocs.pm/Membrane.Element.WithInputPads.html#c:handle_end_of_stream/3)
is called separately for each input pad. Keep in the state which inputs have
already ended - the decision what to do next (switch to the other input or end
the output stream) depends on both of them.
</details>

### Task 3.3 - Bring the audio back

The final task is to bring back the audio you removed in [Task 3.1](#task-31---play-the-video-in-real-time),
play it through the speakers and insert an ad into it as well - the audio for
the ad is located in `assets/ad.mp3`.

The audio branch should:
- read `assets/bbb.mp3` and decode it into raw audio,
- pass it through a `StreamSwitcher` with the same switch time as the video one,
- play it with `Membrane.PortAudio.Sink`.

The ad branch reads `assets/ad.mp3`, decodes it and plugs into the `:ad` pad of the
audio switcher.

Make the pipeline terminate only after _both_ the video and the audio have finished playing.

If you did everything right, you should hear the main audio stop at the same
time the ad appears on the screen and come back once the ad ends.

#### Hints
<details>
<summary><b>The switcher crashes on the audio stream with an <code>ArithmeticError</code></b></summary>

Look closely at the error - it's probably trying to add a number to `nil`. The
MP3 file doesn't carry any timestamps, so the buffers coming out of the decoder
don't have a `pts`. Without them, your switcher can't tell when to switch.

That's the job of `Membrane.RawAudioParser` - with `overwrite_pts?: true`
it will compute the timestamps based on how much audio has already flowed
through it. Put it between the decoder and the switcher, in both the main and
the ad branch.
</details>

<details>
<summary><b>The switcher complains that the stream formats differ</b></summary>

`assets/bbb.mp3` and `assets/ad.mp3` may be decoded into raw audio with different
parameters. Make the decoders output the exact same format by specifying it in
`Membrane.Transcoder`'s `output_stream_format`:

```elixir
%Membrane.Transcoder.OutputFormat.RawAudio{
  sample_format: :s16le,
  sample_rate: 44_100,
  channels: 2
}
```

The Transcoder will resample the audio if needed.
</details>

<details>
<summary><b>The audio doesn't need a Realtimer?</b></summary>

No. `Membrane.PortAudio.Sink` asks for data only as fast as the audio device
consumes it, so the audio flows in real time on its own. This works because
the sink's input pad uses `:manual` flow control - the sink demands exactly as
much data as it needs.

This also explains why video and audio may drift apart slightly: video is paced
by `Membrane.Realtimer`, which uses the system clock, while audio is paced by the
clock of the sound card.
</details>

<details>
<summary><b>The switcher fails on <code>handle_demand/5</code> when linked to the audio sink</b></summary>

`Membrane.PortAudio.Sink` demands data in bytes, not in buffers. If your
output pad doesn't specify a `demand_unit`, it inherits the one of the pad it's linked
to. Declare `demand_unit: :buffers` on the output pad of the switcher, and
Membrane will translate between the two units for you.
</details>
