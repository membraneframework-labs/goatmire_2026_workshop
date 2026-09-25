# Multimedia with Membrane 101

This repository contains all the necessary materials for participation in 
"Multimedia with Membrane 101" workshops at Goatmire 2026 Elixir conference.

## Workshop structure

The workshop will be split into four chapters, each one consisting of two parts:
- Theoretical introduction to multimedia and Membrane concepts relevant for this
  chapter.
- Coding session, where you will develop the project by completing some tasks we
  came up with.

The presentations and tasks are located in the `materials/` directory:
- [Chapter 1 - Codecs, containers and pipelines](materials/Chapter%201/README.md)
- [Chapter 2 - Raw video processing and custom Membrane Elements](materials/Chapter%202/README.md)
- [Chapter 3 - Timestamps and flow control in Membrane](materials/Chapter%203/README.md)
- [Chapter 4 - Real-time streaming with WebRTC](materials/Chapter%204/README.md)

Each chapter's materials come in two flavours:
- `README.md` - a concise description of the task and the building blocks
  needed to complete it. Pick this one if you feel comfortable with the theory
  from the presentation.
- `DEEP_DIVE.md` - a thorough version, with the theory explained in detail and
  the task walked through step by step. If anything in the `README.md` is
  unclear, it's most likely explained here.

Some chapters also come with a `BONUS_TASKS.md` - extra tasks for those who
finish the main one early and are up for a challenge.

## Prerequisites

Before the workshop, make sure you have installed:
- Elixir 1.17 or newer with Erlang/OTP 27 or 28,
- FFmpeg (including the `ffplay` command, used to preview the results),
- SDL2, PortAudio, libvpx, x264 and fdk-aac.

On macOS with Homebrew:

```bash
brew install elixir ffmpeg sdl2 portaudio libvpx x264 fdk-aac
```

On Debian or Ubuntu:

```bash
sudo apt install ffmpeg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
  libswresample-dev libsdl2-dev portaudio19-dev libvpx-dev libx264-dev libfdk-aac-dev
```

## Project development

During the workshop you'll be developing a project based on Membrane from the
ground up. Each chapter builds on top of the previous one.

To get started, clone this repository and stay on the `main` branch - it
contains the initial state of the project, with all the dependencies and
assets needed for the first chapter:

```bash
git clone https://github.com/membraneframework-labs/membrane_workshop_at_goatmire_2026.git
cd membrane_workshop_at_goatmire_2026
mix deps.get
```

### Checkpoint branches

This repo also contains four branches, which can be thought of as checkpoints - each
one contains our solution to a chapter, so the project is in a state ready for
the next one:

| Branch | Contains |
|--------|----------|
| `chapter-1-checkpoint` | Solution to Chapter 1, starting point for Chapter 2 |
| `chapter-2-checkpoint` | Solution to Chapter 2, starting point for Chapter 3 |
| `chapter-3-checkpoint` | Solution to Chapter 3, starting point for Chapter 4 |
| `chapter-4-checkpoint` | Solution to Chapter 4, the finished project |

Using them is optional. We recommend building the project on your own and
consulting the checkpoints when you feel the need to, but if something goes
wrong there is always the option to fall back on a branch ;)

```bash
git checkout chapter-2-checkpoint
```

