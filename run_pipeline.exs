{:ok, supervisor, _pipeline} = Membrane.Pipeline.start_link(WorkshopPipeline, [])

Process.monitor(supervisor)

receive do
  {:DOWN, _ref, :process, _supervisor, _reason} ->
    :ok
end
