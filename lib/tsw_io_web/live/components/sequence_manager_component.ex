defmodule TswIoWeb.SequenceManagerComponent do
  @moduledoc """
  LiveComponent for managing sequences within a train configuration.

  Provides UI for:
  - Listing sequences for a train
  - Creating new sequences
  - Editing sequence commands (add/remove/reorder)
  - Deleting sequences
  """

  use TswIoWeb, :live_component

  alias TswIo.Train, as: TrainContext

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:editing_sequence, nil)
     |> assign(:editing_commands, [])
     |> assign(:show_add_modal, false)
     |> assign(:new_sequence_name, "")}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:train_id, assigns.train_id)
      |> assign(:sequences, assigns.sequences || [])

    {:ok, socket}
  end

  @impl true
  def handle_event("open_add_modal", _params, socket) do
    {:noreply, assign(socket, :show_add_modal, true)}
  end

  @impl true
  def handle_event("close_add_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_add_modal, false)
     |> assign(:new_sequence_name, "")}
  end

  @impl true
  def handle_event("update_name", %{"value" => name}, socket) do
    {:noreply, assign(socket, :new_sequence_name, name)}
  end

  @impl true
  def handle_event("create_sequence", _params, socket) do
    name = socket.assigns.new_sequence_name

    if String.trim(name) != "" do
      case TrainContext.create_sequence(socket.assigns.train_id, %{name: name}) do
        {:ok, _sequence} ->
          notify_parent(:sequences_changed)

          {:noreply,
           socket
           |> assign(:show_add_modal, false)
           |> assign(:new_sequence_name, "")}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("edit_sequence", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case TrainContext.get_sequence(id) do
      {:ok, sequence} ->
        commands =
          Enum.map(sequence.commands, fn cmd ->
            %{
              id: cmd.id,
              endpoint: cmd.endpoint,
              value: cmd.value,
              delay_ms: cmd.delay_ms
            }
          end)

        {:noreply,
         socket
         |> assign(:editing_sequence, sequence)
         |> assign(:editing_commands, commands)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_sequence, nil)
     |> assign(:editing_commands, [])}
  end

  @impl true
  def handle_event("add_command", _params, socket) do
    new_command = %{
      id: nil,
      endpoint: "",
      value: 1.0,
      delay_ms: 0
    }

    commands = socket.assigns.editing_commands ++ [new_command]
    {:noreply, assign(socket, :editing_commands, commands)}
  end

  @impl true
  def handle_event("remove_command", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    commands = List.delete_at(socket.assigns.editing_commands, index)
    {:noreply, assign(socket, :editing_commands, commands)}
  end

  @impl true
  def handle_event("update_command", params, socket) do
    index = String.to_integer(params["index"])
    field = String.to_existing_atom(params["field"])
    value = params["value"]

    commands = socket.assigns.editing_commands

    updated_command =
      commands
      |> Enum.at(index)
      |> update_command_field(field, value)

    commands = List.replace_at(commands, index, updated_command)
    {:noreply, assign(socket, :editing_commands, commands)}
  end

  @impl true
  def handle_event("save_commands", _params, socket) do
    sequence = socket.assigns.editing_sequence
    commands = socket.assigns.editing_commands

    command_params =
      Enum.map(commands, fn cmd ->
        %{
          endpoint: cmd.endpoint,
          value: parse_float(cmd.value),
          delay_ms: parse_int(cmd.delay_ms)
        }
      end)

    case TrainContext.set_sequence_commands(sequence, command_params) do
      {:ok, _updated} ->
        notify_parent(:sequences_changed)

        {:noreply,
         socket
         |> assign(:editing_sequence, nil)
         |> assign(:editing_commands, [])}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_sequence", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case TrainContext.get_sequence(id) do
      {:ok, sequence} ->
        case TrainContext.delete_sequence(sequence) do
          {:ok, _} ->
            notify_parent(:sequences_changed)
            {:noreply, socket}

          {:error, _} ->
            {:noreply, socket}
        end

      {:error, _} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("test_sequence", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case TrainContext.get_sequence(id) do
      {:ok, sequence} ->
        commands = sequence.commands || []

        if Enum.empty?(commands) do
          {:noreply, put_flash(socket, :error, "Sequence has no commands to test")}
        else
          # Execute sequence commands in a spawned task
          spawn(fn ->
            execute_test_sequence(commands)
          end)

          {:noreply, put_flash(socket, :info, "Testing sequence: #{sequence.name}")}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not find sequence")}
    end
  end

  defp execute_test_sequence(commands) do
    alias TswIo.Simulator.Connection, as: SimulatorConnection
    alias TswIo.Simulator.ConnectionState

    Enum.each(commands, fn cmd ->
      case SimulatorConnection.get_status() do
        %ConnectionState{status: :connected, client: client} when client != nil ->
          TswIo.Simulator.Client.set(client, cmd.endpoint, cmd.value)

        _ ->
          :ok
      end

      if cmd.delay_ms > 0 do
        Process.sleep(cmd.delay_ms)
      end
    end)
  end

  defp update_command_field(command, :endpoint, value), do: %{command | endpoint: value}
  defp update_command_field(command, :value, value), do: %{command | value: value}
  defp update_command_field(command, :delay_ms, value), do: %{command | delay_ms: value}

  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value / 1

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp parse_int(value) when is_integer(value), do: value

  defp parse_int(value) when is_binary(value) do
    case Integer.parse(value) do
      {i, _} -> i
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  defp notify_parent(msg) do
    send(self(), {__MODULE__, msg})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-base-200/50 rounded-xl p-6 mt-6">
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base font-semibold">Sequences</h3>
        <button phx-click="open_add_modal" phx-target={@myself} class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="w-4 h-4" /> New Sequence
        </button>
      </div>

      <.empty_state :if={Enum.empty?(@sequences)} />

      <div :if={not Enum.empty?(@sequences)} class="space-y-2">
        <.sequence_card
          :for={sequence <- @sequences}
          sequence={sequence}
          myself={@myself}
        />
      </div>

      <.add_sequence_modal
        :if={@show_add_modal}
        name={@new_sequence_name}
        myself={@myself}
      />

      <.edit_sequence_modal
        :if={@editing_sequence}
        sequence={@editing_sequence}
        commands={@editing_commands}
        myself={@myself}
      />
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center py-8 text-base-content/50">
      <.icon name="hero-list-bullet" class="w-12 h-12 mx-auto mb-2 opacity-30" />
      <p class="text-sm">No sequences defined</p>
      <p class="text-xs">Execute multiple commands from a single button press</p>
    </div>
    """
  end

  attr :sequence, :map, required: true
  attr :myself, :any, required: true

  defp sequence_card(assigns) do
    command_count = length(assigns.sequence.commands || [])
    assigns = assign(assigns, :command_count, command_count)

    ~H"""
    <div class="bg-base-100 rounded-lg border border-base-300 p-3">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-3">
          <.icon name="hero-list-bullet" class="w-5 h-5 text-base-content/50" />
          <div>
            <h4 class="font-medium text-sm">{@sequence.name}</h4>
            <p class="text-xs text-base-content/60">
              {@command_count} command{if @command_count != 1, do: "s"}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-1">
          <button
            phx-click="test_sequence"
            phx-value-id={@sequence.id}
            phx-target={@myself}
            class="btn btn-ghost btn-xs text-success"
            title="Test sequence"
            disabled={@command_count == 0}
          >
            <.icon name="hero-play" class="w-4 h-4" />
          </button>
          <button
            phx-click="edit_sequence"
            phx-value-id={@sequence.id}
            phx-target={@myself}
            class="btn btn-ghost btn-xs"
          >
            <.icon name="hero-pencil" class="w-4 h-4" />
          </button>
          <button
            phx-click="delete_sequence"
            phx-value-id={@sequence.id}
            phx-target={@myself}
            class="btn btn-ghost btn-xs text-error"
            data-confirm="Delete this sequence?"
          >
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :myself, :any, required: true

  defp add_sequence_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_modal" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-sm p-6">
        <h2 class="text-lg font-semibold mb-4">New Sequence</h2>

        <div class="mb-4">
          <label class="label">
            <span class="label-text">Name</span>
          </label>
          <input
            type="text"
            value={@name}
            phx-keyup="update_name"
            phx-target={@myself}
            placeholder="e.g., Door Open, Horn Sequence"
            class="input input-bordered w-full"
            autofocus
          />
        </div>

        <div class="flex justify-end gap-2">
          <button
            type="button"
            phx-click="close_add_modal"
            phx-target={@myself}
            class="btn btn-ghost"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click="create_sequence"
            phx-target={@myself}
            disabled={String.trim(@name) == ""}
            class="btn btn-primary"
          >
            Create
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :sequence, :map, required: true
  attr :commands, :list, required: true
  attr :myself, :any, required: true

  defp edit_sequence_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="close_edit" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div class="p-6 border-b border-base-300">
          <h2 class="text-lg font-semibold">{@sequence.name}</h2>
          <p class="text-sm text-base-content/60">
            Commands execute in order. Delay specifies wait time after each command.
          </p>
        </div>

        <div class="flex-1 overflow-y-auto p-6">
          <div class="space-y-3">
            <div
              :for={{cmd, index} <- Enum.with_index(@commands)}
              class="bg-base-200/50 rounded-lg p-4"
            >
              <div class="flex items-start gap-3">
                <div class="flex-none w-8 pt-2 text-center">
                  <span class="text-sm font-semibold text-base-content/50">{index + 1}</span>
                </div>

                <div class="flex-1 grid grid-cols-3 gap-3">
                  <div class="col-span-2">
                    <label class="label py-1">
                      <span class="label-text text-xs">Endpoint</span>
                    </label>
                    <input
                      type="text"
                      value={cmd.endpoint}
                      phx-keyup="update_command"
                      phx-value-index={index}
                      phx-value-field="endpoint"
                      phx-target={@myself}
                      placeholder="CurrentDrivableActor/..."
                      class="input input-bordered input-sm w-full font-mono"
                    />
                  </div>
                  <div>
                    <label class="label py-1">
                      <span class="label-text text-xs">Value</span>
                    </label>
                    <input
                      type="number"
                      value={cmd.value}
                      step="0.01"
                      phx-keyup="update_command"
                      phx-value-index={index}
                      phx-value-field="value"
                      phx-target={@myself}
                      class="input input-bordered input-sm w-full font-mono"
                    />
                  </div>
                </div>

                <div class="flex-none w-24">
                  <label class="label py-1">
                    <span class="label-text text-xs">Delay (ms)</span>
                  </label>
                  <input
                    type="number"
                    value={cmd.delay_ms}
                    min="0"
                    step="50"
                    phx-keyup="update_command"
                    phx-value-index={index}
                    phx-value-field="delay_ms"
                    phx-target={@myself}
                    class="input input-bordered input-sm w-full font-mono"
                  />
                </div>

                <div class="flex-none pt-7">
                  <button
                    type="button"
                    phx-click="remove_command"
                    phx-value-index={index}
                    phx-target={@myself}
                    class="btn btn-ghost btn-xs btn-circle text-error"
                  >
                    <.icon name="hero-x-mark" class="w-4 h-4" />
                  </button>
                </div>
              </div>
            </div>

            <button
              type="button"
              phx-click="add_command"
              phx-target={@myself}
              class="btn btn-ghost btn-sm w-full"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Add Command
            </button>
          </div>
        </div>

        <div class="p-6 border-t border-base-300 flex justify-end gap-2">
          <button
            type="button"
            phx-click="close_edit"
            phx-target={@myself}
            class="btn btn-ghost"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click="save_commands"
            phx-target={@myself}
            class="btn btn-primary"
          >
            <.icon name="hero-check" class="w-4 h-4" /> Save
          </button>
        </div>
      </div>
    </div>
    """
  end
end
