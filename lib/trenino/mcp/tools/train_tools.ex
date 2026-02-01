defmodule Trenino.MCP.Tools.TrainTools do
  @moduledoc """
  MCP tools for listing and inspecting train configurations.
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "list_trains",
        description:
          "List all configured trains. Returns id, name, identifier, and description for each train.",
        input_schema: %{
          type: "object",
          properties: %{}
        }
      },
      %{
        name: "get_train",
        description:
          "Get a train's full configuration including its elements (levers and buttons) " <>
            "and output bindings. Use this to understand the train's current setup before making changes.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID from list_trains"}
          },
          required: ["train_id"]
        }
      }
    ]
  end

  def execute("list_trains", _args) do
    trains =
      TrainContext.list_trains()
      |> Enum.map(fn t ->
        %{id: t.id, name: t.name, identifier: t.identifier, description: t.description}
      end)

    {:ok, %{trains: trains}}
  end

  def execute("get_train", %{"train_id" => train_id}) do
    case TrainContext.get_train(train_id, preload: [:elements]) do
      {:ok, train} ->
        output_bindings =
          TrainContext.list_output_bindings(train.id)
          |> Enum.map(&serialize_output_binding/1)

        button_bindings =
          TrainContext.list_button_bindings_for_train(train.id)
          |> Enum.map(&serialize_button_binding/1)

        sequences =
          TrainContext.list_sequences(train.id)
          |> Enum.map(&serialize_sequence/1)

        {:ok,
         %{
           train: %{
             id: train.id,
             name: train.name,
             identifier: train.identifier,
             description: train.description,
             elements:
               Enum.map(train.elements, fn e ->
                 %{id: e.id, name: e.name, type: e.type}
               end),
             output_bindings: output_bindings,
             button_bindings: button_bindings,
             sequences: sequences
           }
         }}

      {:error, :not_found} ->
        {:error, "Train not found with id #{train_id}"}
    end
  end

  defp serialize_output_binding(b) do
    %{
      id: b.id,
      name: b.name,
      endpoint: b.endpoint,
      operator: b.operator,
      output_id: b.output_id,
      value_a: b.value_a,
      value_b: b.value_b,
      enabled: b.enabled
    }
  end

  defp serialize_button_binding(b) do
    %{
      id: b.id,
      element_id: b.element_id,
      input_id: b.input_id,
      mode: b.mode,
      endpoint: b.endpoint,
      on_value: b.on_value,
      off_value: b.off_value,
      enabled: b.enabled,
      hardware_type: b.hardware_type,
      keystroke: b.keystroke,
      repeat_interval_ms: b.repeat_interval_ms,
      on_sequence_id: b.on_sequence_id,
      off_sequence_id: b.off_sequence_id
    }
  end

  defp serialize_sequence(s) do
    %{
      id: s.id,
      name: s.name,
      commands:
        case s.commands do
          %Ecto.Association.NotLoaded{} ->
            []

          commands ->
            Enum.map(commands, fn c ->
              %{
                id: c.id,
                position: c.position,
                endpoint: c.endpoint,
                value: c.value,
                delay_ms: c.delay_ms
              }
            end)
        end
    }
  end
end
