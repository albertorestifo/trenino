defmodule Trenino.MCP.Tools.GaugeSerialization do
  @moduledoc false
  alias Trenino.Hardware.{DialCalibration, StepperAxis, StepperLease}
  alias Trenino.Train.GaugeBinding
  def axis(%StepperAxis{} = axis), do: Map.take(axis, StepperAxis.__schema__(:fields))

  def binding(%GaugeBinding{} = b) do
    Map.put(
      Map.take(b, GaugeBinding.__schema__(:fields)),
      :dial,
      dial(GaugeBinding.calibration(b.stepper_axis))
    )
  end

  @doc "The axis dial calibration as plain data, or `nil` when none is recorded."
  def dial(nil), do: nil

  def dial(%DialCalibration{} = c) do
    %{
      stepper_axis_id: c.stepper_axis_id,
      output_unit: c.output_unit,
      valid: c.valid,
      reviewed: c.reviewed,
      points: Enum.map(c.points, &Map.take(&1, [:value, :position]))
    }
  end

  def status(snapshot) do
    axes =
      Map.new(snapshot.axes, fn {id, a} ->
        pending =
          if a.pending,
            do: Map.take(a.pending.command, [:operation, :request_id, :axis, :position]),
            else: nil

        status = if a.status, do: a.status |> Map.from_struct(), else: nil

        {to_string(id),
         %{
           ready: a.ready,
           manual_pause: a.paused,
           lease: a.lease,
           pending: pending,
           error: plain(a.error),
           status: status
         }}
      end)

    %{lifecycle: snapshot.lifecycle, axes: axes, error: plain(Map.get(snapshot, :error))}
  end

  def result({:error, %Ecto.Changeset{} = cs}) do
    errors =
      Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", format_option(value))
        end)
      end)

    {:error, Jason.encode!(errors)}
  end

  def result({:error, reason}), do: {:error, plain(reason)}
  def result(:ok), do: {:ok, %{accepted: true}}
  def result(result), do: result
  # Changeset options are arbitrary terms (enum lists of atoms, types, ...), so only
  # chardata-safe values are stringified directly.
  defp format_option(value) when is_binary(value), do: value
  defp format_option(value) when is_atom(value) or is_number(value), do: to_string(value)
  defp format_option(value) when is_list(value), do: Enum.map_join(value, ", ", &format_option/1)
  defp format_option(value), do: inspect(value)

  defp plain(nil), do: nil
  defp plain({:lease_held, info}), do: StepperLease.message(info)

  defp plain(:lease_expired_finishing_motion),
    do:
      "The lease expired but an accepted move or home is still finishing; only renew, stop or release_lease work now. Claim again once the axis is stationary."

  defp plain(reason) when is_atom(reason),
    do: reason |> Atom.to_string() |> String.replace("_", " ")

  defp plain(reason), do: inspect(reason)
end
