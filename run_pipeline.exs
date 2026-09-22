http_port = 8000

IO.puts("""

Open in your browser:
  1. http://localhost:#{http_port}/webrtc_from_browser.html - sends your camera and microphone to the pipeline
  2. http://localhost:#{http_port}/webrtc_to_browser.html   - plays the pipeline's output
""")

{:ok, supervisor, _pipeline} = Membrane.Pipeline.start_link(WorkshopPipeline, [])

Process.monitor(supervisor)

receive do
  {:DOWN, _ref, :process, _supervisor, _reason} ->
    :ok
end
