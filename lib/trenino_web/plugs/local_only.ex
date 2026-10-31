defmodule TreninoWeb.Plugs.LocalOnly do
  @moduledoc """
  Guards endpoints that must only be reachable by local clients (DNS-rebinding and
  cross-site request protection for the MCP server).

  - The `Host` must be `localhost`, `127.0.0.1` or `[::1]`.
  - A present `Origin` must also be a local host (any scheme, so the Tauri webview's
    `http://localhost:...` and `tauri://localhost` both pass). A missing `Origin` is
    allowed: native MCP clients do not send one.
  """
  import Plug.Conn

  @behaviour Plug

  @local_hosts ["localhost", "127.0.0.1", "::1", "tauri.localhost"]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    if local_host?(conn.host) and origin_allowed?(get_req_header(conn, "origin")) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(403, ~s({"error":"Forbidden: MCP is only available to local clients"}))
      |> halt()
    end
  end

  defp origin_allowed?([]), do: true
  defp origin_allowed?([origin]), do: origin |> URI.parse() |> Map.get(:host) |> local_host?()
  defp origin_allowed?(_multiple), do: false

  defp local_host?(host) when is_binary(host) do
    normalized =
      host |> String.trim_leading("[") |> String.trim_trailing("]") |> String.downcase()

    normalized in @local_hosts
  end

  defp local_host?(_), do: false
end
