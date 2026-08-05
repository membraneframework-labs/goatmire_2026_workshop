# Chapter 2 - Raw video processing and custom Membrane Elements

In this chapter you'll learn the basics about digital representations of images in RGB
format. You'll also dive into the most elementary building block of a Membrane
pipeline - an element - and get to know how it operates from inside out. As for
the practical section, you'll combine all this knowledge and create your own
video processing element.

This file contains a detailed and pretty lengthy theoretical introduction and
explanation of the task - a more concise version can be found in
[TLDR.md](./TLDR.md). If you finished the main task and are looking for a challenge,
take a look at [BONUS_TASKS.md](./BONUS_TASKS.md)

## The task

Your task is to create an element that inverts the colors of an RGB raw video stream
and plug it in the middle of the pipeline from the previous task.

### RGB

An RGB video stream is just a series of RGB images called _frames_, so you don't have
to worry about the video aspect of it all - just invert the colors of all frames in
the stream.

Beware, you won't have any neat abstractions over the images, you'll get
them as a binary - just as they are represented in memory. To have enough
information to interpret this raw data, you'll also need to know the
resolution and pixel format of the frame.

#### Resolution

The resolution allows for mapping data from this 1-dimensional memory chunk to
pixels on a 2-dimensional image. Pixels are organized in memory by rows, like
this: 

```
Resolution: (3, 3)

Memory layout: 
<<1, 2, 3, 4, 5, 6, 7, 8, 9>>

Image pixel layout:
 ---------
| 1, 2, 3 |
| 4, 5, 6 |
| 7, 8, 9 |
 ---------
```

Let's assume a pixel takes up a single byte in memory, which is true most of the
time, and will be true for your task. A pixel at coordinates `(x, y)` will have
an address of `y * width + x` - first you move over `y` rows which take up `width`
pixels, and then you access the `x`th pixel in the `y`th row.

#### Pixel format

You now know where each pixel resides in memory, but they are still just
numbers, whereas they need to be converted to colors. In monochromatic formats
there's typically not that much to optimize - value of a pixel is it's brightness,
where 0 means black and max value means white.

