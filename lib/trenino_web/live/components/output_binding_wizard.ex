defmodule TreninoWeb.OutputBindingWizard do
  @moduledoc """
  Configuration wizard for output bindings.

  Flow:
  1. Select API endpoint using the API explorer
  2. Select output device and pin
  3. Select output type (LED only for now)
  4. Configure condition (operator and threshold values)
  5. Enter name and save

  ## Usage

      <.live_component
        module={TreninoWeb.OutputBindingWizard}
        id="output-wizard"
        train_id={@train.id}
        client={@simulator_client}
        available_outputs={@available_outputs}
        binding={nil}
      />

  ## Events sent to parent

  - `{:output_binding_saved, binding}` - When configuration is saved
  - `{:output_binding_cancelled}` - When user cancels
  """

  use TreninoWeb, :live_component

  require Logger

  alias Trenino.Train
  alias Trenino.Train.OutputBinding
  alias Trenino.Train.OutputController

  @impl true
  def update(%{train_id: train_id} = assigns, socket) do
    socket =
      socket
      |> assign(:train_id, train_id)
      |> assign(:client, assigns.client)
      |> assign(:available_outputs, Map.get(assigns, :available_outputs, []))
      |> assign(:binding, Map.get(assigns, :binding))

    socket =
      if socket.assigns[:initialized] do
        socket
      else
        initialize_wizard(socket, assigns[:binding])
      end

    socket = handle_explorer_event(assigns, socket)

    {:ok, socket}
  end

  def update(assigns, socket) do
    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  defp handle_explorer_event(%{explorer_event: {:select, _field, path}}, socket) do
    socket
    |> assign(:endpoint, path)
    |> assign(:wizard_step, :select_output)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), :output_binding_cancelled)
    assign(socket, :explorer_event, nil)
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, nil) do
    socket
    |> assign(:wizard_step, :select_endpoint)
    |> assign(:endpoint, nil)
    |> assign(:selected_output_id, nil)
    |> assign(:output_type, :led)
    |> assign(:operator, :gt)
    |> assign(:value_a, 0.0)
    |> assign(:value_b, nil)
    |> assign(:name, "")
    |> assign(:initialized, true)
  end

  defp initialize_wizard(socket, %OutputBinding{} = binding) do
    socket
    |> assign(:wizard_step, :configure_condition)
    |> assign(:endpoint, binding.endpoint)
    |> assign(:selected_output_id, binding.output_id)
    |> assign(:output_type, binding.output_type)
    |> assign(:operator, binding.operator)
    |> assign(:value_a, binding.value_a)
    |> assign(:value_b, binding.value_b)
    |> assign(:name, binding.name)
    |> assign(:initialized, true)
  end

  @impl true
  def handle_event("select_output", %{"output-id" => output_id_str}, socket) do
    output_id = String.to_integer(output_id_str)

    socket =
      socket
      |> assign(:selected_output_id, output_id)
      |> assign(:wizard_step, :select_type)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_output_type", %{"type" => type}, socket) do
    socket =
      socket
      |> assign(:output_type, String.to_existing_atom(type))
      |> assign(:wizard_step, :configure_condition)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_condition", params, socket) do
    socket =
      socket
      |> maybe_update_operator(params)
      |> maybe_update_value_a(params)
      |> maybe_update_value_b(params)
      |> maybe_update_name(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("back", _params, socket) do
    prev_step =
      case socket.assigns.wizard_step do
        :select_output -> :select_endpoint
        :select_type -> :select_output
        :configure_condition -> :select_type
        _ -> :select_endpoint
      end

    {:noreply, assign(socket, :wizard_step, prev_step)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    case save_output_binding(socket) do
      {:ok, binding} ->
        OutputController.reload_bindings()
        send(self(), {:output_binding_saved, binding})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    send(self(), :output_binding_cancelled)
    {:noreply, socket}
  end

  defp maybe_update_operator(socket, %{"operator" => op_str}) do
    assign(socket, :operator, String.to_existing_atom(op_str))
  end

  defp maybe_update_operator(socket, _), do: socket

  defp maybe_update_value_a(socket, %{"value_a" => value_str}) do
    case Float.parse(value_str) do
      {value, _} -> assign(socket, :value_a, Float.round(value, 2))
      :error -> socket
    end
  end

  defp maybe_update_value_a(socket, _), do: socket

  defp maybe_update_value_b(socket, %{"value_b" => value_str}) do
    case Float.parse(value_str) do
      {value, _} -> assign(socket, :value_b, Float.round(value, 2))
      :error -> socket
    end
  end

  defp maybe_update_value_b(socket, _), do: socket

  defp maybe_update_name(socket, %{"name" => name}), do: assign(socket, :name, name)
  defp maybe_update_name(socket, _), do: socket

  defp save_output_binding(socket) do
    %{
      train_id: train_id,
      binding: existing_binding,
      endpoint: endpoint,
      selected_output_id: output_id,
      output_type: output_type,
      operator: operator,
      value_a: value_a,
      value_b: value_b,
      name: name
    } = socket.assigns

    params = %{
      output_id: output_id,
      output_type: output_type,
      endpoint: endpoint,
      operator: operator,
      value_a: value_a,
      value_b: if(operator == :between, do: value_b, else: nil),
      name: name
    }

    case existing_binding do
      nil -> Train.create_output_binding(train_id, params)
      binding -> Train.update_output_binding(binding, params)
    end
  end

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp format_errors(_), do: "An error occurred"

  defp can_save?(assigns) do
    assigns.name != "" and
      assigns.endpoint != nil and
      assigns.selected_output_id != nil and
      assigns.value_a != nil and
      (assigns.operator != :between or assigns.value_b != nil)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">
                {if @binding, do: "Edit Output Binding", else: "Add Output Binding"}
              </h2>
              <p class="text-sm text-base-content/60">
                Configure an output to respond to API values
              </p>
            </div>
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>

          <div class="flex items-center gap-2 mt-4">
            <.step_indicator
              step={1}
              label="Endpoint"
              active={@wizard_step == :select_endpoint}
              completed={@wizard_step in [:select_output, :select_type, :configure_condition]}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={2}
              label="Output"
              active={@wizard_step == :select_output}
              completed={@wizard_step in [:select_type, :configure_condition]}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={3}
              label="Type"
              active={@wizard_step == :select_type}
              completed={@wizard_step == :configure_condition}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator step={4} label="Condition" active={@wizard_step == :configure_condition} />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :select_endpoint} class="flex-1 flex flex-col">
            <.live_component
              module={TreninoWeb.ApiExplorerComponent}
              id="output-wizard-api-explorer"
              field={:endpoint}
              client={@client}
              mode={nil}
              embedded={true}
            />
          </div>

          <div :if={@wizard_step == :select_output} class="flex-1 p-6 overflow-y-auto">
            <.output_selection_panel
              myself={@myself}
              available_outputs={@available_outputs}
              selected_output_id={@selected_output_id}
            />
          </div>

          <div :if={@wizard_step == :select_type} class="flex-1 p-6 overflow-y-auto">
            <.output_type_panel myself={@myself} output_type={@output_type} />
          </div>

          <div :if={@wizard_step == :configure_condition} class="flex-1 p-6 overflow-y-auto">
            <.condition_panel
              myself={@myself}
              endpoint={@endpoint}
              selected_output_id={@selected_output_id}
              available_outputs={@available_outputs}
              operator={@operator}
              value_a={@value_a}
              value_b={@value_b}
              name={@name}
              can_save={can_save?(assigns)}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :step, :integer, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false
  attr :completed, :boolean, default: false

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <div class={[
        "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
        @active && "bg-primary text-primary-content",
        @completed && "bg-success text-success-content",
        (not @active and not @completed) && "bg-base-300 text-base-content/50"
      ]}>
        <.icon :if={@completed} name="hero-check" class="w-4 h-4" />
        <span :if={not @completed}>{@step}</span>
      </div>
      <span class={[
        "text-sm",
        @active && "font-medium",
        (not @active and not @completed) && "text-base-content/50"
      ]}>
        {@label}
      </span>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :available_outputs, :list, required: true
  attr :selected_output_id, :integer, default: nil

  defp output_selection_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-6">
        <h3 class="text-xl font-semibold mb-2">Select Output</h3>
        <p class="text-base-content/60">
          Choose which hardware output to control
        </p>
      </div>

      <div :if={@available_outputs == []} class="alert alert-warning">
        <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
        <span>No outputs configured. Add outputs to a device configuration first.</span>
      </div>

      <div :if={@available_outputs != []} class="space-y-2">
        <button
          :for={output <- @available_outputs}
          type="button"
          phx-click="select_output"
          phx-value-output-id={output.id}
          phx-target={@myself}
          class={[
            "w-full p-4 rounded-lg border-2 text-left transition-all",
            @selected_output_id == output.id &&
              "border-primary bg-primary/10",
            @selected_output_id != output.id &&
              "border-base-300 hover:border-primary/50 hover:bg-base-200/50"
          ]}
        >
          <div class="flex items-center gap-3">
            <div class={[
              "p-2 rounded-lg",
              @selected_output_id == output.id && "bg-primary text-primary-content",
              @selected_output_id != output.id && "bg-base-300"
            ]}>
              <.icon name="hero-light-bulb" class="w-5 h-5" />
            </div>
            <div>
              <p class="font-medium">{output.name || "Output #{output.pin}"}</p>
              <p class="text-xs text-base-content/60">
                {output.device.name} - Pin {output.pin}
              </p>
            </div>
          </div>
        </button>
      </div>

      <div class="flex justify-between pt-4 border-t border-base-300">
        <button type="button" phx-click="back" phx-target={@myself} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </button>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :output_type, :atom, required: true

  defp output_type_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-6">
        <h3 class="text-xl font-semibold mb-2">Select Output Type</h3>
        <p class="text-base-content/60">
          Choose how the output should behave
        </p>
      </div>

      <button
        type="button"
        phx-click="select_output_type"
        phx-value-type="led"
        phx-target={@myself}
        class={[
          "w-full p-6 rounded-xl border-2 text-left transition-all",
          @output_type == :led && "border-primary bg-primary/10",
          @output_type != :led && "border-base-300 hover:border-primary/50"
        ]}
      >
        <div class="flex items-start gap-4">
          <div class={[
            "p-3 rounded-lg",
            @output_type == :led && "bg-primary text-primary-content",
            @output_type != :led && "bg-base-300"
          ]}>
            <.icon name="hero-light-bulb" class="w-8 h-8" />
          </div>
          <div>
            <h4 class="font-semibold text-lg">LED (On/Off)</h4>
            <p class="text-base-content/60 mt-1">
              Digital output that turns on when condition is met, off otherwise.
              Ideal for indicator lights, warning LEDs, and status displays.
            </p>
          </div>
        </div>
      </button>

      <div class="text-center text-sm text-base-content/50 mt-4">
        More output types (servo, display, etc.) coming soon
      </div>

      <div class="flex justify-between pt-4 border-t border-base-300">
        <button type="button" phx-click="back" phx-target={@myself} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </button>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :endpoint, :string, required: true
  attr :selected_output_id, :integer, required: true
  attr :available_outputs, :list, required: true
  attr :operator, :atom, required: true
  attr :value_a, :float, required: true
  attr :value_b, :float, default: nil
  attr :name, :string, required: true
  attr :can_save, :boolean, required: true

  defp condition_panel(assigns) do
    selected_output = Enum.find(assigns.available_outputs, &(&1.id == assigns.selected_output_id))
    assigns = assign(assigns, :selected_output, selected_output)

    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="font-semibold mb-2">Summary</h3>
        <div class="bg-base-200 rounded-lg p-4 space-y-2 text-sm">
          <div class="flex justify-between">
            <span class="text-base-content/60">Endpoint:</span>
            <span class="font-mono">{@endpoint}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">Output:</span>
            <span>
              {@selected_output.name || "Output #{@selected_output.pin}"} ({@selected_output.device.name})
            </span>
          </div>
        </div>
      </div>

      <form phx-change="update_condition" phx-target={@myself} class="space-y-4">
        <div>
          <label class="label"><span class="label-text font-medium">Binding Name</span></label>
          <input
            type="text"
            name="name"
            value={@name}
            placeholder="e.g., Speed Warning LED"
            class="input input-bordered w-full"
          />
          <p class="text-xs text-base-content/50 mt-1">
            A descriptive name for this output binding
          </p>
        </div>

        <div>
          <label class="label"><span class="label-text font-medium">Condition</span></label>
          <p class="text-sm text-base-content/60 mb-3">
            Output turns ON when the API value meets this condition
          </p>

          <div class="flex items-center gap-3">
            <span class="text-base-content/70">Value</span>
            <select name="operator" class="select select-bordered">
              <option value="gt" selected={@operator == :gt}>&gt; (greater than)</option>
              <option value="gte" selected={@operator == :gte}>&ge; (greater or equal)</option>
              <option value="lt" selected={@operator == :lt}>&lt; (less than)</option>
              <option value="lte" selected={@operator == :lte}>&le; (less or equal)</option>
              <option value="between" selected={@operator == :between}>between</option>
            </select>
          </div>

          <div class={["mt-3", @operator != :between && "max-w-xs"]}>
            <div :if={@operator != :between} class="flex items-center gap-2">
              <input
                type="number"
                name="value_a"
                step="0.01"
                value={@value_a}
                class="input input-bordered w-32"
              />
            </div>

            <div :if={@operator == :between} class="flex items-center gap-2">
              <input
                type="number"
                name="value_a"
                step="0.01"
                value={@value_a}
                placeholder="min"
                class="input input-bordered w-32"
              />
              <span class="text-base-content/70">and</span>
              <input
                type="number"
                name="value_b"
                step="0.01"
                value={@value_b}
                placeholder="max"
                class="input input-bordered w-32"
              />
            </div>
          </div>
        </div>

        <div class="bg-info/10 border border-info rounded-lg p-4 mt-4">
          <div class="flex items-start gap-2">
            <.icon name="hero-information-circle" class="w-5 h-5 text-info shrink-0 mt-0.5" />
            <div class="text-sm">
              <p class="font-medium text-info">Preview</p>
              <p class="text-base-content/70 mt-1">
                {condition_preview(@operator, @value_a, @value_b)}
              </p>
            </div>
          </div>
        </div>
      </form>

      <div class="flex justify-between pt-4 border-t border-base-300">
        <button type="button" phx-click="back" phx-target={@myself} class="btn btn-ghost">
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </button>
        <button
          type="button"
          phx-click="save"
          phx-target={@myself}
          disabled={not @can_save}
          class="btn btn-primary"
        >
          <.icon name="hero-check" class="w-4 h-4" /> Save
        </button>
      </div>
    </div>
    """
  end

  defp condition_preview(:gt, value_a, _), do: "LED turns ON when value > #{value_a}"
  defp condition_preview(:gte, value_a, _), do: "LED turns ON when value >= #{value_a}"
  defp condition_preview(:lt, value_a, _), do: "LED turns ON when value < #{value_a}"
  defp condition_preview(:lte, value_a, _), do: "LED turns ON when value <= #{value_a}"

  defp condition_preview(:between, value_a, value_b) when is_number(value_b),
    do: "LED turns ON when #{value_a} <= value <= #{value_b}"

  defp condition_preview(:between, value_a, _),
    do: "LED turns ON when #{value_a} <= value <= ?"
end
