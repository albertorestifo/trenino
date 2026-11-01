defmodule Trenino.MCP.Tools.DialCalibrationTools do
  @moduledoc """
  The measured dial of a stepper axis. The dial belongs to the hardware, so one
  calibration serves every train binding on the axis. Saving never moves the motor.
  """
  alias Trenino.Hardware
  alias Trenino.Hardware.DialCalibration
  alias Trenino.MCP.Tools.GaugeSerialization, as: Serialization

  def tools do
    [
      %{
        name: "get_dial_calibration",
        description:
          "Dial calibration of a stepper axis (shared by every train gauge binding on it): output_unit (raw/mps/kmh/mph, what the printed dial shows), points (dial value -> position in transitions), valid and reviewed. Returns calibration: null when none is recorded. Read-only.",
        input_schema: %{
          type: "object",
          required: ["stepper_axis_id"],
          properties: %{stepper_axis_id: %{type: "integer"}}
        }
      },
      %{
        name: "update_dial_calibration",
        description:
          "Create or replace the dial calibration of a stepper axis. 2-32 strictly increasing dial values with strictly monotonic positions inside the axis soft limits. Set reviewed: true only after the user checked the points against the real dial; any change without it clears the review and disables every gauge binding on the axis. Never moves the motor. Measure points with control_stepper_axis (claim, jog, read the estimated position) and use preview_gauge_binding to check a binding's mapping.",
        input_schema: %{
          type: "object",
          required: ["stepper_axis_id"],
          properties: %{
            stepper_axis_id: %{type: "integer"},
            output_unit: %{type: "string", enum: ["raw", "mps", "kmh", "mph"]},
            reviewed: %{type: "boolean"},
            points: %{
              type: "array",
              items: %{
                type: "object",
                properties: %{value: %{type: "number"}, position: %{type: "integer"}},
                required: ["value", "position"]
              }
            }
          }
        }
      }
    ]
  end

  def execute("get_dial_calibration", %{"stepper_axis_id" => id}) when is_integer(id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id) do
      {:ok, %{calibration: Serialization.dial(axis.dial_calibration)}}
    end
    |> Serialization.result()
  end

  def execute("update_dial_calibration", %{"stepper_axis_id" => id} = args)
      when is_integer(id) do
    with {:ok, axis} <- Hardware.get_stepper_axis(id),
         {:ok, %DialCalibration{} = calibration} <-
           Hardware.save_dial_calibration(axis, Map.delete(args, "stepper_axis_id")) do
      {:ok, %{calibration: Serialization.dial(calibration)}}
    end
    |> Serialization.result()
  end

  def execute(_, _), do: {:error, "Missing or invalid parameters"}
end
