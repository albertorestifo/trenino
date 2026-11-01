defmodule Trenino.MCP.Tools.GaugeBindingTools do
  @moduledoc "Gauge configuration and pure preview through the shared train context."
  alias Trenino.MCP.Tools.GaugeSerialization, as: Serialization
  alias Trenino.Train
  alias Trenino.Train.GaugeMapper

  def tools do
    Enum.map(
      [
        {"list_gauge_bindings", ["train_id"]},
        {"create_gauge_binding", ["train_id", "stepper_axis_id", "name", "endpoint"]},
        {"update_gauge_binding", ["id"]},
        {"delete_gauge_binding", ["id"]},
        {"preview_gauge_binding", ["id", "value"]}
      ],
      fn {name, required} ->
        %{
          name: name,
          description:
            "Train gauge binding: which simulator value drives a stepper axis. Disabled by default; enabling requires a commissioned hold axis whose dial is calibrated and reviewed (see get_dial_calibration / update_dial_calibration: the dial belongs to the axis, not the train). input_unit is what the simulator reports (raw/mps/kmh/mph); raw only fits a raw dial. Preview never moves. inactive_behavior can only be hold (the needle stops where it is when the train or data goes inactive); release is rejected. Select a verified endpoint and value key; never guess units.",
          input_schema: %{type: "object", required: required, properties: properties()}
        }
      end
    )
  end

  defp properties do
    Map.new(
      [
        id: "integer",
        train_id: "integer",
        stepper_axis_id: "integer",
        name: "string",
        endpoint: "string",
        value_key: "string",
        input_unit: "string",
        multiplier: "number",
        offset: "number",
        absolute_value: "boolean",
        out_of_range: "string",
        inactive_behavior: "string",
        stale_after_ms: "integer",
        enabled: "boolean",
        value: "number"
      ],
      fn {key, type} -> {key, %{type: type}} end
    )
  end

  def execute("list_gauge_bindings", %{"train_id" => id}) when is_integer(id),
    do: {:ok, %{bindings: Enum.map(Train.list_gauge_bindings(id), &Serialization.binding/1)}}

  def execute("create_gauge_binding", %{"train_id" => id} = args) when is_integer(id),
    do: Train.create_gauge_binding(id, Map.drop(args, ["train_id", "id"])) |> result()

  def execute("update_gauge_binding", %{"id" => id} = args) when is_integer(id) do
    with {:ok, binding} <- Train.get_gauge_binding(id),
         do: Train.update_gauge_binding(binding, Map.drop(args, ["train_id", "id"])) |> result()
  end

  def execute("delete_gauge_binding", %{"id" => id}) when is_integer(id) do
    with {:ok, binding} <- Train.get_gauge_binding(id),
         {:ok, _} <- Train.delete_gauge_binding(binding),
         do: {:ok, %{deleted: true}}
  end

  def execute("preview_gauge_binding", %{"id" => id, "value" => value}) when is_integer(id) do
    with {:ok, b} <- Train.get_gauge_binding(id), do: GaugeMapper.map(b, value, b.stepper_axis)
  end

  def execute(_, _), do: {:error, "Missing or invalid parameters"}
  defp result({:ok, b}), do: {:ok, %{binding: Serialization.binding(b)}}
  defp result(error), do: Serialization.result(error)
end
