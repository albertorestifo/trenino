defmodule Trenino.MCP.Tools.DetectionTools do
  @moduledoc """
  MCP tools for detecting hardware inputs interactively.

  These are long-polling tools that block until detection completes or times out.
  Each tool broadcasts to the "mcp:detection" PubSub topic so the UI can show
  a modal prompting the user to interact with the relevant hardware.
  """

  alias Trenino.Hardware.InputDetectionSession

  @detection_topic "mcp:detection"
  @default_timeout_ms 60_000

  def tools do
    [
      %{
        name: "detect_hardware_input",
        description:
          "Prompt the user to interact with a hardware input (press a button, move a lever). " <>
            "Shows a modal in the Trenino UI and waits for the input event. " <>
            "Returns the detected input details including its database ID for use in bindings. " <>
            "Prefer this over asking the user for input IDs manually. " <>
            "IMPORTANT: Only call this tool one at a time. Do NOT call multiple detections in parallel. " <>
            "Wait for each detection to complete before starting the next one.",
        input_schema: %{
          type: "object",
          properties: %{
            prompt: %{
              type: "string",
              description: "Message shown to the user"
            },
            input_type: %{
              type: "string",
              enum: ["button", "analog", "any"],
              description: "Type of input to detect"
            }
          },
          required: ["prompt"]
        }
      }
    ]
  end

  def execute("detect_hardware_input", %{"prompt" => prompt} = args) do
    input_type = parse_input_type(Map.get(args, "input_type"))
    timeout_ms = Map.get(args, "timeout_ms", @default_timeout_ms)
    detection_id = generate_id()

    broadcast_detection_request(detection_id, :hardware, prompt)

    {:ok, _pid} =
      InputDetectionSession.start(self(), input_type: input_type, timeout_ms: timeout_ms)

    result =
      receive do
        {:input_detected, input} ->
          broadcast_detection_complete(detection_id)
          {:ok, %{detected: true, input: input}}

        {:detection_timeout} ->
          broadcast_detection_complete(detection_id)
          {:ok, %{detected: false, reason: "timeout"}}
      end

    result
  end

  # Private functions

  defp parse_input_type("button"), do: :button
  defp parse_input_type("analog"), do: :analog
  defp parse_input_type(_), do: :any

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp broadcast_detection_request(id, type, prompt) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @detection_topic,
      {:detection_request, %{id: id, type: type, prompt: prompt}}
    )
  end

  defp broadcast_detection_complete(id) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @detection_topic,
      {:detection_complete, id}
    )
  end
end
