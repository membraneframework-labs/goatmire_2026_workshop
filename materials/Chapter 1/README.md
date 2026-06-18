# Chapter 1 - Codecs, containers and pipelines

In this chapter you'll learn the essentials about codecs and containers
and how to build Membrane pipelines. You will then implement a simple pipeline
by yourself.

## Theory overview

TODO

## The task
Your task is to create a pipeline that will read audio from an MP3 file,
VP8 video from an IVF file, transcode them into AAC and H264 respectively, and
mux them into a single MP4 container file.

Woah, that's a mouthful of abbreviations and acronyms with numbers in them! 
Let's go over the process step by step.

### The process

You have access to two media files - one with audio, the other with video: 
- `assets/input_video.ivf` - **IVF** (Indeo Video Format) is a simple container 
  format for storing video. It supports multiple multiple codecs, and the video 
  stored in this one is encoded with **VP8** - an open and royalty-free video coding format. 
- `assets/input_audio.mp3` - **MP3** is an audio coding format. It doesn't need to be
payloaded to a separate container, the encoded stream can just be put into a file directly.

The first step is to read the media from those files to get the streams flowing through the 
pipeline. Then decode them into raw audio and video using decoders appropriate
for these formats.

These raw streams can then be encoded into our target formats using encoders: 
- **H.264** - also known as AVC (Advanced Video Coding) - A video coding format, 
  by far the most commonly used format in the industry. 
- **AAC** (Advanced Audio Coding) - An audio coding format, widely supported in the
  industry, designed to be the successor of MP3.

The process of converting from one coding format to another is called
_transcoding_. Here we achieve it by decoding a stream and then immediately
encoding it with a different codec.

Now you should have access to two streams, encoded with our desired formats. Now
let's merge them, so that they are synchronized and can be interpreted as two 
interleaved tracks of a single multimedia stream. This process is called
_muxing_ (shortened from multiplexing), and here you will mux your audio and video
streams into an **MP4** container. MP4 is a container format most commonly used for 
storing video and audio, but can also be used to store other data, such as subtitles. 

The muxed stream is now ready to be put into a file. The container format
ensures that anything reading from the file will be able to separate (_demux_)
included tracks into distinct, synchronized streams. For example, the thing
reading from the file can be a media player, which needs to play both tracks
alongside each other.

### Membrane implementation

Okay, we hope that now you know _what_ you need to do. Now let's explore _how_ to
do it.


