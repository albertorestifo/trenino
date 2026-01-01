defmodule TswIoWeb.ConfigurationWizardComponent do
  @moduledoc """
  Configuration wizard for button elements.

  Uses API explorer as the primary interface with auto-detection as default.
  Flow:
  1. Browse API tree in explorer
  2. Auto-detect or manually select endpoints
  3. Select hardware input and configure button behavior
  4. Test connection and save

  ## Usage

      <.live_component
        module={TswIoWeb.ConfigurationWizardComponent}
        id="config-wizard"
        mode={:button}
        element={@element}
        client={@simulator_client}
        available_inputs={@available_inputs}
      />

  ## Events sent to parent

  - `{:configuration_complete, element_id, result}` - When configuration is saved
  - `{:configuration_cancelled, element_id}` - When user cancels
  """

  use TswIoWeb, :live_component

  require Logger

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

  def update(%{button_detected_input_id: input_id}, socket) do
    # Button was detected by parent - select it
    socket =
      socket
      |> assign(:selected_input_id, input_id)
      |> assign(:detecting_button, false)
      |> check_mapping_complete()

    {:ok, socket}
  end

  def update(assigns, socket) do
    # Handle forwarded API explorer events from parent
    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  # Get train_id from the element's train association
  defp get_train_id(%Element{train_id: train_id}) when is_integer(train_id), do: train_id
  defp get_train_id(_), do: nil

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

  defp handle_explorer_event(%{explorer_event: {:auto_detect_result, change}}, socket) do
    # Auto-detect completed - use the detected endpoint
    on_value = change[:current_value] || socket.assigns.on_value
    off_value = change[:previous_value] || socket.assigns.off_value

    socket
    |> assign(:detected_endpoints, %{endpoint: change.endpoint})
    |> assign(:on_value, Float.round(on_value, 2))
    |> assign(:off_value, Float.round(off_value, 2))
    |> assign(:show_auto_detect, false)
    |> assign(:wizard_step, :testing)
    |> check_mapping_complete()
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :auto_detect_cancelled}, socket) do
    socket
    |> assign(:show_auto_detect, false)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_wizard(socket, element, _mode) do
    train_id = get_train_id(element)
    sequences = if train_id, do: Train.list_sequences(train_id), else: []

    # Check if we have an existing complete binding (for edit mode)
    {initial_step, detected_endpoints, mapping_complete} = get_initial_wizard_state(element)

    socket
    |> assign(:wizard_step, initial_step)
    |> assign(:detected_endpoints, detected_endpoints)
    |> assign(:manual_selections, %{})
    |> assign(:mapping_complete, mapping_complete)
    |> assign(:test_state, nil)
    |> assign(:selected_input_id, get_existing_input_id(element))
    |> assign(:on_value, get_existing_on_value(element))
    |> assign(:off_value, get_existing_off_value(element))
    |> assign(:binding_mode, get_existing_binding_mode(element))
    |> assign(:hardware_type, get_existing_hardware_type(element))
    |> assign(:repeat_interval_ms, get_existing_repeat_interval(element))
    |> assign(:sequences, sequences)
    |> assign(:on_sequence_id, get_existing_on_sequence_id(element))
    |> assign(:off_sequence_id, get_existing_off_sequence_id(element))
    |> assign(:show_explorer, true)
    |> assign(:individual_selection_mode, false)
    |> assign(:show_auto_detect, false)
    |> assign(:detecting_button, false)
    |> assign(:initialized, true)
  end

  # For buttons with existing complete bindings, skip to configure step
  defp get_initial_wizard_state(%Element{button_binding: binding})
       when not is_nil(binding) and not is_nil(binding.input_id) do
    # Check if binding is complete (has endpoint for simple/momentary, or sequence for sequence mode)
    is_complete =
      case binding.mode do
        :sequence -> not is_nil(binding.on_sequence_id)
        _ -> not is_nil(binding.endpoint)
      end

    if is_complete do
      # Skip to configure page with existing endpoint
      detected_endpoints =
        if binding.endpoint, do: %{endpoint: binding.endpoint}, else: %{}

      {:testing, detected_endpoints, true}
    else
      {:browsing, nil, false}
    end
  end

  # Default: start at browsing step
  defp get_initial_wizard_state(_element) do
    {:browsing, nil, false}
  end

  defp get_existing_input_id(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.input_id
  end

  defp get_existing_input_id(_element), do: nil

  defp get_existing_on_value(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.on_value
  end

  defp get_existing_on_value(_element), do: 1.0

  defp get_existing_off_value(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.off_value
  end

  defp get_existing_off_value(_element), do: 0.0

  defp get_existing_binding_mode(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.mode
  end

  defp get_existing_binding_mode(_element), do: :simple

  defp get_existing_hardware_type(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.hardware_type
  end

  defp get_existing_hardware_type(_element), do: :momentary

  defp get_existing_repeat_interval(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.repeat_interval_ms
  end

  defp get_existing_repeat_interval(_element), do: 100

  defp get_existing_on_sequence_id(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.on_sequence_id
  end

  defp get_existing_on_sequence_id(_element), do: nil

  defp get_existing_off_sequence_id(%Element{button_binding: binding})
       when not is_nil(binding) do
    binding.off_sequence_id
  end

  defp get_existing_off_sequence_id(_element), do: nil

  @impl true
  def handle_event("select_input", %{"input-id" => input_id_str}, socket) do
    input_id = String.to_integer(input_id_str)

    socket =
      socket
      |> assign(:selected_input_id, input_id)
      |> assign(:detecting_button, false)
      |> check_mapping_complete()

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_button_detection", _params, socket) do
    # Tell parent to start listening for button presses
    send(self(), {:start_button_detection, socket.assigns.available_inputs})
    {:noreply, assign(socket, :detecting_button, true)}
  end

  @impl true
  def handle_event("cancel_button_detection", _params, socket) do
    send(self(), :stop_button_detection)
    {:noreply, assign(socket, :detecting_button, false)}
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
  def handle_event("update_button_fields", params, socket) do
    Logger.info("[ConfigWizard] update_button_fields: #{inspect(params)}")

    socket =
      socket
      |> maybe_update_binding_mode(params)
      |> maybe_update_hardware_type(params)
      |> maybe_update_on_sequence(params)
      |> maybe_update_off_sequence(params)
      |> maybe_update_on_value(params)
      |> maybe_update_off_value(params)
      |> check_mapping_complete()

    {:noreply, socket}
  end

  @impl true
  def handle_event("open_auto_detect", _params, socket) do
    {:noreply, assign(socket, :show_auto_detect, true)}
  end

  @impl true
  def handle_event("close_auto_detect", _params, socket) do
    {:noreply, assign(socket, :show_auto_detect, false)}
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
  def handle_event("back_to_browsing", _params, socket) do
    socket =
      socket
      |> assign(:wizard_step, :browsing)
      |> assign(:detected_endpoints, nil)
      |> assign(:mapping_complete, false)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_button_config", _params, socket) do
    case save_button_configuration(socket) do
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

  # Private helpers for update_button_fields
  defp maybe_update_binding_mode(socket, %{"binding_mode" => mode_str}) do
    mode = String.to_existing_atom(mode_str)
    Logger.info("[ConfigWizard] Setting binding_mode to: #{inspect(mode)}")
    assign(socket, :binding_mode, mode)
  end

  defp maybe_update_binding_mode(socket, _params), do: socket

  defp maybe_update_hardware_type(socket, %{"hardware_type" => type_str}) do
    type = String.to_existing_atom(type_str)
    assign(socket, :hardware_type, type)
  end

  defp maybe_update_hardware_type(socket, _params), do: socket

  defp maybe_update_on_sequence(socket, %{"on_sequence_id" => value_str}) do
    sequence_id =
      case Integer.parse(value_str) do
        {id, _} -> id
        :error -> nil
      end

    assign(socket, :on_sequence_id, sequence_id)
  end

  defp maybe_update_on_sequence(socket, _params), do: socket

  defp maybe_update_off_sequence(socket, %{"off_sequence_id" => value_str}) do
    sequence_id =
      case Integer.parse(value_str) do
        {id, _} -> id
        :error -> nil
      end

    assign(socket, :off_sequence_id, sequence_id)
  end

  defp maybe_update_off_sequence(socket, _params), do: socket

  defp maybe_update_on_value(socket, %{"on_value" => value_str}) do
    case Float.parse(value_str) do
      {value, _} -> assign(socket, :on_value, Float.round(value, 2))
      :error -> socket
    end
  end

  defp maybe_update_on_value(socket, _params), do: socket

  defp maybe_update_off_value(socket, %{"off_value" => value_str}) do
    case Float.parse(value_str) do
      {value, _} -> assign(socket, :off_value, Float.round(value, 2))
      :error -> socket
    end
  end

  defp maybe_update_off_value(socket, _params), do: socket

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">Configure Button</h2>
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
              completed={@wizard_step == :testing}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={2}
              label="Configure"
              active={@wizard_step == :testing}
              completed={false}
            />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :browsing && !@show_auto_detect} class="flex-1 flex flex-col">
            <div class="p-4 border-b border-base-300 bg-base-200/50">
              <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                  <.icon name="hero-sparkles" class="w-5 h-5 text-primary" />
                  <span class="font-medium">Quick Setup</span>
                </div>
                <button
                  type="button"
                  phx-click="open_auto_detect"
                  phx-target={@myself}
                  class="btn btn-primary btn-sm"
                >
                  <.icon name="hero-cursor-arrow-rays" class="w-4 h-4" /> Auto-Detect Control
                </button>
              </div>
              <p class="text-xs text-base-content/60 mt-1">
                Interact with a control in the simulator to automatically detect it, or browse below
              </p>
            </div>
            <.live_component
              module={TswIoWeb.ApiExplorerComponent}
              id="wizard-api-explorer"
              field={:endpoint}
              client={@client}
              mode={:button}
              embedded={true}
            />
          </div>

          <.live_component
            :if={@wizard_step == :browsing && @show_auto_detect}
            module={TswIoWeb.AutoDetectComponent}
            id="wizard-auto-detect"
            client={@client}
          />

          <div :if={@wizard_step == :testing} class="flex-1 p-6 overflow-y-auto">
            <.button_test_panel
              myself={@myself}
              detected_endpoints={@detected_endpoints}
              available_inputs={@available_inputs}
              selected_input_id={@selected_input_id}
              on_value={@on_value}
              off_value={@off_value}
              binding_mode={@binding_mode}
              hardware_type={@hardware_type}
              repeat_interval_ms={@repeat_interval_ms}
              sequences={@sequences}
              on_sequence_id={@on_sequence_id}
              off_sequence_id={@off_sequence_id}
              test_state={@test_state}
              mapping_complete={@mapping_complete}
              detecting_button={@detecting_button}
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
  attr :binding_mode, :atom, required: true
  attr :hardware_type, :atom, required: true
  attr :repeat_interval_ms, :integer, required: true
  attr :sequences, :list, default: []
  attr :on_sequence_id, :integer, default: nil
  attr :off_sequence_id, :integer, default: nil
  attr :test_state, :any, default: nil
  attr :mapping_complete, :boolean, required: true
  attr :detecting_button, :boolean, default: false

  defp button_test_panel(assigns) do
    selected_input = Enum.find(assigns.available_inputs, &(&1.id == assigns.selected_input_id))
    assigns = assign(assigns, :selected_input, selected_input)

    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="font-semibold mb-2">Selected Endpoint</h3>
        <div class="bg-base-200 rounded-lg p-3 font-mono text-sm">
          {@detected_endpoints[:endpoint]}
        </div>
      </div>

      <div>
        <h3 class="font-semibold mb-2">Hardware Input</h3>

        <div :if={@available_inputs == []} class="bg-base-200 rounded-lg p-4">
          <p class="text-sm text-base-content/60 italic">
            No button inputs configured. Add button inputs in device settings first.
          </p>
        </div>

        <div
          :if={@available_inputs != [] && !@detecting_button && is_nil(@selected_input)}
          class="bg-base-200 rounded-lg p-4"
        >
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-base-content/70">No button selected</p>
              <p class="text-xs text-base-content/50">
                Press "Detect" and then press a button on your device
              </p>
            </div>
            <button
              type="button"
              phx-click="start_button_detection"
              phx-target={@myself}
              class="btn btn-primary btn-sm"
            >
              <.icon name="hero-hand-raised" class="w-4 h-4" /> Detect
            </button>
          </div>
        </div>

        <div :if={@detecting_button} class="bg-primary/10 border border-primary rounded-lg p-4">
          <div class="flex items-center gap-3">
            <span class="loading loading-dots loading-md text-primary"></span>
            <div>
              <p class="font-medium text-primary">Waiting for button press...</p>
              <p class="text-xs text-base-content/60">Press a button on your hardware device</p>
            </div>
          </div>
          <button
            type="button"
            phx-click="cancel_button_detection"
            phx-target={@myself}
            class="btn btn-ghost btn-xs mt-2"
          >
            Cancel
          </button>
        </div>

        <div
          :if={@selected_input != nil && !@detecting_button}
          class="bg-success/10 border border-success rounded-lg p-4"
        >
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
              <div>
                <p class="font-medium">{@selected_input.name || "Button #{@selected_input.pin}"}</p>
                <p class="text-xs text-base-content/60">
                  {@selected_input.device.name} - Pin {@selected_input.pin}
                </p>
              </div>
            </div>
            <button
              type="button"
              phx-click="start_button_detection"
              phx-target={@myself}
              class="btn btn-ghost btn-sm"
            >
              Change
            </button>
          </div>
        </div>
      </div>

      <form phx-change="update_button_fields" phx-target={@myself}>
        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="label">
              <span class="label-text font-medium">Button Mode</span>
            </label>
            <select
              name="binding_mode"
              class="select select-bordered w-full"
            >
              <option value="simple" selected={@binding_mode == :simple}>
                Simple (send once)
              </option>
              <option value="momentary" selected={@binding_mode == :momentary}>
                Momentary (repeat while held)
              </option>
              <option value="sequence" selected={@binding_mode == :sequence}>
                Sequence (execute commands)
              </option>
            </select>
            <p class="text-xs text-base-content/50 mt-1">
              {mode_description(@binding_mode)}
            </p>
          </div>
          <div>
            <label class="label">
              <span class="label-text font-medium">Hardware Type</span>
            </label>
            <select
              name="hardware_type"
              class="select select-bordered w-full"
            >
              <option value="momentary" selected={@hardware_type == :momentary}>
                Momentary (spring-loaded)
              </option>
              <option value="latching" selected={@hardware_type == :latching}>
                Latching (toggle switch)
              </option>
            </select>
            <p class="text-xs text-base-content/50 mt-1">
              {hardware_type_description(@hardware_type)}
            </p>
          </div>
        </div>

        <div :if={@binding_mode == :sequence} class="bg-base-200/50 rounded-lg p-4 space-y-4 mt-4">
          <div>
            <label class="label">
              <span class="label-text font-medium">Press Sequence</span>
            </label>
            <select
              name="on_sequence_id"
              class="select select-bordered w-full"
            >
              <option value="" selected={@on_sequence_id == nil}>Select a sequence...</option>
              <option
                :for={seq <- @sequences}
                value={seq.id}
                selected={@on_sequence_id == seq.id}
              >
                {seq.name} ({length(seq.commands)} commands)
              </option>
            </select>
            <p class="text-xs text-base-content/50 mt-1">
              Sequence to execute when button is pressed
            </p>
          </div>

          <div :if={@hardware_type == :latching}>
            <label class="label">
              <span class="label-text font-medium">Release Sequence (optional)</span>
            </label>
            <select
              name="off_sequence_id"
              class="select select-bordered w-full"
            >
              <option value="" selected={@off_sequence_id == nil}>None</option>
              <option
                :for={seq <- @sequences}
                value={seq.id}
                selected={@off_sequence_id == seq.id}
              >
                {seq.name} ({length(seq.commands)} commands)
              </option>
            </select>
            <p class="text-xs text-base-content/50 mt-1">
              Sequence to execute when toggle is turned off (latching hardware only)
            </p>
          </div>

          <div :if={Enum.empty?(@sequences)} class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
            <div>
              <span>No sequences defined.</span>
              <a
                href="#sequences"
                phx-click="cancel"
                phx-target={@myself}
                class="link link-primary ml-1"
              >
                Create one in the Sequences section
              </a>
            </div>
          </div>
        </div>

        <div :if={@binding_mode != :sequence} class="grid grid-cols-2 gap-4 mt-4">
          <div>
            <label class="label">
              <span class="label-text font-medium">ON Value</span>
            </label>
            <input
              type="number"
              name="on_value"
              step="0.1"
              value={@on_value}
              class="input input-bordered w-full"
            />
          </div>
          <div>
            <label class="label">
              <span class="label-text font-medium">OFF Value</span>
            </label>
            <input
              type="number"
              name="off_value"
              step="0.1"
              value={@off_value}
              class="input input-bordered w-full"
            />
          </div>
        </div>
      </form>

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
          phx-click="save_button_config"
          phx-target={@myself}
          disabled={not @mapping_complete}
          class="btn btn-primary"
        >
          <.icon name="hero-check" class="w-4 h-4" /> Save
        </button>
      </div>
    </div>
    """
  end

  defp mode_description(:simple),
    do: "Sends ON when pressed, OFF when released. Use for: lights, doors, switches"

  defp mode_description(:momentary),
    do: "Repeats ON value while held. Use for: horn, bell, announcements"

  defp mode_description(:sequence),
    do: "Executes a command sequence. Use for: startup procedures, multi-step operations"

  defp hardware_type_description(:momentary),
    do: "Button returns when released (like a keyboard key or doorbell)"

  defp hardware_type_description(:latching),
    do: "Toggle switch that stays in position (like a light switch)"

  # Helper functions

  defp check_mapping_complete(%{assigns: %{binding_mode: :sequence}} = socket) do
    has_input = socket.assigns.selected_input_id != nil
    has_sequence = socket.assigns.on_sequence_id != nil

    assign(socket, :mapping_complete, has_input and has_sequence)
  end

  defp check_mapping_complete(socket) do
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

  defp save_button_configuration(%{assigns: assigns}) do
    %{element: element, detected_endpoints: detected, selected_input_id: input_id} = assigns

    # For sequence mode, endpoint is nil (sequences define their own endpoints)
    endpoint =
      if assigns.binding_mode == :sequence do
        nil
      else
        detected[:endpoint]
      end

    params = %{
      endpoint: endpoint,
      on_value: Float.round(assigns.on_value, 2),
      off_value: Float.round(assigns.off_value, 2),
      mode: assigns.binding_mode,
      hardware_type: assigns.hardware_type,
      repeat_interval_ms: assigns.repeat_interval_ms,
      on_sequence_id: assigns.on_sequence_id,
      off_sequence_id: assigns.off_sequence_id
    }

    Logger.info("[ConfigWizard] Saving button config: #{inspect(params)}")

    result =
      case element.button_binding do
        nil ->
          Train.create_button_binding(element.id, input_id, params)

        existing ->
          Train.update_button_binding(existing, Map.put(params, :input_id, input_id))
      end

    Logger.info("[ConfigWizard] Save result: #{inspect(result)}")
    result
  end

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
