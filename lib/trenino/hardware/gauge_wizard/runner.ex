defmodule Trenino.Hardware.GaugeWizard.Runner do
  @moduledoc """
  Carries out the effects requested by `Trenino.Hardware.GaugeWizard`.

  This is the only place the wizard reaches `StepperManager` and the database. It reuses the
  existing operations: manual control claim/release, `StepperManager.command/4`, saving the
  dial through `Hardware.save_dial_calibration/2`, and commissioning only through
  `StepperManager.complete_commissioning/2`. Manual control is held by the calling process
  (the LiveView), which the manager monitors, so it needs no renewal and is dropped if the
  page goes away.
  """
  alias Trenino.Hardware
  alias Trenino.Hardware.GaugeWizard
  alias Trenino.Hardware.GaugeWizard.Observation
  alias Trenino.Hardware.StepperManager

  require Logger

  @doc "Runs one effect for the wizard state and returns the event to feed back."
  @spec run(GaugeWizard.effect(), GaugeWizard.t()) :: {:result, GaugeWizard.effect(), term()}
  def run(effect, %GaugeWizard{} = state) do
    result = execute(effect, state)
    log_failure(effect, result)
    {:result, effect, result}
  end

  defp log_failure(effect, {:error, reason}),
    do: Logger.warning("Gauge wizard effect #{inspect(effect)} failed: #{inspect(reason)}")

  defp log_failure(_effect, _result), do: :ok

  defp execute(:claim, state),
    do: StepperManager.claim_manual(state.axis.id, self(), resume_on_owner_loss: true)

  defp execute(:release, %{token: token} = state),
    do: StepperManager.release_manual(state.axis.id, token)

  defp execute(:resume, state), do: StepperManager.resume(state.axis.id)
  defp execute(:recover, state), do: StepperManager.recover(state.axis.device_id)

  defp execute(:complete_commissioning, state),
    do: StepperManager.complete_commissioning(state.axis.id, state.token)

  defp execute(:apply, state), do: Hardware.apply_saved_configuration(state.axis.device_id)

  defp execute({:command, op, params}, state),
    do: StepperManager.command(state.axis.id, op, params, state.token)

  defp execute({:update_axis, attrs}, state), do: execute({:update_axis, attrs, []}, state)

  defp execute({:update_axis, attrs, opts}, state) do
    with {:ok, axis} <- Hardware.get_stepper_axis(state.axis.id),
         do: Hardware.update_stepper_axis(axis, attrs, opts)
  end

  defp execute({:save_dial, attrs}, state) do
    with {:ok, axis} <- Hardware.get_stepper_axis(state.axis.id),
         do: Hardware.save_dial_calibration(axis, attrs)
  end

  @doc "Builds the observation for the wizard's axis from the manager's authoritative snapshot."
  @spec observe(GaugeWizard.t()) :: Observation.t()
  def observe(%GaugeWizard{axis: axis}) do
    GaugeWizard.observation(
      StepperManager.snapshot(axis.device_id),
      axis,
      System.monotonic_time(:millisecond)
    )
  end
end
