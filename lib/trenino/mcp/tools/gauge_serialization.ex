defmodule Trenino.MCP.Tools.GaugeSerialization do
  @moduledoc false
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Train.GaugeBinding
  def axis(%StepperAxis{} = axis), do: Map.take(axis, StepperAxis.__schema__(:fields))

  def binding(%GaugeBinding{} = b) do
    b
    |> Map.take(GaugeBinding.__schema__(:fields))
    |> Map.put(:points, Enum.map(b.points, &Map.take(&1, [:value, :position])))
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
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    {:error, Jason.encode!(errors)}
  end

  def result({:error, reason}), do: {:error, plain(reason)}
  def result(:ok), do: {:ok, %{accepted: true}}
  def result(result), do: result
  defp plain(nil), do: nil

  defp plain(reason) when is_atom(reason),
    do: reason |> Atom.to_string() |> String.replace("_", " ")

  defp plain(reason), do: inspect(reason)
end
