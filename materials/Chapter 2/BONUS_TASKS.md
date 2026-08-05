# Chapter 2 - BONUS Tasks

If you managed to finish the main task and are up for a challenge, then these
BONUS tasks are for you.

## BONUS Task

Modify your element so that it inverts only the bottom half of the frames.

To do this you'll need access to the resolution of the stream, which is
available in `handle_buffer/4`. The third argument of this callback is the
[_Context_](https://membrane-core.hexdocs.pm/Membrane.Element.CallbackContext.html) - 
a map containing many various fields about the current state of the element.
Without getting into details, the width of the frame can be accessed at 
`context.pads[:input].stream_format.width` and the height at
`context.pads[:input].stream_format.height`.

## BONUS B O N U S Task

Modify your element so that it inverts only the left half of the frames.
