# Chapter 2 - Raw video processing and custom Membrane Elements

In this chapter you'll learn the basics about digital representations of images in RGB
format. You'll also dive into the most elementary building block of a Membrane
pipeline - an element - and get to know how it operates from inside out. As for
the practical section, you'll combine all this knowledge and create your own
video processing element.

## Theory overview

TODO

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

In color formats more complex approaches are used - expressing a color as a
single value in this use case has drawbacks and can be done more effectively. 
The most popular practice in video is to use [chroma subsampling](https://en.wikipedia.org/wiki/Chroma_subsampling),
but we'll not get into that here. 

For direct image manipulation, [RGB](https://en.wikipedia.org/wiki/RGB_color_model)
is more handy. You probably know how RGB colors works, each of the primary 
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
invert a color, what does this even mean? Inverting a color can be also
called getting its [complementary color](https://en.wikipedia.org/wiki/Complementary_colors).
This may seem pretty complex at first, but it's really simple to
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

Elements are defined by implementing behaviours corresponding to given element
types. For this task, you'll implement a `Membrane.Filter` behaviour. To
generate a template for a
