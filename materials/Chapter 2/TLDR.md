# Chapter 2 - Raw video processing and custom Membrane Elements - TLDR

[README.md](./README.md) goes over everything in detail - this file will be more concise 
and won't explain everything step by step. If you feel like you understand
everything needed for this chapter then this version should suffice, however if
you are ever unsure about something, it's probably explained in the README.

## Task 

Your task is to create an element that inverts the colors of an RGB raw video stream
and plug it in the middle of the pipeline from the previous task.

### RGB 

An RGB video stream is just a series of RGB images called _frames_. 
You'll have access to a binaries containing each RGB frame. Each pixel gets
three bytes, one for each of the primary colors. The pixels are laid out first 
by rows, then by columns, like this:

```
Resolution: (2, 2)

Bytes in memory: 
[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]

Pixels on a frame:
 -----------------
| #010203 #040506 | 
| #070809 #101112 | 
 -----------------
```

### Color inversion

Inverting a color can be also
called getting its [complementary color](https://en.wikipedia.org/wiki/Complementary_colors).
In RGB, these two colors always add up to create white.

To invert the colors of an image, you need to take each pixel from each plane 
and convert it to it's complementary value, so that the sum of it and the
original one will be equal to 255.

### Creating elements

Elements are the most basic components that can be put into a Pipeline.
There are four different types of elements: Sources, Sinks, Filters and
Endpoints. For this task you'll implement a Filter - elements of this type
both consume and produce streams and can be placed in the middle of a Pipeline.

To create a blank filter, which will become your color inverter, you can call

```bash
mix membrane.gen.filter ColorInverter
```

#### Pads

Pads are the parts of the element that link to other components in a Pipeline.
When defining pads, you can specify what media formats can flow through them.
When linking the element with another component in the pipeline, their accepted 
formats have to match.

```elixir
  def_input_pad :input,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    ...

  def_output_pad :output,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    ...
```

#### Callbacks

Callbacks define the behaviour of elements. For this task you'll need to
implement a 
[`handle_buffer/4`](https://membrane-core.hexdocs.pm/Membrane.Element.WithInputPads.html#c:handle_buffer/4)
callback, which is called every time a buffer arrives on the filters input pad.
In it you'll have to invert the colors of the frame that just arrived, which can
be found at `buffer.payload`. Once that's done, return a 
[`:buffer`](https://membrane-core.hexdocs.pm/Membrane.Element.Action.html#t:buffer/0)
action to send the buffer with inverted frame on the `:output` pad.

```elixir
  @impl true
  def handle_buffer(:input, %Membrane.Buffer{} = buffer, _ctx, state) do
    inverted_frame = invert_frame(buffer.payload)
    buffer = %Membrane.Buffer{buffer | payload: inverted_frame}

    {[buffer: {:output, buffer}], state}
  end
```

### Plugging the element

The pipeline needs to be modified slightly - you need to have access to a raw
video stream. This can be done by replacing the singular video `Transcoder` with
a decoding and an encoding `Transcoder` and plugging the `ColorInverter`
in between them.

```elixir
...
|> child(:video_decoder, Membrane.Transcoder)
|> via_out(:output,
  options: [
    output_stream_format: %Membrane.Transcoder.OutputFormat.RawVideo{pixel_format: :RGB}
  ]
)
|> child(:color_inverter, ColorInverter)
|> child(:video_encoder, Membrane.Transcoder)
|> via_out(:output,
  options: [
    output_stream_format: %Membrane.Transcoder.OutputFormat.H264{stream_structure: :avc1}
  ]
)
|> ...
```

The pipeline can be run the same way as in the previous task, with 
`mix run run_pipeline.exs`.
