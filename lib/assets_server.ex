defmodule AssetsServer do
  @moduledoc false
  use Plug.Builder

  plug(Plug.Static, at: "/", from: "assets")
  plug(:not_found)

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
  end

  def start_link(opts) do
    port = Keyword.fetch!(opts, :port)

    IO.puts("""

    Open in your browser:
      1. http://localhost:#{port}/webrtc_from_browser.html - sends your camera and microphone to the pipeline
      2. http://localhost:#{port}/webrtc_to_browser.html   - plays the pipeline's output
    """)

    Bandit.start_link(plug: __MODULE__, port: port)
  end

  def not_found(conn, _opts), do: Plug.Conn.send_resp(conn, 404, "Not found")
end
