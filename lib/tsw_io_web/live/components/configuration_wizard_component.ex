defmodule TswIoWeb.ConfigurationWizardComponent do
  @moduledoc """
  Unified configuration wizard for train elements.

  Uses API explorer as the primary interface with auto-detection as default.
  Handles both lever and button configuration with a consistent flow:
  1. Browse API tree in explorer
  2. Auto-detect or manually select endpoints
  3. Test configuration (buttons only)
  4. Confirm and save

  ## Usage

      <.live_component
        module={TswIoWeb.ConfigurationWizardComponent}
        id="config-wizard"
        mode={:lever}
        element={@element}
        client={@simulator_client}
        available_inputs={@available_inputs}
      />

  ## Events sent to parent

  - `{:configuration_complete, element_id, result}` - When configuration is saved
  - `{:configuration_cancelled, element_id}` - When user cancels
  """

  use TswIoWeb, :live_component

  alias TswIo.Simulator.Client
  alias TswIo.Train
  alias TswIo.Train.Element

  @impl true
  def update(%{element: %Element{} = element, mode: mode} = assigns, socket) do
    socket =
      socket
      |> assign(:element, element)
      |> assign(:mode, mode)
      |> assign(:client, assigns.client)
      |> assign(:available_inputs, Map.get(assigns, :available_inputs, []))

    # Initialize on first mount
    socket =
      if socket.assigns[:initialized] do
        socket
      else
        initialize_wizard(socket, element, mode)
      end

    # Handle forwarded API explorer events from parent
    socket = handle_explorer_event(assigns, socket)

    {:ok, socket}
  end

  def update(assigns, socket) do
    # Handle forwarded API explorer events from parent
    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  # Handle API explorer events forwarded from parent via assigns
  defp handle_explorer_event(%{explorer_event: {:auto_configure, endpoints}}, socket) do
    socket
    |> assign(:detected_endpoints, endpoints)
    |> assign(:wizard_step, :confirming)
    |> assign(:mapping_complete, true)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: {:button_detected, detection}}, socket) do
    # Use suggested values from detection if available
    on_value = detection[:suggested_on] || socket.assigns.on_value
    off_value = detection[:suggested_off] || socket.assigns.off_value

    socket
    |> assign(:detected_endpoints, detection)
    |> assign(:on_value, on_value)
    |> assign(:off_value, off_value)
    |> assign(:wizard_step, :testing)
    |> check_mapping_complete()
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :individual_selection}, socket) do
    socket
    |> assign(:individual_selection_mode, true)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: {:select, field, path}}, socket) do
    manual_selections = Map.put(socket.assigns.manual_selections, field, path)

    socket
    |> assign(:manual_selections, manual_selections)
    |> check_mapping_complete()
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), {:configuration_cancelled, socket.assigns.element.id})
    assign(socket, :explorer_event, nil)
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, element, mode) do
    socket
    |> assign(:wizard_step, :browsing)
    |> assign(:detected_endpoints, nil)
    |> assign(:manual_selections, %{})
    |> assign(:mapping_complete, false)
    |> assign(:test_state, nil)
    |> assign(:selected_input_id, get_existing_input_id(element, mode))
    |> assign(:on_value, get_existing_on_value(element, mode))
    |> assign(:off_value, get_existing_off_value(element, mode))
    |> assign(:show_explorer, true)
    |> assign(:individual_selection_mode, false)
    |> assign(:initialized, true)
  end

  defp get_existing_input_id(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.input_id
  end

  defp get_existing_input_id(_element, _mode), do: nil

  defp get_existing_on_value(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.on_value
  end

  defp get_existing_on_value(_element, _mode), do: 1.0

  defp get_existing_off_value(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.off_value
  end

  defp get_existing_off_value(_element, _mode), do: 0.0

  @impl true
  def handle_event("select_input", %{"input-id" => input_id_str}, socket) do
    input_id = String.to_integer(input_id_str)

    socket =
      socket
      |> assign(:selected_input_id, input_id)
      |> check_mapping_complete()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_on_value", %{"value" => value_str}, socket) do
    case Float.parse(value_str) do
      {value, _} -> {:noreply, assign(socket, :on_value, Float.round(value, 2))}
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_off_value", %{"value" => value_str}, socket) do
    case Float.parse(value_str) do
      {value, _} -> {:noreply, assign(socket, :off_value, Float.round(value, 2))}
      :error -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("test_on", _params, socket) do
    endpoint = get_configured_endpoint(socket)
    on_value = socket.assigns.on_value

    case send_test_value(socket.assigns.client, endpoint, on_value) do
      {:ok, _body} ->
        {:noreply, assign(socket, :test_state, {:on, DateTime.utc_now()})}

      {:error, _reason} ->
        {:noreply, assign(socket, :test_state, {:error, :on})}
    end
  end

  @impl true
  def handle_event("test_off", _params, socket) do
    endpoint = get_configured_endpoint(socket)
    off_value = socket.assigns.off_value

    case send_test_value(socket.assigns.client, endpoint, off_value) do
      {:ok, _body} ->
        {:noreply, assign(socket, :test_state, {:off, DateTime.utc_now()})}

      {:error, _reason} ->
        {:noreply, assign(socket, :test_state, {:error, :off})}
    end
  end

  @impl true
  def handle_event("proceed_to_confirm", _params, socket) do
    {:noreply, assign(socket, :wizard_step, :confirming)}
  end

  @impl true
  def handle_event("back_to_testing", _params, socket) do
    {:noreply, assign(socket, :wizard_step, :testing)}
  end

  @impl true
  def handle_event("back_to_browsing", _params, socket) do
    socket =
      socket
      |> assign(:wizard_step, :browsing)
      |> assign(:detected_endpoints, nil)
      |> assign(:mapping_complete, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("confirm_configuration", _params, socket) do
    result =
      case socket.assigns.mode do
        :lever -> save_lever_configuration(socket)
        :button -> save_button_configuration(socket)
      end

    case result do
      {:ok, _config} ->
        send(self(), {:configuration_complete, socket.assigns.element.id, :ok})
        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, format_errors(changeset))}
    end
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    send(self(), {:configuration_cancelled, socket.assigns.element.id})
    {:noreply, socket}
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
                {if @mode == :lever, do: "Configure Lever", else: "Configure Button"}
              </h2>
              <p class="text-sm text-base-content/60">{@element.name}</p>
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
              label="Find in Simulator"
              active={@wizard_step == :browsing}
              completed={@wizard_step in [:testing, :confirming]}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              :if={@mode == :button}
              step={2}
              label="Test Values"
              active={@wizard_step == :testing}
              completed={@wizard_step == :confirming}
            />
            <div :if={@mode == :button} class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={if @mode == :button, do: 3, else: 2}
              label="Confirm"
              active={@wizard_step == :confirming}
              completed={false}
            />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :browsing} class="flex-1 flex flex-col">
            <.live_component
              module={TswIoWeb.ApiExplorerComponent}
              id="wizard-api-explorer"
              field={:endpoint}
              client={@client}
              mode={@mode}
            />
          </div>

          <div :if={@wizard_step == :testing and @mode == :button} class="flex-1 p-6">
            <.button_test_panel
              myself={@myself}
              detected_endpoints={@detected_endpoints}
              available_inputs={@available_inputs}
              selected_input_id={@selected_input_id}
              on_value={@on_value}
              off_value={@off_value}
              test_state={@test_state}
              mapping_complete={@mapping_complete}
            />
          </div>

          <div :if={@wizard_step == :confirming} class="flex-1 p-6">
            <.confirmation_panel
              myself={@myself}
              mode={@mode}
              element={@element}
              detected_endpoints={@detected_endpoints}
              manual_selections={@manual_selections}
              selected_input_id={@selected_input_id}
              available_inputs={@available_inputs}
              on_value={@on_value}
              off_value={@off_value}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Step indicator component
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

  # Button test panel component
  attr :myself, :any, required: true
  attr :detected_endpoints, :map, required: true
  attr :available_inputs, :list, required: true
  attr :selected_input_id, :integer, default: nil
  attr :on_value, :float, required: true
  attr :off_value, :float, required: true
  attr :test_state, :any, default: nil
  attr :mapping_complete, :boolean, required: true

  defp button_test_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="font-semibold mb-2">Selected Endpoint</h3>
        <div class="bg-base-200 rounded-lg p-3 font-mono text-sm">
          {@detected_endpoints[:endpoint]}
        </div>
      </div>

      <div>
        <h3 class="font-semibold mb-2">Select Hardware Input</h3>
        <div class="grid grid-cols-2 gap-2 max-h-48 overflow-y-auto">
          <label
            :for={input <- @available_inputs}
            class={[
              "flex items-center gap-2 p-3 rounded-lg border cursor-pointer transition-colors",
              @selected_input_id == input.id && "border-primary bg-primary/10",
              @selected_input_id != input.id && "border-base-300 hover:border-base-content/30"
            ]}
          >
            <input
              type="radio"
              name="input-id"
              value={input.id}
              checked={@selected_input_id == input.id}
              phx-click="select_input"
              phx-value-input-id={input.id}
              phx-target={@myself}
              class="radio radio-sm radio-primary"
            />
            <div>
              <div class="font-medium text-sm">{input.name || "Button #{input.pin}"}</div>
              <div class="text-xs text-base-content/60">
                {input.device.name} - Pin {input.pin}
              </div>
            </div>
          </label>
        </div>
        <p :if={@available_inputs == []} class="text-sm text-base-content/60 italic">
          No button inputs configured. Add button inputs in device settings first.
        </p>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="label">
            <span class="label-text font-medium">ON Value</span>
          </label>
          <input
            type="number"
            step="0.1"
            value={@on_value}
            phx-blur="update_on_value"
            phx-target={@myself}
            class="input input-bordered w-full"
          />
        </div>
        <div>
          <label class="label">
            <span class="label-text font-medium">OFF Value</span>
          </label>
          <input
            type="number"
            step="0.1"
            value={@off_value}
            phx-blur="update_off_value"
            phx-target={@myself}
            class="input input-bordered w-full"
          />
        </div>
      </div>

      <div>
        <h3 class="font-semibold mb-2">Test Connection</h3>
        <div class="flex items-center gap-3">
          <button
            type="button"
            phx-click="test_on"
            phx-target={@myself}
            class={[
              "btn btn-sm",
              test_button_class(@test_state, :on)
            ]}
          >
            <.icon name="hero-play" class="w-4 h-4" /> Test ON
          </button>
          <button
            type="button"
            phx-click="test_off"
            phx-target={@myself}
            class={[
              "btn btn-sm",
              test_button_class(@test_state, :off)
            ]}
          >
            <.icon name="hero-stop" class="w-4 h-4" /> Test OFF
          </button>
          <span :if={@test_state} class="text-sm text-base-content/60">
            {format_test_state(@test_state)}
          </span>
        </div>
      </div>

      <div class="flex justify-between pt-4 border-t border-base-300">
        <button
          type="button"
          phx-click="back_to_browsing"
          phx-target={@myself}
          class="btn btn-ghost"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </button>
        <button
          type="button"
          phx-click="proceed_to_confirm"
          phx-target={@myself}
          disabled={not @mapping_complete}
          class="btn btn-primary"
        >
          Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  # Confirmation panel component
  attr :myself, :any, required: true
  attr :mode, :atom, required: true
  attr :element, Element, required: true
  attr :detected_endpoints, :map, default: nil
  attr :manual_selections, :map, default: %{}
  attr :selected_input_id, :integer, default: nil
  attr :available_inputs, :list, default: []
  attr :on_value, :float, default: 1.0
  attr :off_value, :float, default: 0.0

  defp confirmation_panel(assigns) do
    selected_input = Enum.find(assigns.available_inputs, &(&1.id == assigns.selected_input_id))
    assigns = assign(assigns, :selected_input, selected_input)

    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-3 text-success">
        <.icon name="hero-check-circle" class="w-8 h-8" />
        <div>
          <h3 class="font-semibold text-lg">Ready to Save</h3>
          <p class="text-sm text-base-content/60">Review your configuration below</p>
        </div>
      </div>

      <div :if={@mode == :lever} class="space-y-3">
        <h4 class="font-medium">Lever Endpoints</h4>
        <div class="bg-base-200 rounded-lg p-4 space-y-2 font-mono text-sm">
          <div class="flex justify-between">
            <span class="text-base-content/60">Min Value:</span>
            <span>{get_endpoint(@detected_endpoints, @manual_selections, :min_endpoint)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">Max Value:</span>
            <span>{get_endpoint(@detected_endpoints, @manual_selections, :max_endpoint)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">Current Value:</span>
            <span>{get_endpoint(@detected_endpoints, @manual_selections, :value_endpoint)}</span>
          </div>
          <div
            :if={get_endpoint(@detected_endpoints, @manual_selections, :notch_count_endpoint)}
            class="flex justify-between"
          >
            <span class="text-base-content/60">Notch Count:</span>
            <span>
              {get_endpoint(@detected_endpoints, @manual_selections, :notch_count_endpoint)}
            </span>
          </div>
          <div
            :if={get_endpoint(@detected_endpoints, @manual_selections, :notch_index_endpoint)}
            class="flex justify-between"
          >
            <span class="text-base-content/60">Notch Index:</span>
            <span>
              {get_endpoint(@detected_endpoints, @manual_selections, :notch_index_endpoint)}
            </span>
          </div>
        </div>
      </div>

      <div :if={@mode == :button} class="space-y-3">
        <h4 class="font-medium">Button Configuration</h4>
        <div class="bg-base-200 rounded-lg p-4 space-y-2">
          <div class="flex justify-between">
            <span class="text-base-content/60">Endpoint:</span>
            <span class="font-mono text-sm">{@detected_endpoints[:endpoint]}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">Hardware Input:</span>
            <span :if={@selected_input}>
              {@selected_input.name || "Button #{@selected_input.pin}"} ({@selected_input.device.name})
            </span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">ON Value:</span>
            <span>{@on_value}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">OFF Value:</span>
            <span>{@off_value}</span>
          </div>
        </div>
      </div>

      <div class="flex justify-between pt-4 border-t border-base-300">
        <button
          type="button"
          phx-click={if @mode == :button, do: "back_to_testing", else: "back_to_browsing"}
          phx-target={@myself}
          class="btn btn-ghost"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
        </button>
        <button
          type="button"
          phx-click="confirm_configuration"
          phx-target={@myself}
          class="btn btn-primary"
        >
          <.icon name="hero-check" class="w-4 h-4" /> Save Configuration
        </button>
      </div>
    </div>
    """
  end

  # Helper functions

  defp check_mapping_complete(%{assigns: %{mode: :lever}} = socket) do
    manual = socket.assigns.manual_selections
    detected = socket.assigns.detected_endpoints

    required_fields = [:min_endpoint, :max_endpoint, :value_endpoint]

    has_all_required =
      if detected do
        Enum.all?(required_fields, &Map.get(detected, &1))
      else
        Enum.all?(required_fields, &Map.get(manual, &1))
      end

    assign(socket, :mapping_complete, has_all_required)
  end

  defp check_mapping_complete(%{assigns: %{mode: :button}} = socket) do
    has_endpoint = socket.assigns.detected_endpoints[:endpoint] != nil
    has_input = socket.assigns.selected_input_id != nil

    assign(socket, :mapping_complete, has_endpoint and has_input)
  end

  defp get_configured_endpoint(socket) do
    socket.assigns.detected_endpoints[:endpoint]
  end

  defp send_test_value(%Client{} = client, endpoint, value) when is_binary(endpoint) do
    Client.set(client, endpoint, value)
  end

  defp send_test_value(_client, _endpoint, _value), do: {:error, :invalid_endpoint}

  defp test_button_class({:on, _}, :on), do: "btn-success"
  defp test_button_class({:off, _}, :off), do: "btn-warning"
  defp test_button_class({:error, :on}, :on), do: "btn-error"
  defp test_button_class({:error, :off}, :off), do: "btn-error"
  defp test_button_class(_, _), do: "btn-outline"

  defp format_test_state({:on, _time}), do: "Sent ON value"
  defp format_test_state({:off, _time}), do: "Sent OFF value"
  defp format_test_state({:error, _}), do: "Test failed"
  defp format_test_state(_), do: ""

  defp get_endpoint(detected, manual, field) do
    Map.get(manual, field) || Map.get(detected || %{}, field)
  end

  defp save_lever_configuration(%{assigns: assigns}) do
    %{element: element, detected_endpoints: detected, manual_selections: manual} = assigns

    params =
      %{}
      |> maybe_put(:min_endpoint, get_endpoint(detected, manual, :min_endpoint))
      |> maybe_put(:max_endpoint, get_endpoint(detected, manual, :max_endpoint))
      |> maybe_put(:value_endpoint, get_endpoint(detected, manual, :value_endpoint))
      |> maybe_put(:notch_count_endpoint, get_endpoint(detected, manual, :notch_count_endpoint))
      |> maybe_put(:notch_index_endpoint, get_endpoint(detected, manual, :notch_index_endpoint))

    if element.lever_config do
      Train.update_lever_config(element.lever_config, params)
    else
      Train.create_lever_config(element.id, params)
    end
  end

  defp save_button_configuration(%{assigns: assigns}) do
    %{element: element, detected_endpoints: detected, selected_input_id: input_id} = assigns

    params = %{
      endpoint: detected[:endpoint],
      on_value: Float.round(assigns.on_value, 2),
      off_value: Float.round(assigns.off_value, 2)
    }

    case element.button_binding do
      nil ->
        Train.create_button_binding(element.id, input_id, params)

      existing ->
        Train.update_button_binding(existing, Map.put(params, :input_id, input_id))
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp format_errors(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_errors(_), do: "An error occurred"
end
