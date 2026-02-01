defmodule Trenino.MCP.Server do
  @moduledoc """
  JSON-RPC 2.0 protocol handler for the MCP server.

  Parses incoming messages, dispatches to the correct handler,
  and formats responses according to the MCP specification.
  """

  alias Trenino.MCP.ToolRegistry

  @server_name "Trenino"
  @server_version Mix.Project.config()[:version]
  @protocol_version "2024-11-05"

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

  defp dispatch("initialize", _params) do
    {:ok,
     %{
       protocolVersion: @protocol_version,
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
        {:ok,
         %{
           content: [%{type: "text", text: encode_result(result)}]
         }}

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

  defp encode_result(nil), do: "ok"
  defp encode_result(result) when is_binary(result), do: result
  defp encode_result(result), do: Jason.encode!(result)

  defp jsonrpc_response(id, result) do
    %{jsonrpc: "2.0", id: id, result: result}
  end

  defp jsonrpc_error(id, code, message) do
    %{jsonrpc: "2.0", id: id, error: %{code: code, message: message}}
  end
end
