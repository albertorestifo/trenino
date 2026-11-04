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

  @typedoc """
  The one-word state of an axis card. `primary` is the single promoted action:
  `:wizard` (guided setup), `:rezero`, `:resume` or `nil`.
  """
  @type axis_status :: %{
          state:
            :ready
            | :needs_setup
            | :needs_rezero
            | :needs_apply
            | :paused
            | :manual
            | :zeroing
            | :moving
            | :starting
            | :fault
            | :offline
            | :unsupported,
          label: String.t(),
          kind: :ok | :warn | :error | :info | :muted,
          reason: String.t() | nil,
          primary: :wizard | :rezero | :resume | nil
        }

  @doc """
  The resting-view summary of an axis: one state, one reason (only when something needs
  attention) and the one action that moves the operator forward. Read-only.

  "Set up" is one fact for the operator: the axis is commissioned, holds when idle and its
  dial is saved, valid and reviewed. All of it comes from the guided gauge setup.
  """
  @spec axis_status(StepperAxis.t(), snapshot()) :: axis_status()
  def axis_status(%StepperAxis{} = axis, snapshot),
    do: classify(snapshot.lifecycle, snapshot, axis, snapshot.axes[axis.id])

  @doc "Whether train output may drive this axis once it is referenced (see `axis_status/2`)."
  @spec set_up?(StepperAxis.t()) :: boolean()
  def set_up?(%StepperAxis{commissioned: true, idle_behavior: :hold} = axis),
    do: match?(%DialCalibration{valid: true, reviewed: true}, GaugeBinding.calibration(axis))

  def set_up?(%StepperAxis{}), do: false

  defp classify(:disconnected, _, _, _),
    do: status(:offline, "Offline", :muted, "Connect the controller to use this gauge.", nil)

  defp classify(:unsupported, _, _, _),
    do:
      status(
        :unsupported,
        "Update firmware",
        :warn,
        "Update the controller firmware to 3.1.0 or newer.",
        nil
      )

  defp classify(:fault, snapshot, axis, _) do
    detail = GaugeFeedback.fault(Map.get(snapshot, :error) || :unknown)
    status(:fault, "Fault", :error, detail, if(set_up?(axis), do: :rezero, else: :wizard))
  end

  defp classify(lifecycle, _, _, _)
       when lifecycle in [:probing, :deploying, :resetting, :configuring],
       do: status(:starting, "Starting", :info, nil, nil)

  defp classify(_, _, axis, runtime) do
    cond do
      not set_up?(axis) ->
        status(
          :needs_setup,
          "Needs setup",
          :warn,
          "Line up zero, check the direction and mark the dial.",
          :wizard
        )

      not applied?(axis, runtime) ->
        status(
          :needs_apply,
          "Apply needed",
          :warn,
          "The saved settings are not on the controller yet. Apply the configuration.",
          nil
        )

      runtime.lease != nil ->
        status(:manual, "Manual control", :info, manual_reason(runtime.lease), nil)

      zeroing?(runtime) ->
        status(:zeroing, "Zeroing", :info, nil, nil)

      moving?(runtime) ->
        status(:moving, "Moving", :info, nil, nil)

      not runtime.ready ->
        status(:needs_rezero, "Needs re-zero", :warn, rezero_reason(axis), :rezero)

      runtime.paused ->
        status(:paused, "Paused", :warn, "Train output is paused for this gauge.", :resume)

      true ->
        status(:ready, "Ready", :ok, nil, nil)
    end
  end

  # Train targets are refused until the device runs the saved configuration. A session
  # without this axis was started before it was added.
  defp applied?(_axis, nil), do: false

  defp applied?(axis, %{config: %StepperAxis{} = config}),
    do:
      config.axis_index == axis.axis_index and
        StepperAxis.to_protocol_config(config) == StepperAxis.to_protocol_config(axis)

  defp applied?(_axis, _runtime), do: true

  defp status(state, label, kind, reason, primary),
    do: %{state: state, label: label, kind: kind, reason: reason, primary: primary}

  defp manual_reason(%{owner: :mcp}), do: "An assistant has manual control through MCP."
  defp manual_reason(_), do: "Train output is paused while manual control is held."

  defp rezero_reason(%StepperAxis{reference_strategy: :internal_stop}),
    do: "Trenino lost track of the needle (reconnect, stop or fault). Re-zero to resume."

  defp rezero_reason(_),
    do: "Trenino lost track of the needle. Line it up on 0 by hand, then re-zero."

  @doc "Whether the axis needle is in motion right now (reported or just commanded)."
  @spec moving?(map() | nil) :: boolean()
  def moving?(%{status: %{state: state}}) when state in [:moving, :homing], do: true
  def moving?(%{pending: %{command: %{operation: op}}}) when op in [:move_to, :home], do: true
  def moving?(_), do: false

  defp zeroing?(%{status: %{state: :homing}}), do: true
  defp zeroing?(%{pending: %{command: %{operation: :home}}}), do: true
  defp zeroing?(_), do: false

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
        "Not moving: the gauge is not set up. Run the gauge setup on its stepper axis first."

      match?(%DialCalibration{valid: false}, GaugeBinding.calibration(axis)) ->
        "Not moving: the dial is blocked because the axis changed or a homing setup was left unfinished. Run the gauge wizard again."

      true ->
        lifecycle_blocker(snapshot, snapshot.axes[axis.id])
    end
  end

  defp lifecycle_blocker(%{lifecycle: :disconnected}, _),
    do: "Not moving: the device is not connected."

  defp lifecycle_blocker(%{lifecycle: :fault}, _),
    do: "Not moving: the axis is in a fault state. Re-zero it on its stepper axis."

  defp lifecycle_blocker(%{lifecycle: :unsupported}, _),
    do: "Not moving: the controller firmware does not support steppers."

  defp lifecycle_blocker(%{lifecycle: lifecycle}, nil) when lifecycle != :ready,
    do: "Not moving: the device is still being configured."

  defp lifecycle_blocker(_, %{ready: false}),
    do: "Not moving: the needle needs re-zeroing. Re-zero it on its stepper axis."

  defp lifecycle_blocker(_, %{paused: true}),
    do: "Not moving: train output is paused. Resume it on its stepper axis."

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
