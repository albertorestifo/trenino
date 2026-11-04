defmodule TreninoWeb.GaugeFeedback do
  @moduledoc "Human-readable feedback shared by physical gauge controls."
  alias Trenino.Hardware.StepperLease
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

  def result(:preview_only), do: "Preview calculated; hardware has not moved."
  def result(:ok), do: "Request accepted."
  def result({:ok, _}), do: "Command accepted; waiting for firmware status to confirm completion."
  def result({:error, reason}), do: error(reason)
  def result(reason), do: error(reason)

  def error(:disconnected), do: "Connect the configured device first."
  def error({:lease_held, info}), do: StepperLease.message(info)

  def error(:lease_expired_finishing_motion),
    do: "The lease expired while a move is finishing. Wait for it to stop, then claim again."

  def error(:owned), do: "Another session has manual control. Release it there first."
  def error(:invalid_lease), do: "Manual control expired. Take manual control again."
  def error(:needs_reference), do: "Reference the axis before moving it."

  def error(:manual_pause),
    do: "Train output is paused for this gauge. Resume it on its stepper axis."

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

  def error(:not_commissioned), do: "Set up this gauge first."

  def error(:alignment_required),
    do: "Line the needle up on 0 by hand and confirm before re-zeroing."

  def error(:needs_apply),
    do: "The saved axis settings are not on the device yet. Apply the configuration."

  def error(%Ecto.Changeset{}),
    do: "Review the configuration fields and finish the gauge setup before enabling."

  def error(reason) do
    Logger.debug(fn -> "Gauge operation unavailable: #{inspect(reason)}" end)
    "This operation is unavailable. Check the device status, reference and configuration."
  end

  @doc "Plain-language text for a session or status fault."
  def fault(:driver_i2c),
    do: "Motor driver (I2C) fault. Check shield power and wiring."

  def fault(:home_timeout), do: "Zeroing timed out before the needle reached its stop."
  def fault(:host_lost), do: "The host stopped sending keep-alive; the axis stopped."
  def fault(:send_failed), do: "Could not talk to the device. Check the USB connection."

  def fault(:unexpected_reset),
    do: "The device restarted unexpectedly."

  def fault(:unsupported_capabilities), do: "The firmware does not support this axis setup."

  def fault({:configure_failed, _}),
    do: "The device rejected the axis settings. Review and Apply again."

  def fault(_), do: "The axis reported a fault."

  def value(value) when is_float(value), do: Float.round(value, 2)
  def value(value) when is_integer(value), do: value
  def value(_), do: "unavailable"
end
