defmodule Trenino.MCP.Tools.GaugeSerialization do
  @moduledoc false
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train.GaugeBinding

  def gauge(%Gauge{} = gauge) do
    gauge
    |> Map.take([
      :id,
      :device_id,
      :name,
      :driver,
      :pins,
      :travel,
      :max_speed,
      :acceleration,
      :reverse
    ])
    |> Map.put(:dial, dial(loaded(gauge.dial_calibration)))
  end

  def binding(%GaugeBinding{} = b) do
    Map.put(
      Map.take(b, GaugeBinding.__schema__(:fields)),
      :dial,
      dial(GaugeBinding.calibration(b.gauge))
    )
  end

  defp loaded(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded(value), do: value

  @doc "The gauge dial calibration as plain data, or `nil` when none is recorded."
  def dial(nil), do: nil

  def dial(%DialCalibration{} = c) do
    %{
      gauge_id: c.gauge_id,
      output_unit: c.output_unit,
      valid: c.valid,
      reviewed: c.reviewed,
      points: Enum.map(c.points, &Map.take(&1, [:value, :position]))
    }
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

  defp plain(:needs_apply),
    do:
      "The device has not confirmed the saved configuration. Call apply_device_configuration first."

  defp plain(:too_many_modules),
    do:
      "A controller stores at most 8 inputs, matrices, displays and gauges together. Move some to another controller, then apply again."

  defp plain(:gauge_pin_conflict),
    do:
      "A gauge shares a pin with an input, matrix or output on this device. Move one of them to a free pin, then apply again."

  defp plain(:device_not_connected),
    do: "The device is not connected. Connect it and try again."

  defp plain(:device_rejected),
    do:
      "The device rejected the configuration. For gauges check: at most 4, no shared pins except RESET_N, and direct drive only on AVR boards (Pro Micro, Leonardo, Micro, Uno, Nano, Mega)."

  defp plain(:no_inputs),
    do:
      "This configuration is empty. Add at least one input, matrix, output, display or gauge, then apply again."

  defp plain(:firmware_update_required),
    do:
      "This needs newer device firmware (3.3.0 or newer for gauges). Update the device firmware, then try again."

  defp plain(reason) when is_atom(reason),
    do: reason |> Atom.to_string() |> String.replace("_", " ")

  defp plain(reason), do: inspect(reason)
end
