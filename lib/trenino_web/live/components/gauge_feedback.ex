defmodule TreninoWeb.GaugeFeedback do
  @moduledoc "Human-readable feedback shared by physical gauge controls."
  require Logger

  def result(:preview_only), do: "Preview calculated; hardware has not moved."
  def result(:ok), do: "Request accepted."
  def result({:ok, _}), do: "Command accepted; waiting for firmware status to confirm completion."
  def result({:error, reason}), do: error(reason)
  def result(reason), do: error(reason)

  def error(:disconnected), do: "Connect the configured device first."
  def error(:owned), do: "Another session has manual control. Release it there first."
  def error(:invalid_lease), do: "Manual control expired. Take manual control again."
  def error(:needs_reference), do: "Reference the axis before moving it."

  def error(:manual_pause),
    do: "Automatic control is paused. Resume it in hardware commissioning."

  def error(:outside_limits), do: "The requested position is outside the configured limits."
  def error(:out_of_range), do: "The value is outside the calibration range."
  def error(:busy), do: "Wait for the pending command to finish."

  def error(:outcome_unknown),
    do: "The command outcome is unknown. Recover and reference the axis again."

  def error(:select_axis), do: "Select a hardware axis first."
  def error(:not_found), do: "This configuration is no longer available."

  def error(:needs_fresh_stationary_position),
    do: "Wait for a fresh stationary position before continuing."

  def error(:requires_fresh_reference_and_manual_lease),
    do: "Take manual control and wait for a fresh, stationary referenced position."

  def error(:invalid_calibration_or_limits), do: "Review calibration points and the axis limits."

  def error(:wrong_reference_strategy),
    do: "Use the reference method selected in the axis configuration."

  def error(:not_commissioned),
    do: "Complete physical commissioning before enabling automatic control."

  def error(%Ecto.Changeset{}),
    do:
      "Review the configuration fields, measured calibration and hardware commissioning before enabling."

  def error(reason) do
    Logger.debug(fn -> "Gauge operation unavailable: #{inspect(reason)}" end)
    "This operation is unavailable. Check the device status, reference and configuration."
  end

  def value(value) when is_float(value), do: Float.round(value, 2)
  def value(value) when is_integer(value), do: value
  def value(_), do: "unavailable"
end
