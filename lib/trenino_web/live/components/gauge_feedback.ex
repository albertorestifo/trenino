defmodule TreninoWeb.GaugeFeedback do
  @moduledoc "Human-readable feedback shared by the gauge screens."
  alias Trenino.Hardware
  require Logger

  @unit_options [
    {"Raw (no conversion)", :raw},
    {"m/s", :mps},
    {"km/h", :kmh},
    {"mph", :mph}
  ]

  @doc "Unit choices shared by the gauge forms: `{label, unit}`."
  @spec unit_options() :: [{String.t(), atom()}]
  def unit_options, do: @unit_options

  def result(:ok), do: "Sent."
  def result({:ok, _}), do: "Sent."
  def result({:error, reason}), do: error(reason)
  def result(reason), do: error(reason)

  def error(:device_not_connected), do: "Connect the configured device first."

  def error(:firmware_update_required),
    do:
      "Gauges need controller firmware #{Hardware.gauge_firmware_version()} or newer. Update the firmware, then apply the configuration."

  def error(:needs_apply),
    do: "The device does not have the saved configuration yet. Apply the configuration first."

  def error(:manual_control),
    do: "Paused while the gauge is being calibrated. Close its calibration to resume."

  def error(:out_of_range), do: "The value is outside the calibration range."
  def error(:select_gauge), do: "Select a gauge first."
  def error(:not_found), do: "This configuration is no longer available."

  def error(:invalid_calibration_or_limits),
    do: "Calibrate the gauge's dial in the hardware configuration first."

  def error(%Ecto.Changeset{}),
    do: "Review the fields and calibrate the gauge's dial before enabling."

  def error(reason) do
    Logger.debug(fn -> "Gauge operation unavailable: #{inspect(reason)}" end)
    "This is unavailable right now. Check the device connection and configuration."
  end

  def value(value) when is_float(value), do: Float.round(value, 2)
  def value(value) when is_integer(value), do: value
  def value(_), do: "unavailable"
end
