defmodule TreninoWeb.MCP.DiscoveryController do
  @moduledoc """
  Documents that let an AI assistant discover and configure Trenino's MCP server.

  - GET /llms.txt — Plain-text setup guide with a copy-paste command per client
  - GET /mcp/server-card — MCP Server Card (SEP-2127) describing both transports
  - GET /.well-known/ai-catalog.json — AI Catalog entry pointing at the server card

  Every URL is built from the endpoint URL, so the documents match the host and port
  Trenino is serving on.
  """

  use TreninoWeb, :controller

  alias Trenino.MCP.Server

  @card_name "io.github.albertorestifo/trenino"
  @repository_url "https://github.com/albertorestifo/trenino"
  @docs_url "#{@repository_url}/blob/master/docs/mcp-setup.md"

  def llms_txt(conn, _params) do
    conn
    |> put_resp_content_type("text/markdown")
    |> send_resp(200, llms_text(url(conn, ~p"/mcp"), url(conn, ~p"/mcp/sse")))
  end

  def server_card(conn, _params) do
    %{name: title, version: version} = Server.server_info()
    protocol_versions = Server.supported_protocol_versions()

    card = %{
      "$schema" => "https://static.modelcontextprotocol.io/schemas/v1/server-card.schema.json",
      name: @card_name,
      title: title,
      version: version,
      description:
        "Configure Trenino train controllers for Train Sim World: hardware inputs, " <>
          "LEDs, displays, sequences, Lua scripts and live simulator access.",
      websiteUrl: @docs_url,
      repository: %{url: @repository_url, source: "github"},
      remotes: [
        %{
          type: "streamable-http",
          url: url(conn, ~p"/mcp"),
          supportedProtocolVersions: protocol_versions
        },
        %{type: "sse", url: url(conn, ~p"/mcp/sse"), supportedProtocolVersions: protocol_versions}
      ]
    }

    conn
    |> put_resp_content_type("application/mcp-server-card+json")
    |> send_resp(200, Jason.encode!(card))
  end

  def ai_catalog(conn, _params) do
    catalog = %{
      specVersion: "1.0",
      entries: [
        %{
          identifier: "urn:air:albertorestifo.github.io:mcp:trenino",
          type: "application/mcp-server-card+json",
          url: url(conn, ~p"/mcp/server-card")
        }
      ]
    }

    conn
    |> put_resp_content_type("application/ai-catalog+json")
    |> send_resp(200, Jason.encode!(catalog))
  end

  defp llms_text(mcp_url, sse_url) do
    """
    # Trenino MCP server

    > Trenino bridges custom hardware train controllers to Train Sim World. Its built-in
    > MCP server lets an AI assistant configure trains: detect hardware inputs, bind
    > buttons, LEDs and displays, write sequences and Lua scripts, and read or write
    > live simulator values.

    The server is running right now inside the Trenino desktop app. It only accepts
    connections from this computer (localhost), needs no authentication, and is only
    reachable while Trenino is open.

    - Streamable HTTP endpoint (preferred): #{mcp_url}
    - Legacy SSE endpoint: #{sse_url}
    - Server name to use: trenino
    - Server card: #{mcp_url}/server-card

    ## Install

    Pick the command for the client you are running in. Each one is a single step;
    restart or reload the client afterwards if it does not pick up the server on its own.

    ### Claude Code

    ```bash
    claude mcp add --transport http --scope user trenino #{mcp_url}
    ```

    ### Claude Desktop

    Claude Desktop only launches local (stdio) servers from its config file, so bridge
    with `mcp-remote` (requires Node.js). Add this to `claude_desktop_config.json`
    (macOS: `~/Library/Application Support/Claude/`, Windows: `%APPDATA%\\Claude\\`),
    merging into any existing `mcpServers`, then fully quit and reopen Claude Desktop:

    ```json
    {
      "mcpServers": {
        "trenino": {
          "command": "npx",
          "args": ["-y", "mcp-remote", "#{mcp_url}"]
        }
      }
    }
    ```

    Settings > Connectors does not work: custom connectors are reached from Anthropic's
    servers, which cannot see this computer's localhost.

    ### Codex (CLI, IDE extension and app)

    ```bash
    codex mcp add trenino --url #{mcp_url}
    ```

    ### ChatGPT (web and desktop)

    Not supported. ChatGPT connectors run in OpenAI's cloud and need a public HTTPS URL,
    and Trenino deliberately refuses non-local connections. Use Codex instead.

    ### Gemini CLI

    ```bash
    gemini mcp add --transport http trenino #{mcp_url}
    ```

    ### VS Code (GitHub Copilot)

    ```bash
    code --add-mcp '{"name":"trenino","type":"http","url":"#{mcp_url}"}'
    ```

    ### Cursor

    Add to `~/.cursor/mcp.json`:

    ```json
    {
      "mcpServers": {
        "trenino": { "url": "#{mcp_url}" }
      }
    }
    ```

    ### Any other MCP client

    Configure a remote server named `trenino` with Streamable HTTP transport at
    #{mcp_url}. Clients that only speak the older HTTP+SSE transport can use #{sse_url}.

    ## Verify

    After installing, list the tools: there should be dozens, such as `list_trains` and
    `list_simulator_endpoints`. Simulator tools additionally need Train Sim World running
    with its External Interface API enabled.

    ## More

    - Full setup guide and example workflows: #{@docs_url}
    - Source: #{@repository_url}
    """
  end
end
