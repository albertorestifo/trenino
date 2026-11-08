defmodule Trenino.MCP.Tools.DialCalibrationTools do
  @moduledoc """
  The measured dial of a gauge. The dial belongs to the hardware, so one calibration
  serves every train binding on the gauge. Saving never moves the needle.
  """
  alias Trenino.Hardware
  alias Trenino.Hardware.DialCalibration
  alias Trenino.MCP.Tools.GaugeSerialization, as: Serialization

  def tools do
    [
      %{
        name: "get_dial_calibration",
        description:
          "Dial calibration of a gauge (shared by every train gauge binding on it): output_unit (raw/mps/kmh/mph, what the printed dial shows), points (dial value -> position in steps from the end stop), valid and reviewed. Returns calibration: null when none is recorded. Read-only.",
        input_schema: %{
          type: "object",
          required: ["gauge_id"],
          properties: %{gauge_id: %{type: "integer"}}
        }
      },
      %{
        name: "update_dial_calibration",
        description:
          "Create or replace the dial calibration of a gauge. 2-32 strictly increasing dial values with strictly monotonic positions between 0 and the gauge travel (steps from the end stop). Set reviewed: true only after the user checked the points against the real dial; any change without it clears the review and disables every gauge binding on the gauge. Never moves the needle. Measure points with move_gauge (move, then ask the user what the dial reads; release it afterwards) and use preview_gauge_binding to check a binding's mapping.",
        input_schema: %{
          type: "object",
          required: ["gauge_id"],
          properties: %{
            gauge_id: %{type: "integer"},
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

  def execute("get_dial_calibration", %{"gauge_id" => id}) when is_integer(id) do
    with {:ok, gauge} <- Hardware.get_gauge(id) do
      {:ok, %{calibration: Serialization.dial(gauge.dial_calibration)}}
    end
    |> Serialization.result()
  end

  def execute("update_dial_calibration", %{"gauge_id" => id} = args)
      when is_integer(id) do
    with {:ok, gauge} <- Hardware.get_gauge(id),
         {:ok, %DialCalibration{} = calibration} <-
           Hardware.save_dial_calibration(gauge, Map.delete(args, "gauge_id")) do
      {:ok, %{calibration: Serialization.dial(calibration)}}
    end
    |> Serialization.result()
  end

  def execute(_, _), do: {:error, "Missing or invalid parameters"}
end
