defmodule AssetsServer do
  @moduledoc false
  use Plug.Builder

  plug(Plug.Static, at: "/", from: "assets")
  plug(:not_found)

  def not_found(conn, _opts), do: Plug.Conn.send_resp(conn, 404, "Not found")
end
