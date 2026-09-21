defmodule Goatmire2026Workshop.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {AssetsServer, port: 8000}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Goatmire2026Workshop.Supervisor)
  end
end
