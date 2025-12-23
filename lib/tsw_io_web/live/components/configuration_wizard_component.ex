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

  require Logger

  alias TswIo.Simulator.Client
  alias TswIo.Simulator.LeverAnalyzer
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

  defp initialize_wizard(socket, element, mode) do
    train_id = get_train_id(element)
    sequences = if train_id, do: Train.list_sequences(train_id), else: []

    socket
    |> assign(:wizard_step, :browsing)
    |> assign(:detected_endpoints, nil)
    |> assign(:manual_selections, %{})
    |> assign(:mapping_complete, false)
    |> assign(:test_state, nil)
    |> assign(:selected_input_id, get_existing_input_id(element, mode))
    |> assign(:on_value, get_existing_on_value(element, mode))
    |> assign(:off_value, get_existing_off_value(element, mode))
    |> assign(:binding_mode, get_existing_binding_mode(element, mode))
    |> assign(:hardware_type, get_existing_hardware_type(element, mode))
    |> assign(:repeat_interval_ms, get_existing_repeat_interval(element, mode))
    |> assign(:sequences, sequences)
    |> assign(:on_sequence_id, get_existing_on_sequence_id(element, mode))
    |> assign(:off_sequence_id, get_existing_off_sequence_id(element, mode))
    |> assign(:show_explorer, true)
    |> assign(:individual_selection_mode, false)
    |> assign(:show_auto_detect, false)
    |> assign(:calibrating, false)
    |> assign(:calibration_error, nil)
    |> assign(:detecting_button, false)
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

  defp get_existing_binding_mode(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.mode
  end

  defp get_existing_binding_mode(_element, _mode), do: :simple

  defp get_existing_hardware_type(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.hardware_type
  end

  defp get_existing_hardware_type(_element, _mode), do: :momentary

  defp get_existing_repeat_interval(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.repeat_interval_ms
  end

  defp get_existing_repeat_interval(_element, _mode), do: 100

  defp get_existing_on_sequence_id(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.on_sequence_id
  end

  defp get_existing_on_sequence_id(_element, _mode), do: nil

  defp get_existing_off_sequence_id(%Element{button_binding: binding}, :button)
       when not is_nil(binding) do
    binding.off_sequence_id
  end

  defp get_existing_off_sequence_id(_element, _mode), do: nil

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
  def handle_event("update_binding_mode", %{"value" => mode_str}, socket) do
    mode = String.to_existing_atom(mode_str)
    {:noreply, assign(socket, :binding_mode, mode)}
  end

  @impl true
  def handle_event("update_hardware_type", %{"value" => type_str}, socket) do
    type = String.to_existing_atom(type_str)
    {:noreply, assign(socket, :hardware_type, type)}
  end

  @impl true
  def handle_event("update_repeat_interval", %{"value" => value_str}, socket) do
    case Integer.parse(value_str) do
      {value, _} when value > 0 and value <= 5000 ->
        {:noreply, assign(socket, :repeat_interval_ms, value)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_on_sequence", %{"value" => value_str}, socket) do
    sequence_id =
      case Integer.parse(value_str) do
        {id, _} -> id
        :error -> nil
      end

    socket =
      socket
      |> assign(:on_sequence_id, sequence_id)
      |> check_mapping_complete()

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_off_sequence", %{"value" => value_str}, socket) do
    sequence_id =
      case Integer.parse(value_str) do
        {id, _} -> id
        :error -> nil
      end

    {:noreply, assign(socket, :off_sequence_id, sequence_id)}
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
    case socket.assigns.mode do
      :lever ->
        # For levers, go to calibration step
        {:noreply, assign(socket, :wizard_step, :calibrating)}

      :button ->
        # For buttons, save directly
        case save_button_configuration(socket) do
          {:ok, _config} ->
            send(self(), {:configuration_complete, socket.assigns.element.id, :ok})
            {:noreply, socket}

          {:error, changeset} ->
            {:noreply, put_flash(socket, :error, format_errors(changeset))}
        end
    end
  end

  @impl true
  def handle_event("start_calibration", _params, socket) do
    # Start calibration - run synchronously but with UI feedback
    socket = assign(socket, :calibrating, true)

    # Run calibration and save
    result = save_lever_configuration(socket)

    case result do
      {:ok, _config} ->
        send(self(), {:configuration_complete, socket.assigns.element.id, :ok})
        {:noreply, socket}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:calibrating, false)
         |> assign(:calibration_error, format_calibration_error(reason))}
    end
  end

  @impl true
  def handle_event("back_to_confirm", _params, socket) do
    {:noreply,
     socket
     |> assign(:wizard_step, :confirming)
     |> assign(:calibrating, false)
     |> assign(:calibration_error, nil)}
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
              completed={@wizard_step in [:testing, :confirming, :calibrating]}
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
              label={if @mode == :lever, do: "Review", else: "Confirm"}
              active={@wizard_step == :confirming}
              completed={@wizard_step == :calibrating}
            />
            <div :if={@mode == :lever} class="flex-1 h-px bg-base-300" />
            <.step_indicator
              :if={@mode == :lever}
              step={3}
              label="Calibrate"
              active={@wizard_step == :calibrating}
              completed={false}
            />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div :if={@wizard_step == :browsing && !@show_auto_detect} class="flex-1 flex flex-col">
            <div :if={@mode == :button} class="p-4 border-b border-base-300 bg-base-200/50">
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
              mode={@mode}
              embedded={true}
            />
          </div>

          <.live_component
            :if={@wizard_step == :browsing && @show_auto_detect}
            module={TswIoWeb.AutoDetectComponent}
            id="wizard-auto-detect"
            client={@client}
          />

          <div :if={@wizard_step == :testing && @mode == :button} class="flex-1 p-6 overflow-y-auto">
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

          <div :if={@wizard_step == :confirming} class="flex-1 p-6 overflow-y-auto">
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
              binding_mode={@binding_mode}
              hardware_type={@hardware_type}
              repeat_interval_ms={@repeat_interval_ms}
              sequences={@sequences}
              on_sequence_id={@on_sequence_id}
              off_sequence_id={@off_sequence_id}
            />
          </div>

          <div :if={@wizard_step == :calibrating} class="flex-1 p-6 overflow-y-auto">
            <.calibration_panel
              myself={@myself}
              calibrating={@calibrating}
              calibration_error={@calibration_error}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Calibration panel component for levers
  attr :myself, :any, required: true
  attr :calibrating, :boolean, required: true
  attr :calibration_error, :string, default: nil

  defp calibration_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div :if={!@calibrating && is_nil(@calibration_error)} class="space-y-4">
        <div class="flex items-center gap-3 text-warning">
          <.icon name="hero-exclamation-triangle" class="w-8 h-8" />
          <div>
            <h3 class="font-semibold text-lg">Prepare for Calibration</h3>
            <p class="text-sm text-base-content/60">The lever will be moved automatically</p>
          </div>
        </div>

        <div class="bg-base-200 rounded-lg p-4 space-y-3">
          <p class="text-sm">
            Before starting calibration, please ensure:
          </p>
          <ul class="text-sm space-y-2 ml-4">
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>The train is stationary and brakes are applied</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>The lever can move freely through its full range</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>No safety systems will be triggered by lever movement</span>
            </li>
          </ul>
          <p class="text-sm text-base-content/60 mt-3">
            The calibration will sweep the lever from minimum to maximum to detect its behavior
            and create the appropriate notch configuration.
          </p>
        </div>

        <div class="flex justify-between pt-4 border-t border-base-300">
          <button
            type="button"
            phx-click="back_to_confirm"
            phx-target={@myself}
            class="btn btn-ghost"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
          </button>
          <button
            type="button"
            phx-click="start_calibration"
            phx-target={@myself}
            class="btn btn-primary"
          >
            <.icon name="hero-play" class="w-4 h-4" /> Start Calibration
          </button>
        </div>
      </div>

      <div :if={@calibrating} class="flex flex-col items-center justify-center py-12 space-y-4">
        <span class="loading loading-spinner loading-lg text-primary"></span>
        <div class="text-center">
          <h3 class="font-semibold text-lg">Calibrating Lever</h3>
          <p class="text-sm text-base-content/60">
            Moving lever through its range to detect behavior...
          </p>
          <p class="text-xs text-base-content/40 mt-2">
            This may take 10-15 seconds
          </p>
        </div>
      </div>

      <div :if={@calibration_error} class="space-y-4">
        <div class="flex items-center gap-3 text-error">
          <.icon name="hero-exclamation-circle" class="w-8 h-8" />
          <div>
            <h3 class="font-semibold text-lg">Calibration Failed</h3>
            <p class="text-sm text-base-content/60">{@calibration_error}</p>
          </div>
        </div>

        <div class="flex justify-between pt-4 border-t border-base-300">
          <button
            type="button"
            phx-click="back_to_confirm"
            phx-target={@myself}
            class="btn btn-ghost"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
          </button>
          <button
            type="button"
            phx-click="start_calibration"
            phx-target={@myself}
            class="btn btn-primary"
          >
            <.icon name="hero-arrow-path" class="w-4 h-4" /> Retry
          </button>
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

        <div :if={@available_inputs != [] && !@detecting_button && is_nil(@selected_input)} class="bg-base-200 rounded-lg p-4">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm text-base-content/70">No button selected</p>
              <p class="text-xs text-base-content/50">Press "Detect" and then press a button on your device</p>
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

        <div :if={@selected_input != nil && !@detecting_button} class="bg-success/10 border border-success rounded-lg p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center gap-3">
              <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
              <div>
                <p class="font-medium">{@selected_input.name || "Button #{@selected_input.pin}"}</p>
                <p class="text-xs text-base-content/60">{@selected_input.device.name} - Pin {@selected_input.pin}</p>
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

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="label">
            <span class="label-text font-medium">Button Mode</span>
          </label>
          <select
            phx-change="update_binding_mode"
            phx-target={@myself}
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
            phx-change="update_hardware_type"
            phx-target={@myself}
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

      <div :if={@binding_mode == :momentary} class="bg-base-200/50 rounded-lg p-4">
        <label class="label">
          <span class="label-text font-medium">Repeat Interval (ms)</span>
        </label>
        <input
          type="number"
          min="10"
          max="5000"
          step="10"
          value={@repeat_interval_ms}
          phx-blur="update_repeat_interval"
          phx-target={@myself}
          class="input input-bordered w-full"
        />
        <p class="text-xs text-base-content/50 mt-1">
          How often to repeat the ON value while button is held (10-5000ms)
        </p>
      </div>

      <div :if={@binding_mode == :sequence} class="bg-base-200/50 rounded-lg p-4 space-y-4">
        <div>
          <label class="label">
            <span class="label-text font-medium">Press Sequence</span>
          </label>
          <select
            phx-change="update_on_sequence"
            phx-target={@myself}
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
            phx-change="update_off_sequence"
            phx-target={@myself}
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

      <div :if={@binding_mode != :sequence} class="grid grid-cols-2 gap-4">
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
  attr :binding_mode, :atom, default: :simple
  attr :hardware_type, :atom, default: :momentary
  attr :repeat_interval_ms, :integer, default: 100
  attr :sequences, :list, default: []
  attr :on_sequence_id, :integer, default: nil
  attr :off_sequence_id, :integer, default: nil

  defp confirmation_panel(assigns) do
    selected_input = Enum.find(assigns.available_inputs, &(&1.id == assigns.selected_input_id))
    on_sequence = Enum.find(assigns.sequences, &(&1.id == assigns.on_sequence_id))
    off_sequence = Enum.find(assigns.sequences, &(&1.id == assigns.off_sequence_id))

    assigns =
      assigns
      |> assign(:selected_input, selected_input)
      |> assign(:on_sequence, on_sequence)
      |> assign(:off_sequence, off_sequence)

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
          <div :if={@binding_mode != :sequence} class="flex justify-between">
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
            <span class="text-base-content/60">Button Mode:</span>
            <span>{format_binding_mode(@binding_mode)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-base-content/60">Hardware Type:</span>
            <span>{format_hardware_type(@hardware_type)}</span>
          </div>
          <div :if={@binding_mode == :momentary} class="flex justify-between">
            <span class="text-base-content/60">Repeat Interval:</span>
            <span>{@repeat_interval_ms}ms</span>
          </div>
          <div :if={@binding_mode == :sequence} class="flex justify-between">
            <span class="text-base-content/60">Press Sequence:</span>
            <span :if={@on_sequence}>{@on_sequence.name}</span>
            <span :if={!@on_sequence} class="text-error">Not selected</span>
          </div>
          <div
            :if={@binding_mode == :sequence && @hardware_type == :latching}
            class="flex justify-between"
          >
            <span class="text-base-content/60">Release Sequence:</span>
            <span :if={@off_sequence}>{@off_sequence.name}</span>
            <span :if={!@off_sequence} class="text-base-content/50">None</span>
          </div>
          <div :if={@binding_mode != :sequence} class="flex justify-between">
            <span class="text-base-content/60">ON Value:</span>
            <span>{@on_value}</span>
          </div>
          <div :if={@binding_mode != :sequence} class="flex justify-between">
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

  defp format_binding_mode(:simple), do: "Simple"
  defp format_binding_mode(:momentary), do: "Momentary (repeat while held)"
  defp format_binding_mode(:sequence), do: "Sequence"

  defp format_hardware_type(:momentary), do: "Momentary (spring-loaded)"
  defp format_hardware_type(:latching), do: "Latching (toggle switch)"

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

  defp check_mapping_complete(%{assigns: %{mode: :button, binding_mode: :sequence}} = socket) do
    has_input = socket.assigns.selected_input_id != nil
    has_sequence = socket.assigns.on_sequence_id != nil

    assign(socket, :mapping_complete, has_input and has_sequence)
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
    %{element: element, detected_endpoints: detected, manual_selections: manual, client: client} =
      assigns

    # Get the control path (node path) from detected endpoints
    # The node_path is stored during detection, or we derive it from value_endpoint
    value_endpoint = get_endpoint(detected, manual, :value_endpoint)
    control_path = derive_control_path(detected, value_endpoint)

    params =
      %{}
      |> maybe_put(:min_endpoint, get_endpoint(detected, manual, :min_endpoint))
      |> maybe_put(:max_endpoint, get_endpoint(detected, manual, :max_endpoint))
      |> maybe_put(:value_endpoint, value_endpoint)
      |> maybe_put(:notch_count_endpoint, get_endpoint(detected, manual, :notch_count_endpoint))
      |> maybe_put(:notch_index_endpoint, get_endpoint(detected, manual, :notch_index_endpoint))

    # Run lever analysis to detect true behavior
    case run_lever_analysis(client, control_path) do
      {:ok, analysis_result} ->
        Logger.info(
          "[ConfigWizard] Lever analysis complete: type=#{analysis_result.lever_type}, " <>
            "notches=#{length(analysis_result.suggested_notches)}"
        )

        # Save with analysis results
        if element.lever_config do
          Train.update_lever_config_with_analysis(element.lever_config, params, analysis_result)
        else
          Train.create_lever_config_with_analysis(element.id, params, analysis_result)
        end

      {:error, reason} ->
        Logger.warning(
          "[ConfigWizard] Lever analysis failed: #{inspect(reason)}, saving without analysis"
        )

        # Fallback to saving without analysis
        if element.lever_config do
          Train.update_lever_config(element.lever_config, params)
        else
          Train.create_lever_config(element.id, params)
        end
    end
  end

  # Derive the control path from detected endpoints or value_endpoint
  defp derive_control_path(%{node_path: node_path}, _value_endpoint) when is_binary(node_path) do
    node_path
  end

  defp derive_control_path(_detected, value_endpoint) when is_binary(value_endpoint) do
    # Value endpoint is like "CurrentDrivableActor/MasterController.InputValue"
    # Extract the control path by removing the ".InputValue" suffix
    case String.split(value_endpoint, ".") do
      [path | _rest] -> path
      _ -> value_endpoint
    end
  end

  defp derive_control_path(_detected, _value_endpoint), do: nil

  # Run lever analysis with error handling
  defp run_lever_analysis(nil, _control_path), do: {:error, :no_client}
  defp run_lever_analysis(_client, nil), do: {:error, :no_control_path}

  defp run_lever_analysis(%Client{} = client, control_path) do
    Logger.info("[ConfigWizard] Running lever analysis on #{control_path}...")

    # Run analysis with a restore position at the neutral point (0.5)
    LeverAnalyzer.analyze(client, control_path, restore_position: 0.5)
  end

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

  defp format_calibration_error(:no_client), do: "Simulator not connected"
  defp format_calibration_error(:no_control_path), do: "Could not determine control path"
  defp format_calibration_error(:insufficient_samples), do: "Could not collect enough samples"
  defp format_calibration_error({:http_error, code, msg}), do: "Simulator error: #{code} - #{msg}"
  defp format_calibration_error(%Ecto.Changeset{} = cs), do: format_errors(cs)
  defp format_calibration_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_calibration_error(reason), do: inspect(reason)
end
