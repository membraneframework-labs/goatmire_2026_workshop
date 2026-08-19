# Chapter 1 - BONUS Tasks

If you managed to finish the main task and are up for a challenge, then these
BONUS tasks are for you.

## BONUS Task

It's really simple - reverse the pipeline you implemented. Transform an MP4 file
with H264 and AAC tracks into an IVF file with VP9 and an MP3 file. You'll need
a few more components that weren't mentioned:
* `Membrane.MP4.Demuxer.ISOM` - Extracts different tracks from
  an MP4 container - essentially the reverse of `Membrane.MP4.Muxer.ISOM`. 
* `Membrane.IVF.Serializer` - Puts a video track into an IVF container - 
  essentially the reverse of `Membrane.IVF.Deserializer`. 

### Hints
<details>
<summary><b>How to actually get the streams from the Demuxer?</b></summary>

You need to be able to tell which track to send on which
output pad - the Demuxer doesn't know where it should send the demuxed tracks. The MP4
we're demuxing contains two tracks - audio and video. This case is very common,
so Demuxer makes the process easier for this case - you just need to specify
which pad will output audio, and which video, with the `:kind` pad option:

```elixir
spec = [
  ... # pipeline start
  |> child(:demuxer, Membrane.MP4.Demuxer.ISOM)
  |> via_out(:output, options: [kind: :audio])
  |> ... # audio branch of the pipeline,
  get_child(:demuxer)
  |> via_out(:output, options: [kind: :video])
  |> ... # video branch of the pipeline,
]
```
</details>

## BONUS B O N U S Task

Woah, you're good. Hopefully this one will stop you, because we don't have any
more (for this chapter at least). 

Your BONUS B O N U S task is to extend the pipeline from BONUS task and add support
for MP4's with any number of H264 and AAC tracks - each one should end up in
a separate IVF or MP3 file. 

### Hints
<details>
<summary><b>How am I supposed to know what tracks are in the MP4?</b></summary>

To check manually, you can use `ffprobe` command on the file - the output is a
bit cluttered, search for records looking something like this:
`Stream #0:0[0x1](und): Audio: aac` - this one indicates an AAC audio
track.

To check it programatically, a 
[`:new_tracks`](https://membrane-mp4-plugin.hexdocs.pm/Membrane.MP4.Demuxer.ISOM.html#t:new_tracks_t/0)
notification emitted by the Demuxer
will be your ally - see the 
[Demuxer's documentation](https://membrane-mp4-plugin.hexdocs.pm/Membrane.MP4.Demuxer.ISOM.html) 
for details. In it you'll find the necessary information to link output pads 
corresponding to the tracks from the MP4. These pads are _dynamic_, you can read
more about this concept [here](https://membrane-core.hexdocs.pm/pads.html#dynamic-pads).
</details>