In color formats, more complex approaches are used - expressing a color as a
single value is not really practical. The most popular practice in video
is to use [chroma subsampling](https://en.wikipedia.org/wiki/Chroma_subsampling), 
but this guide is already getting long, so we'll not get into that here. 

For direct image manipulation, [RGB](https://en.wikipedia.org/wiki/RGB_color_model)
is more handy. You probably already know how RGB colors works, each of the primary 
colors - red, green and blue - gets assigned a value from 0 to 255. These colors are
then added together, resulting in the final color. The pixels in a typical
monitor are made out of three parts, each one emitting a primary color with a
given intensity - that's one of the ways how the RGB addition can occur.

Let's talk about how the RGB frames are represented in memory. Each of the primary
colors receives its own _plane_, which is essentially an image of the same
resolution as the combined one, but only containing information about the
primary color. The pixels in a plane are organized in the same manner as presented in the 
Resolution section - each pixel takes up a single byte and the image is stored by 
rows. The planes themselves are located one after another in memory, like this:

```
Resolution: (2, 2)
Memory layout: 
<<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12>>

Image pixel layout:
Red plane:
 ------
| 1, 2 |
| 3, 4 |
 ------

Green plane:
 ------ 
| 5, 6 |
| 7, 8 |
 ------

Blue plane:
 --------
|  9, 10 |
| 11, 12 |
 --------
```

### Color inversion

Great, you now know exactly how RGB images are stored in memory. Now, how do you
invert colors of an image, what does this even mean? Inverting a color can be also
called getting its [complementary color](https://en.wikipedia.org/wiki/Complementary_colors).
Inverting a while image seem pretty complex at first, but it's really simple to
achieve this - you just need to take each pixel from each plane and convert it 
to it's complementary value, so that the sum of it and the original one will be equal
to 255. When adding the resulting (_negative_) image to the original (_positive_) image
pixel-wise, the result will be a totally white image, which is exactly what
happens with complementary colors in RGB.

### Creating elements

Elements are the most basic components that can be put into a pipeline. There
are four different types of elements: 
- Sources - can only produce streams and have only output pads.
- Sinks - can only consume streams and have only input pads.
- Filters - consume, transform and produce streams and have both input and
  output pads. 
- Endpoints - similar to filters, but while filters generally only transform a
  stream, endpoints serve as a sink and a source in a single element - the stream 
  they produce is a completely different stream than the one they consume. 

For this task you'll need to implement a Filter - it will take in a normal raw
video stream, invert its colors, and output it.

Elements are defined by creating modules implementing behaviours corresponding to
given element types. There are two main parts of an element that can be defined:
- _Pads_, which are responsible for interfacing with other components.
- _Callbacks_, which define the behaviour of the element.

To create a blank filter, which will become your color inverter, you can call

```bash
mix membrane.gen.filter ColorInverter
```

This will create a `color_inverter.ex` file in `lib/` directory with an 
`ColorInverter` module implementing `Membrane.Filter` inside it. This module
will contain the skeleton of the things you need to implement, just like the
Pipeline template you created in the last task.

#### Pads

Let's start by defining the _pads_ of the element, which
can be thought as the parts which link to other components in the pipeline. You
can configure pads in many ways, but one of the essential ones is
by defining their _accepted format_. By doing this you create a contract about
what the element can handle on its input and output - only components with
matching accepted formats can be linked. Your element will consume
and produce a raw video stream with RGB pixel format, which can be expressed
like this:

```elixir
  def_input_pad :input,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    ...

  def_output_pad :output,
    accepted_format: %Membrane.RawVideo{pixel_format: :RGB},
    ...
```

An element with pads defined like this can only be linked with a component that
produces an RGB video stream and a components that consumes an RGB video stream,
which is exactly what we need.

#### Callbacks

The callbacks of the behaviours determine how the elements react to 
things, for example arriving media or termination. A callback always returns
a tuple with 2 elements - a list of actions to execute and a state which will be
available in the next callbacks.

For this task you'll need to implement only one callback -
[`handle_buffer/4`](https://membrane-core.hexdocs.pm/Membrane.Element.WithInputPads.html#c:handle_buffer/4),
which is called every time a new buffer is received by the element. 

What is a buffer? Media streams in Membrane are represented by sequences of 
[_Buffers_](https://membrane-core.hexdocs.pm/Membrane.Buffer.html), which are
structs containing chunks of the stream. In the case this task,
each Buffer will contain a single raw frame binary under the field `:payload` -
that's the only field you'll need to worry about.

Once you inverted the colors of the frame, you can now update the `:payload` of
the buffer with it. To then send this buffer through the `:output` pad to the next
element, you need to return a
[`:buffer`](https://membrane-core.hexdocs.pm/Membrane.Element.Action.html#t:buffer/0)
action from the callback.

Implementation of 
[`handle_buffer/4`](https://membrane-core.hexdocs.pm/Membrane.Element.WithInputPads.html#c:handle_buffer/4)
should look similarly to this, where `invert_frame/1` is a function accepting a
raw frame and returning its negative:

```elixir
  @impl true
  def handle_buffer(:input, %Membrane.Buffer{} = buffer, _ctx, state) do
    inverted_frame = invert_frame(buffer.payload)
    buffer = %Membrane.Buffer{buffer | payload: inverted_frame}

    {[buffer: {:output, buffer}], state}
  end
```

### Plugging the element

Great, now that you have your filter, it's time to plug it into the
pipeline you created in the previous task. Unfortunately it won't be as simple
as adding another [`child/3`](https://membrane-core.hexdocs.pm/Membrane.ChildrenSpec.html#child/3)
call in the spec - currently there are no places in the pipeline where raw video
is accessible. That's because the `Transcoder` handles the decoding and encoding
inside itself, without exposing the decoded stream outside. We can circumvent 
that by splitting the process of decoding and encoding between two `Transcoder`s and
plugging your `ColorInverter` in between them.

The original `Transcoder` child definition should look something like that:

```elixir
...
|> child(:video_transcoder, Membrane.Transcoder)
|> via_out(:output,
  options: [
    output_stream_format: %Membrane.Transcoder.OutputFormat.H264{stream_structure: :avc1}
  ]
)
|> ...
```

To split the decoding and encoding and plug the `ColorInverter` in the middle,
the original `Transcoder` can be replaced with the following structure:

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

This way the stream will be decoded, color-inverted and encoded with H264.

The pipeline can be run the same way as in the previous task, with 
`mix run run_pipeline.exs`.
