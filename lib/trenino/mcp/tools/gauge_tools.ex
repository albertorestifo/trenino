defmodule Trenino.MCP.Tools.GaugeTools do
  @moduledoc """
  X27 gauge tools: configure gauges on a device (firmware >= 3.3.0), apply the
  configuration, and move or re-zero a needle by hand to calibrate its dial.
  """
  alias Trenino.Hardware
  alias Trenino.MCP.Tools.GaugeSerialization, as: Serialization
  alias Trenino.Train.GaugeController

  # A manual move keeps the train away from the gauge for this long; every move renews it.
  @manual_ttl_ms 60_000

  @about "X27 gauge stepper driven by the device itself (firmware 3.3.0 or newer, up to 4 per device). " <>
           "driver: vid6606 (a VID6606 channel: pins [STEP, DIR, RESET_N or 255, 255], 3780 steps for 315 degrees, max_speed up to 5000) " <>
           "or direct (four AVR pins wired to X27 contacts 1-4: pins [c1, c2, c3, c4], 945 steps for 315 degrees, max_speed up to 1800; not on Due or ESP32). " <>
           "travel 1-4000 steps from the end stop, acceleration 1-60000 steps/s^2; on create, omitted travel/max_speed/acceleration take the driver defaults, and switching driver on update moves values still at the old driver's defaults to the new one's. " <>
           "Gauges on one VID6606 share its RESET_N; no other pin may be shared. Train-lever gauge board channels: A [8,7,6,255], B [14,16,6,255], C [21,20,6,255], D [5,4,6,255]. " <>
           "Saving never reaches the device: call apply_device_configuration, which sends the whole device configuration; every gauge then sweeps to its end stop and zeros itself. " <>
           "Changing driver, pins or reverse deletes the gauge's dial calibration, and so does shortening travel below a dial point. A controller stores at most 8 inputs, matrices, displays and gauges together."

  def tools do
    [
      tool("list_gauges", "List the gauges of a device. " <> @about, ["device_id"], %{
        device_id: %{type: "integer"}
      }),
      tool(
        "create_gauge",
        "Create a gauge. " <> @about,
        ["device_id", "name", "pins"],
        %{
          device_id: %{type: "integer"}
        }
        |> Map.merge(config_properties())
      ),
      tool(
        "update_gauge",
        "Update a gauge. " <> @about,
        ["id"],
        %{id: %{type: "integer"}}
        |> Map.merge(config_properties())
      ),
      tool("delete_gauge", "Delete a gauge with its dial and train bindings.", ["id"], %{
        id: %{type: "integer"}
      }),
      tool(
        "apply_device_configuration",
        "Send a device's saved configuration (inputs, matrices, displays, outputs and gauges) to the connected device. Asynchronous; gauges re-zero once the device stores it. Gauges need firmware 3.3.0 or newer.",
        ["device_id"],
        %{device_id: %{type: "integer"}}
      ),
      tool(
        "move_gauge",
        "Move a gauge's needle to `position` steps from its end stop (clamped to travel), to measure dial points: move, ask the user what the dial reads, then update_dial_calibration. Takes manual control so the active train stops driving this gauge for 60 s (renewed by every move). Pass release: true (without position) to hand the gauge back to the train. Fire-and-forget: the device never confirms, so ask the user what the needle shows.",
        ["id"],
        %{
          id: %{type: "integer"},
          position: %{type: "integer", minimum: 0, maximum: 4000},
          release: %{type: "boolean"}
        }
      ),
      tool(
        "zero_gauge",
        "Re-zero a gauge: it sweeps into its end stop, calls that 0, then returns to its last position. Use when the needle was knocked or lost steps.",
        ["id"],
        %{id: %{type: "integer"}}
      )
    ]
  end

  defp tool(name, description, required, properties),
    do: %{
      name: name,
      description: description,
      input_schema: %{type: "object", properties: properties, required: required}
    }

  defp config_properties do
    %{
      name: %{type: "string"},
      driver: %{type: "string", enum: ["vid6606", "direct"]},
      pins: %{
        type: "array",
        items: %{type: "integer", minimum: 0, maximum: 255},
        minItems: 4,
        maxItems: 4
      },
      travel: %{type: "integer", minimum: 1, maximum: 4000},
      max_speed: %{type: "integer", minimum: 1, maximum: 5000},
      acceleration: %{type: "integer", minimum: 1, maximum: 60_000},
      reverse: %{type: "boolean"}
    }
  end

  @config_keys ~w(name driver pins travel max_speed acceleration reverse)

  def execute("list_gauges", %{"device_id" => id}) when is_integer(id),
    do: {:ok, %{gauges: Enum.map(Hardware.list_gauges(id), &Serialization.gauge/1)}}

  def execute("create_gauge", %{"device_id" => id} = args) when is_integer(id) do
    case Hardware.create_gauge(id, Map.take(args, @config_keys)) do
      {:ok, gauge} -> {:ok, %{gauge: Serialization.gauge(gauge), next_steps: next_steps()}}
      error -> Serialization.result(error)
    end
  end

  def execute("update_gauge", %{"id" => id} = args) when is_integer(id) do
    with {:ok, gauge} <- Hardware.get_gauge(id),
         {:ok, gauge} <- Hardware.update_gauge(gauge, Map.take(args, @config_keys)) do
      {:ok, %{gauge: Serialization.gauge(gauge), next_steps: next_steps()}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("delete_gauge", %{"id" => id}) when is_integer(id) do
    with {:ok, gauge} <- Hardware.get_gauge(id),
         {:ok, _} <- Hardware.delete_gauge(gauge) do
      GaugeController.release_manual(id)
      {:ok, %{deleted: true}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("apply_device_configuration", %{"device_id" => id}) when is_integer(id) do
    case Hardware.apply_saved_configuration(id) do
      {:ok, config_id} -> {:ok, %{applying: true, config_id: config_id}}
      error -> Serialization.result(error)
    end
  end

  def execute("move_gauge", %{"id" => id, "release" => true}) when is_integer(id) do
    case Hardware.get_gauge(id) do
      {:ok, _gauge} ->
        GaugeController.release_manual(id)
        {:ok, %{released: true}}

      error ->
        Serialization.result(error)
    end
  end

  def execute("move_gauge", %{"id" => id, "position" => position})
      when is_integer(id) and is_integer(position) do
    with {:ok, gauge} <- Hardware.get_gauge(id),
         {:ok, port} <- Hardware.gauge_link(gauge.device),
         :ok <- GaugeController.hold_manual(id, ttl_ms: @manual_ttl_ms),
         :ok <- Hardware.set_gauge_position(port, gauge, position) do
      {:ok, %{sent: true, position: position |> max(0) |> min(gauge.travel)}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("zero_gauge", %{"id" => id}) when is_integer(id) do
    with {:ok, gauge} <- Hardware.get_gauge(id),
         {:ok, port} <- Hardware.gauge_link(gauge.device),
         :ok <- Hardware.zero_gauge(port, gauge) do
      {:ok, %{sent: true}}
    else
      error -> Serialization.result(error)
    end
  end

  def execute("move_gauge", %{"id" => id}) when is_integer(id),
    do:
      {:error,
       "Pass position (an integer number of steps) to move, or release: true to hand the gauge back."}

  def execute(_, _), do: {:error, "Missing or invalid parameters"}

  defp next_steps,
    do:
      "Saved only; the device is unchanged. Call apply_device_configuration to send it, then calibrate the dial with move_gauge and update_dial_calibration."
end
