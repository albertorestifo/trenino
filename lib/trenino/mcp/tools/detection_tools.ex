defmodule Trenino.MCP.Tools.DetectionTools do
  @moduledoc """
  MCP tools for detecting hardware inputs and simulator endpoints interactively.

  These are long-polling tools that block until detection completes or times out.
  Each tool broadcasts to the "mcp:detection" PubSub topic so the UI can show
  a modal prompting the user to interact with the relevant hardware or simulator.
  """

  alias Trenino.Hardware.InputDetectionSession
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Simulator.ControlDetectionSession

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
            "Prefer this over asking the user for input IDs manually.",
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
      },
      %{
        name: "detect_simulator_endpoint",
        description:
          "Prompt the user to interact with a control in Train Sim World. " <>
            "Detects which simulator API endpoint changes. " <>
            "Shows a modal in the Trenino UI. " <>
            "Returns the endpoint path for use in bindings and configurations. " <>
            "Requires the simulator to be connected.",
        input_schema: %{
          type: "object",
          properties: %{
            prompt: %{
              type: "string",
              description: "Message shown to the user"
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

  def execute("detect_simulator_endpoint", %{"prompt" => prompt} = args) do
    case Connection.get_status() do
      %ConnectionState{status: :connected, client: client} when not is_nil(client) ->
        run_simulator_detection(client, prompt, args)

      %ConnectionState{} ->
        {:ok,
         %{
           detected: false,
           reason: "Simulator not connected. Please connect to Train Sim World first."
         }}
    end
  end

  # Private functions

  defp run_simulator_detection(client, prompt, args) do
    timeout_ms = Map.get(args, "timeout_ms", @default_timeout_ms)
    detection_id = generate_id()

    broadcast_detection_request(detection_id, :simulator, prompt)

    {:ok, _pid} = ControlDetectionSession.start(client, self())

    result =
      receive do
        {:control_detected, changes} ->
          broadcast_detection_complete(detection_id)
          {:ok, build_control_result(changes)}

        {:detection_timeout} ->
          broadcast_detection_complete(detection_id)
          {:ok, %{detected: false, reason: "timeout"}}

        {:detection_error, reason} ->
          broadcast_detection_complete(detection_id)
          {:ok, %{detected: false, reason: "Detection error: #{inspect(reason)}"}}
      after
        timeout_ms ->
          broadcast_detection_complete(detection_id)
          {:ok, %{detected: false, reason: "timeout"}}
      end

    result
  end

  defp build_control_result([first | _rest] = changes) do
    all_changes =
      Enum.map(changes, fn change ->
        %{
          endpoint: change.endpoint,
          control_name: change.control_name,
          previous_value: Float.round(change.previous_value * 1.0, 2),
          current_value: Float.round(change.current_value * 1.0, 2)
        }
      end)

    %{
      detected: true,
      endpoint: first.endpoint,
      control_name: first.control_name,
      previous_value: Float.round(first.previous_value * 1.0, 2),
      current_value: Float.round(first.current_value * 1.0, 2),
      all_changes: all_changes
    }
  end

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
