defmodule Trenino.MCP.Tools.GaugeRuntimeTools do
  @moduledoc "Read-only view of what the gauge controller is doing right now."
  alias Trenino.Train
  alias Trenino.Train.GaugeController

  def tools do
    [
      %{
        name: "get_gauge_runtime",
        description:
          "Live gauge controller state for a train (default: the active train), read-only. Returns controller state (simulator_connected, cleaning, cleanup_attempts, last_error, subscribed_endpoints) and per binding the latest raw sample, converted value, target, clamped, stale, inactive, age_ms and failure (subscribe/poll/mapping error, or why the position was not sent: manual_control while move_gauge or the calibration panel holds the gauge, needs_apply, device_not_connected, firmware_update_required). A stale binding holds its needle; after a reboot or a new configuration the needle rests at zero until a fresh value arrives. Use it to see why a gauge is not moving. `active: false` means the controller is not running that train.",
        input_schema: %{
          type: "object",
          properties: %{train_id: %{type: "integer"}},
          required: []
        }
      }
    ]
  end

  def execute("get_gauge_runtime", args) do
    case train_id(args) do
      nil -> {:error, "No active train; pass train_id"}
      id when is_integer(id) -> {:ok, runtime(id)}
      _ -> {:error, "train_id must be an integer"}
    end
  end

  def execute(_, _), do: {:error, "Missing or invalid parameters"}

  defp train_id(%{"train_id" => id}), do: id

  defp train_id(_) do
    case Train.get_active_train() do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp runtime(train_id) do
    case GaugeController.runtime(train_id) do
      nil ->
        %{train_id: train_id, active: false, controller: nil, bindings: []}

      %{controller: controller, bindings: statuses} ->
        %{
          train_id: train_id,
          active: true,
          controller: %{controller | last_error: plain(controller.last_error)},
          bindings: bindings(train_id, statuses)
        }
    end
  end

  defp bindings(train_id, statuses) do
    now = System.monotonic_time(:millisecond)

    for binding <- Train.list_gauge_bindings(train_id) do
      base = %{id: binding.id, name: binding.name, endpoint: binding.endpoint}
      Map.merge(base, binding_status(Map.get(statuses, binding.id), now))
    end
  end

  defp binding_status(nil, _now), do: %{reporting: false}

  defp binding_status(status, now) do
    %{
      reporting: true,
      sample: Map.get(status, :sample),
      value: Map.get(status, :value),
      target: Map.get(status, :target),
      clamped: Map.get(status, :clamped),
      stale: Map.get(status, :stale, false),
      inactive: Map.get(status, :inactive, false),
      age_ms: age(status, now),
      failure: plain(Map.get(status, :failure))
    }
  end

  defp age(%{received_at: at}, now), do: now - at
  defp age(_, _), do: nil

  defp plain(nil), do: nil
  defp plain(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp plain(reason), do: inspect(reason)
end
