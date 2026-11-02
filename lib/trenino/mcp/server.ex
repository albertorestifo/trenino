defmodule Trenino.MCP.Server do
  @moduledoc """
  JSON-RPC 2.0 protocol handler for the MCP server.

  Parses incoming messages, dispatches to the correct handler,
  and formats responses according to the MCP specification.
  """

  alias Trenino.MCP.ToolRegistry

  @server_name "Trenino"
  @server_version Mix.Project.config()[:version]
  # Newest first. The tools-only surface is identical across these revisions, so the
  # server echoes whichever one the client asks for.
  @supported_protocol_versions ["2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05"]

  @spec supported_protocol_versions() :: [String.t()]
  def supported_protocol_versions, do: @supported_protocol_versions

  @spec handle_message(map()) :: {:reply, map()} | {:error, map()}
  def handle_message(%{"jsonrpc" => "2.0", "method" => method} = message) do
    id = Map.get(message, "id")
    params = Map.get(message, "params", %{})

    case dispatch(method, params) do
      {:ok, result} ->
        {:reply, jsonrpc_response(id, result)}

      {:error, code, message_text} ->
        {:error, jsonrpc_error(id, code, message_text)}
    end
  end

  def handle_message(_invalid) do
    {:error, jsonrpc_error(nil, -32_600, "Invalid request")}
  end

  defp dispatch("initialize", params) do
    {:ok,
     %{
       protocolVersion: negotiate_protocol_version(params["protocolVersion"]),
       capabilities: %{
         tools: %{}
       },
       serverInfo: %{
         name: @server_name,
         version: @server_version
       }
     }}
  end

  defp dispatch("notifications/initialized", _params) do
    {:ok, nil}
  end

  defp dispatch("tools/list", _params) do
    tools =
      ToolRegistry.list_tools()
      |> Enum.map(fn tool ->
        %{
          name: tool.name,
          description: tool.description,
          inputSchema: tool.input_schema
        }
      end)

    {:ok, %{tools: tools}}
  end

  defp dispatch("tools/call", %{"name" => name, "arguments" => arguments}) do
    case ToolRegistry.call_tool(name, arguments) do
      {:ok, result} ->
        case encode_result(result) do
          {:ok, text} ->
            {:ok, %{content: [%{type: "text", text: text}]}}

          :error ->
            {:ok,
             %{content: [%{type: "text", text: "Result could not be encoded"}], isError: true}}
        end

      {:error, message_text} ->
        {:ok,
         %{
           content: [%{type: "text", text: message_text}],
           isError: true
         }}
    end
  end

  defp dispatch("tools/call", _params) do
    {:error, -32_602, "Invalid params: name and arguments required"}
  end

  defp dispatch("ping", _params) do
    {:ok, %{}}
  end

  defp dispatch(method, _params) do
    {:error, -32_601, "Method not found: #{method}"}
  end

  defp negotiate_protocol_version(requested) when requested in @supported_protocol_versions,
    do: requested

  defp negotiate_protocol_version(_requested), do: hd(@supported_protocol_versions)

  defp encode_result(nil), do: {:ok, "ok"}
  defp encode_result(result) when is_binary(result), do: {:ok, result}

  defp encode_result(result) do
    case Jason.encode(result) do
      {:ok, text} -> {:ok, text}
      {:error, _} -> :error
    end
  rescue
    Protocol.UndefinedError -> :error
  end

  defp jsonrpc_response(id, result) do
    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp jsonrpc_error(id, code, message) do
    %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
  end
end
