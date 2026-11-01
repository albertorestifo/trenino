defmodule TreninoWeb.GaugeGuidance do
  @moduledoc """
  Plain-language guidance derived from existing stepper runtime data.

  Everything here is read-only: it explains the next step for an axis and why an
  enabled gauge binding is not moving, without changing any state.
  """
  alias Trenino.Hardware.{DialCalibration, StepperAxis}
  alias Trenino.Train.GaugeBinding
  alias Trenino.Train.Train
  alias TreninoWeb.GaugeFeedback

  @type snapshot :: %{required(:lifecycle) => atom(), optional(atom()) => term()}

  @glossary [
    {"Reference",
     "the pointer position the software trusts. It is lost on Release, a moving Stop, a fault or a reconnect."},
    {"Manual control",
     "you hold the axis and automatic train output is paused until you Resume train control."},
    {"Commissioning",
     "your recorded check on the real dial that direction, travel and reference are right."}
  ]

  @doc "One-line glossary entries as `{term, meaning}`."
  @spec glossary() :: [{String.t(), String.t()}]
  def glossary, do: @glossary

  @doc "The next thing the operator should do for an axis."
  @spec next_step(StepperAxis.t(), snapshot(), boolean(), boolean()) :: String.t()
  def next_step(%StepperAxis{} = axis, snapshot, has_token?, apply_needed?) do
    runtime = snapshot.axes[axis.id]
    step(snapshot.lifecycle, axis, runtime, has_token?, apply_needed?)
  end

  @typedoc """
  The one-word state of an axis card. `primary` is the single promoted action:
  `:wizard`, `:recover`, `:resume` or `nil`.
  """
  @type axis_status :: %{
          state: :ready | :needs_setup | :offline | :fault | :paused | :moving | :busy,
          label: String.t(),
          kind: :ok | :warn | :error | :info | :muted,
          reason: String.t() | nil,
          primary: :wizard | :recover | :resume | nil
        }

  @doc """
  The resting-view summary of an axis: one state, one reason (only when something needs
  attention) and the one action that moves the operator forward. Read-only.
  """
  @spec axis_status(StepperAxis.t(), snapshot(), boolean(), boolean()) :: axis_status()
  def axis_status(%StepperAxis{} = axis, snapshot, has_token?, apply_needed?) do
    reason = next_step(axis, snapshot, has_token?, apply_needed?)
    classify(snapshot.lifecycle, snapshot, axis, snapshot.axes[axis.id], reason, apply_needed?)
  end

  defp classify(:disconnected, _, _, _, reason, _),
    do: status(:offline, "Device not connected", :muted, reason, nil)

  defp classify(:fault, snapshot, _, _, reason, _) do
    detail = if Map.get(snapshot, :error), do: GaugeFeedback.fault(snapshot.error), else: reason
    status(:fault, "Fault", :error, detail, :recover)
  end

  defp classify(:unsupported, _, _, _, reason, _),
    do: status(:needs_setup, "Needs setup", :warn, reason, nil)

  defp classify(lifecycle, _, _, _, reason, _)
       when lifecycle in [:probing, :deploying, :resetting, :configuring],
       do: status(:busy, "Starting", :info, reason, nil)

  defp classify(_, _, _, _, reason, true),
    do: status(:needs_setup, "Needs setup", :warn, reason, :wizard)

  defp classify(_, _, _, nil, reason, _), do: status(:busy, "Starting", :info, reason, nil)

  defp classify(_, _, axis, runtime, reason, _) do
    cond do
      not runtime.ready or not axis.commissioned ->
        status(:needs_setup, "Needs setup", :warn, reason, :wizard)

      runtime.paused ->
        status(:paused, "Paused", :warn, reason, :resume)

      moving?(runtime) ->
        status(:moving, "Moving", :info, nil, nil)

      true ->
        status(:ready, "Ready", :ok, nil, nil)
    end
  end

  defp status(state, label, kind, reason, primary),
    do: %{state: state, label: label, kind: kind, reason: reason, primary: primary}

  @doc "Whether the axis needle is in motion right now (reported or just commanded)."
  @spec moving?(map() | nil) :: boolean()
  def moving?(%{status: %{state: state}}) when state in [:moving, :homing], do: true
  def moving?(_), do: false

  defp step(:disconnected, _, _, _, true),
    do: "Apply needed: connect the device, then click Apply to Device."

  defp step(:disconnected, _, _, _, _),
    do: "Connect the device to commission this axis."

  defp step(_, _, _, _, true),
    do: "Apply needed: click Apply to Device so the device receives the saved axis settings."

  defp step(:unsupported, _, _, _, _),
    do: "Update the controller firmware to 3.1.0 or newer, then Apply again."

  defp step(:fault, _, _, _, _),
    do: "Recover: press Recover configuration, then set the reference again."

  defp step(lifecycle, _, _, _, _)
       when lifecycle in [:probing, :deploying, :resetting, :configuring],
       do: "Wait while the device is configured."

  defp step(_, _, nil, _, _), do: "Wait for the first status from the device."

  defp step(_, _, %{ready: false}, false, _),
    do: "Set reference: take manual control, then align the pointer and set the reference."

  defp step(_, axis, %{ready: false}, true, _),
    do: "Set reference: #{reference_action(axis)}"

  defp step(_, %{commissioned: false}, _, false, _),
    do: "Take manual control, check direction and travel, then complete commissioning."

  defp step(_, %{commissioned: false}, _, true, _),
    do: "Jog to check direction and travel on the real dial, then complete commissioning."

  defp step(_, _, %{paused: true}, _, _),
    do: "Resume train control so enabled gauges can drive this axis."

  defp step(_, _, _, _, _), do: "Ready: enabled gauges drive this axis from train data."

  defp reference_action(%{reference_strategy: :internal_stop}),
    do: "press Home to run the bounded sweep, then verify the pointer."

  defp reference_action(_),
    do: "physically align the pointer, enter its position and press Assign reference."

  @doc """
  Why an enabled binding cannot move right now, or `nil` when nothing blocks it.

  `simulator_connected?` is whether the simulator client is available.
  """
  @spec blocker(GaugeBinding.t(), snapshot(), boolean()) :: String.t() | nil
  def blocker(%GaugeBinding{enabled: false}, _, _), do: nil

  def blocker(%GaugeBinding{} = binding, snapshot, simulator_connected?) do
    axis = binding.stepper_axis

    cond do
      not simulator_connected? ->
        "Not moving: the simulator is not connected."

      not axis.commissioned ->
        "Not moving: the axis is not commissioned. Complete physical commissioning first."

      match?(%DialCalibration{valid: false}, GaugeBinding.calibration(axis)) ->
        "Not moving: the dial is blocked because the axis changed or a homing setup was left unfinished. Run the gauge wizard again."

      true ->
        lifecycle_blocker(snapshot, snapshot.axes[axis.id])
    end
  end

  defp lifecycle_blocker(%{lifecycle: :disconnected}, _),
    do: "Not moving: the device is not connected."

  defp lifecycle_blocker(%{lifecycle: :fault}, _),
    do: "Not moving: the axis is in a fault state. Recover it in hardware commissioning."

  defp lifecycle_blocker(%{lifecycle: :unsupported}, _),
    do: "Not moving: the controller firmware does not support steppers."

  defp lifecycle_blocker(%{lifecycle: lifecycle}, nil) when lifecycle != :ready,
    do: "Not moving: the device is still being configured."

  defp lifecycle_blocker(_, %{ready: false}),
    do:
      "Not moving: the axis needs a reference. Set it in hardware commissioning, or reconnect the device if it homes automatically."

  defp lifecycle_blocker(_, %{paused: true}),
    do:
      "Not moving: automatic control is paused (manual control). Resume train control in hardware commissioning."

  defp lifecycle_blocker(_, _), do: nil

  @doc """
  Hint shown when none of the train's identifiers match the detected train.

  Matching is the same prefix rule used by train detection. Returns `nil` when
  nothing is detected or the train matches.
  """
  @spec train_hint(Train.t(), String.t() | nil) :: String.t() | nil
  def train_hint(%Train{}, nil), do: nil

  def train_hint(%Train{identifiers: identifiers}, detected) when is_binary(detected) do
    if Enum.any?(identifiers, &String.starts_with?(detected, &1.identifier)) do
      nil
    else
      "This train profile does not match the detected train \"#{detected}\", so gauges here will not move. " <>
        "Add \"#{detected}\" as a train identifier to use them in this cab."
    end
  end
end
