defmodule Trenino.MCP.Tools.SequenceTools do
  @moduledoc """
  MCP tools for CRUD operations on command sequences.

  Sequences are ordered lists of simulator API commands that can be
  triggered by button bindings. Each command sends a value to a
  simulator endpoint with an optional delay before the next command.
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "list_sequences",
        description:
          "List all command sequences for a train. Sequences can be used with button bindings " <>
            "in 'sequence' mode to execute multiple simulator commands in order.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"}
          },
          required: ["train_id"]
        }
      },
      %{
        name: "create_sequence",
        description:
          "Create a named command sequence for a train. Commands are executed in order, " <>
            "each sending a value to a simulator endpoint with an optional delay before the next command. " <>
            "Use list_simulator_endpoints to find valid endpoint paths.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Startup sequence'"},
            commands: %{
              type: "array",
              description: "Ordered list of commands to execute",
              items: %{
                type: "object",
                properties: %{
                  endpoint: %{type: "string", description: "Simulator API endpoint path"},
                  value: %{type: "number", description: "Value to send"},
                  delay_ms: %{
                    type: "integer",
                    description:
                      "Delay in ms after this command before next (0-60000, default: 0)"
                  }
                },
                required: ["endpoint", "value"]
              }
            }
          },
          required: ["train_id", "name", "commands"]
        }
      },
      %{
        name: "update_sequence",
        description:
          "Update a sequence's name or replace all its commands. " <>
            "When providing commands, all existing commands are replaced.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Sequence ID"},
            name: %{type: "string", description: "New name for the sequence"},
            commands: %{
              type: "array",
              description: "New ordered list of commands (replaces all existing commands)",
              items: %{
                type: "object",
                properties: %{
                  endpoint: %{type: "string", description: "Simulator API endpoint path"},
                  value: %{type: "number", description: "Value to send"},
                  delay_ms: %{type: "integer", description: "Delay in ms (0-60000, default: 0)"}
                },
                required: ["endpoint", "value"]
              }
            }
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_sequence",
        description:
          "Delete a command sequence. This will also remove any button binding references to it.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Sequence ID to delete"}
          },
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_sequences", %{"train_id" => train_id}) do
    sequences =
      TrainContext.list_sequences(train_id)
      |> Enum.map(&serialize/1)

    {:ok, %{sequences: sequences}}
  end

  def execute("create_sequence", %{"train_id" => train_id, "name" => name} = args) do
    with {:ok, sequence} <- TrainContext.create_sequence(train_id, %{name: name}),
         {:ok, sequence} <- set_commands_if_present(sequence, args) do
      {:ok, %{sequence: serialize(sequence)}}
    else
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_changeset_errors(changeset)}
      {:error, reason} -> {:error, "Failed to set commands: #{inspect(reason)}"}
    end
  end

  def execute("update_sequence", %{"id" => id} = args) do
    case TrainContext.get_sequence(id) do
      {:ok, sequence} ->
        result =
          with :ok <- maybe_update_name(sequence, args),
               :ok <- maybe_update_commands(sequence, args) do
            {:ok, updated} = TrainContext.get_sequence(id)
            {:ok, %{sequence: serialize(updated)}}
          end

        case result do
          {:ok, _} = success -> success
          {:error, _} = error -> error
        end

      {:error, :not_found} ->
        {:error, "Sequence not found with id #{id}"}
    end
  end

  def execute("delete_sequence", %{"id" => id}) do
    case TrainContext.get_sequence(id) do
      {:ok, sequence} ->
        case TrainContext.delete_sequence(sequence) do
          {:ok, _} -> {:ok, %{deleted: true, id: id}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Sequence not found with id #{id}"}
    end
  end

  defp maybe_update_name(sequence, %{"name" => name}) do
    case TrainContext.update_sequence(sequence, %{name: name}) do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, format_changeset_errors(changeset)}
    end
  end

  defp maybe_update_name(_sequence, _args), do: :ok

  defp maybe_update_commands(sequence, %{"commands" => commands}) do
    command_attrs = build_command_attrs(commands)

    case TrainContext.set_sequence_commands(sequence, command_attrs) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, "Failed to set commands: #{inspect(reason)}"}
    end
  end

  defp maybe_update_commands(_sequence, _args), do: :ok

  defp set_commands_if_present(sequence, %{"commands" => commands}) when commands != [] do
    command_attrs = build_command_attrs(commands)

    case TrainContext.set_sequence_commands(sequence, command_attrs) do
      {:ok, _} ->
        TrainContext.get_sequence(sequence.id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp set_commands_if_present(sequence, _args), do: {:ok, sequence}

  defp build_command_attrs(commands) do
    commands
    |> Enum.with_index()
    |> Enum.map(fn {cmd, index} ->
      %{
        position: index,
        endpoint: cmd["endpoint"],
        value: cmd["value"],
        delay_ms: Map.get(cmd, "delay_ms", 0)
      }
    end)
  end

  defp serialize(s) do
    %{
      id: s.id,
      name: s.name,
      train_id: s.train_id,
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

  defp format_changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    "Validation failed: " <>
      Enum.map_join(errors, "; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)
  end
end
