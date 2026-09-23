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
- [Chapter 4 - WebRTC and it's usage with Membrane](materials/Chapter%204/README.md)

## Project development

During the workshop you'll be developing a project based on Membrane from the
ground up. Each chapter will be building on top of the next.

To get started, clone this repository and stay on the `main` branch - it
contains the initial state of the project, with all the dependencies and
assets needed for the first chapter:

```bash
git clone https://github.com/membraneframework-labs/membrane_workshop_at_goatmire_2026.git
cd membrane_workshop_at_goatmire_2026
mix deps.get
```

This repo also contains four branches, which can be thought of as checkpoints - each
one contains the project in a state ready for the next chapter. We recommend
building the project on your own and consulting the checkpoints when you feel
the need to, but if something goes wrong there is always the option to fall back
on a branch ;)

