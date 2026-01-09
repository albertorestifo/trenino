defmodule TreninoWeb.EndpointSelectorComponent do
  @moduledoc """
  Shared component for selecting simulator endpoints.

  Used by both button bindings and sequence commands to provide a consistent
  endpoint selection experience with optional value detection.

  ## Usage

      <.live_component
        module={TreninoWeb.EndpointSelectorComponent}
        id="endpoint-selector"
        client={@simulator_client}
        mode={:button}
        include_value_detection={true}
        selected_endpoint={@endpoint}
        selected_value={@value}
      />

  ## Props

  - `client`: Simulator.Client - required for API calls
  - `mode`: :button | :sequence - affects detection behavior
  - `include_value_detection`: boolean - show value detection step
  - `selected_endpoint`: string | nil - current endpoint
  - `selected_value`: float | nil - current value (when include_value_detection)

  ## Events sent to parent

  - `{:completed, %{endpoint: endpoint, value: value}}` - endpoint and value selected (when include_value_detection)
  - `{:endpoint_selected, endpoint}` - endpoint selected (when NOT include_value_detection)
  - `:cancelled` - user cancelled selection
  """

  use TreninoWeb, :live_component

  alias Trenino.Simulator.Client

  @impl true
  def update(
        %{
          id: id,
          client: %Client{} = client,
          mode: mode,
          include_value_detection: include_value_detection
        } = assigns,
        socket
      ) do
    socket =
      socket
      |> assign(:id, id)
      |> assign(:client, client)
      |> assign(:mode, mode)
      |> assign(:include_value_detection, include_value_detection)
      |> assign(:selected_endpoint, Map.get(assigns, :selected_endpoint))
      |> assign(:selected_value, Map.get(assigns, :selected_value))

    # Initialize on first mount
    socket =
      if socket.assigns[:initialized] do
        socket
      else
        initialize_selector(socket)
      end

    # Handle forwarded API explorer events from parent
    socket = handle_explorer_event(assigns, socket)

    {:ok, socket}
  end

  def update(%{value_polling_result: value}, socket) do
    # Handle polled endpoint value from parent for value detection
    {:ok, process_polled_value(socket, value)}
  end

  def update(assigns, socket) do
    # Handle forwarded API explorer events from parent
    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  # Handle API explorer events forwarded from parent via assigns
  defp handle_explorer_event(%{explorer_event: {:auto_detect_result, change}}, socket) do
    # Auto-detect completed - use the detected endpoint
    endpoint = change.endpoint

    socket =
      socket
      |> assign(:selected_endpoint, endpoint)
      |> assign(:show_auto_detect, false)
      |> assign(:explorer_event, nil)

    # If value detection is enabled, move to step 2, otherwise notify parent
    if socket.assigns.include_value_detection do
      # Auto-detected value becomes the initial detected value
      detected_value = Float.round(change.current_value * 1.0, 2)

      socket
      |> assign(:current_step, :configure_value)
      |> assign(:detected_value, detected_value)
    else
      notify_parent(socket, {:endpoint_selected, endpoint})
      socket
    end
  end

  defp handle_explorer_event(%{explorer_event: :auto_detect_cancelled}, socket) do
    socket
    |> assign(:show_auto_detect, false)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: {:select, _field, path}}, socket) do
    # Endpoint was manually selected from the browser
    socket =
      socket
      |> assign(:selected_endpoint, path)
      |> assign(:explorer_event, nil)

    # If value detection is enabled, move to step 2, otherwise notify parent
    if socket.assigns.include_value_detection do
      assign(socket, :current_step, :configure_value)
    else
      notify_parent(socket, {:endpoint_selected, path})
      socket
    end
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    notify_parent(socket, :cancelled)
    assign(socket, :explorer_event, nil)
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  defp initialize_selector(socket) do
    socket
    |> assign(:current_step, :select_endpoint)
    |> assign(:show_auto_detect, false)
    |> assign(:value_config_mode, :auto)
    |> assign(:value_detection_status, :idle)
    |> assign(:detected_value, nil)
    |> assign(:manual_value, socket.assigns[:selected_value])
    |> assign(:initialized, true)
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
  def handle_event("back_to_endpoint", _params, socket) do
    {:noreply, assign(socket, :current_step, :select_endpoint)}
  end

  @impl true
  def handle_event("set_value_config_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :value_config_mode, String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("start_value_detection", _params, socket) do
    endpoint = socket.assigns.selected_endpoint
    send(self(), {:start_value_polling, endpoint})

    {:noreply,
     socket
     |> assign(:value_detection_status, :waiting)
     |> assign(:detected_value, nil)}
  end

  @impl true
  def handle_event("cancel_value_detection", _params, socket) do
    send(self(), :stop_value_polling)
    {:noreply, assign(socket, :value_detection_status, :idle)}
  end

  @impl true
  def handle_event("confirm_detected_value", _params, socket) do
    send(self(), :stop_value_polling)

    value = socket.assigns.detected_value
    notify_parent(socket, {:value_detected, value})

    {:noreply,
     socket
     |> assign(:value_detection_status, :idle)
     |> assign(:selected_value, value)}
  end

  @impl true
  def handle_event("retry_value_detection", _params, socket) do
    endpoint = socket.assigns.selected_endpoint
    send(self(), {:start_value_polling, endpoint})

    {:noreply,
     socket
     |> assign(:value_detection_status, :waiting)
     |> assign(:detected_value, nil)}
  end

  @impl true
  def handle_event("update_manual_value", %{"value" => value_str}, socket) do
    case Float.parse(value_str) do
      {value, _} ->
        rounded_value = Float.round(value, 2)

        {:noreply,
         socket
         |> assign(:manual_value, rounded_value)
         |> assign(:selected_value, rounded_value)}

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("confirm_selection", _params, socket) do
    # Final confirmation - send combined event to avoid race condition
    endpoint = socket.assigns.selected_endpoint

    if socket.assigns.include_value_detection do
      value = socket.assigns.selected_value || socket.assigns.manual_value
      notify_parent(socket, {:completed, %{endpoint: endpoint, value: value}})
    else
      notify_parent(socket, {:endpoint_selected, endpoint})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    notify_parent(socket, :cancelled)
    {:noreply, socket}
  end

  # Process polled endpoint value for value detection
  defp process_polled_value(%{assigns: %{value_detection_status: :waiting}} = socket, value) do
    rounded_value = Float.round(value * 1.0, 2)

    # For sequence commands, we just capture the current value
    # For buttons, ConfigurationWizardComponent handles ON/OFF detection
    send(self(), :stop_value_polling)

    socket
    |> assign(:detected_value, rounded_value)
    |> assign(:value_detection_status, :detected)
  end

  defp process_polled_value(socket, _value), do: socket

  # Send notification to parent LiveView
  defp notify_parent(socket, event) do
    send(self(), {:endpoint_selector, socket.assigns.id, event})
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
              <h2 class="text-lg font-semibold">Select Endpoint</h2>
              <p :if={@selected_endpoint} class="text-sm text-base-content/60 font-mono">
                {@selected_endpoint}
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

          <div :if={@include_value_detection} class="flex items-center gap-2 mt-4">
            <.step_indicator
              step={1}
              label="Select Endpoint"
              active={@current_step == :select_endpoint}
              completed={@current_step == :configure_value}
            />
            <div class="flex-1 h-px bg-base-300" />
            <.step_indicator
              step={2}
              label="Configure Value"
              active={@current_step == :configure_value}
              completed={false}
            />
          </div>
        </div>

        <div class="flex-1 overflow-hidden flex">
          <div
            :if={@current_step == :select_endpoint && !@show_auto_detect}
            class="flex-1 flex flex-col"
          >
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
              module={TreninoWeb.ApiExplorerComponent}
              id="endpoint-selector-api-explorer"
              field={:endpoint}
              client={@client}
              mode={@mode}
              embedded={true}
            />
          </div>

          <.live_component
            :if={@current_step == :select_endpoint && @show_auto_detect}
            module={TreninoWeb.AutoDetectComponent}
            id="endpoint-selector-auto-detect"
            client={@client}
          />

          <div :if={@current_step == :configure_value} class="flex-1 p-6 overflow-y-auto">
            <.value_config_panel
              myself={@myself}
              selected_endpoint={@selected_endpoint}
              value_config_mode={@value_config_mode}
              value_detection_status={@value_detection_status}
              detected_value={@detected_value}
              manual_value={@manual_value}
              selected_value={@selected_value}
            />
          </div>
        </div>

        <div :if={@current_step == :configure_value} class="p-4 border-t border-base-300">
          <div class="flex justify-between">
            <button
              type="button"
              phx-click="back_to_endpoint"
              phx-target={@myself}
              class="btn btn-ghost"
            >
              <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
            </button>
            <button
              type="button"
              phx-click="confirm_selection"
              phx-target={@myself}
              disabled={is_nil(@selected_value) && is_nil(@manual_value)}
              class="btn btn-primary"
            >
              <.icon name="hero-check" class="w-4 h-4" /> Confirm
            </button>
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

  # Value configuration panel component
  attr :myself, :any, required: true
  attr :selected_endpoint, :string, required: true
  attr :value_config_mode, :atom, required: true
  attr :value_detection_status, :atom, required: true
  attr :detected_value, :float, default: nil
  attr :manual_value, :float, default: nil
  attr :selected_value, :float, default: nil

  defp value_config_panel(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="font-semibold mb-2">Selected Endpoint</h3>
        <div class="bg-base-200 rounded-lg p-3 font-mono text-sm">
          {@selected_endpoint}
        </div>
      </div>

      <div>
        <div class="flex items-center justify-between mb-3">
          <h3 class="font-semibold">Configure Value</h3>
          <div class="flex items-center gap-2">
            <span class={[
              "text-xs",
              @value_config_mode == :auto && "text-primary font-medium"
            ]}>
              Auto-Detect
            </span>
            <input
              type="checkbox"
              class="toggle toggle-sm"
              checked={@value_config_mode == :manual}
              phx-click="set_value_config_mode"
              phx-value-mode={if @value_config_mode == :manual, do: "auto", else: "manual"}
              phx-target={@myself}
            />
            <span class={["text-xs", @value_config_mode == :manual && "font-medium"]}>
              Manual
            </span>
          </div>
        </div>

        <div :if={@value_config_mode == :manual} class="space-y-4">
          <div>
            <label class="label"><span class="label-text">Value</span></label>
            <input
              type="number"
              name="value"
              step="0.01"
              value={@manual_value}
              phx-change="update_manual_value"
              phx-target={@myself}
              class="input input-bordered w-full"
              placeholder="Enter value..."
            />
            <p class="text-xs text-base-content/60 mt-1">
              Enter the exact value to use for this endpoint
            </p>
          </div>
        </div>

        <div :if={@value_config_mode == :auto}>
          <div :if={@value_detection_status == :idle} class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between">
              <div>
                <p class="font-medium">Detect Value</p>
                <p class="text-xs text-base-content/60">
                  Interact with the control in the simulator to detect its value
                </p>
              </div>
              <button
                type="button"
                phx-click="start_value_detection"
                phx-target={@myself}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-play" class="w-4 h-4" /> Start Detection
              </button>
            </div>
          </div>

          <div
            :if={@value_detection_status == :waiting}
            class="bg-primary/10 border border-primary rounded-lg p-4"
          >
            <div class="flex items-center gap-3 mb-3">
              <span class="loading loading-dots loading-md text-primary"></span>
              <div>
                <p class="font-medium text-primary">Detecting value...</p>
                <p class="text-xs text-base-content/60">
                  Interact with the control in the simulator
                </p>
              </div>
            </div>

            <button
              type="button"
              phx-click="cancel_value_detection"
              phx-target={@myself}
              class="btn btn-ghost btn-xs"
            >
              Cancel
            </button>
          </div>

          <div
            :if={@value_detection_status == :detected}
            class="bg-success/10 border border-success rounded-lg p-4"
          >
            <div class="flex items-center gap-2 mb-3">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
              <p class="font-medium text-success">Value Detected</p>
            </div>

            <div class="bg-base-100 rounded p-3 text-center mb-4">
              <p class="text-xs text-base-content/60">Detected Value</p>
              <p class="font-mono text-2xl">{@detected_value}</p>
            </div>

            <div class="flex gap-2 justify-end">
              <button
                type="button"
                phx-click="retry_value_detection"
                phx-target={@myself}
                class="btn btn-ghost btn-sm"
              >
                Retry
              </button>
              <button
                type="button"
                phx-click="confirm_detected_value"
                phx-target={@myself}
                class="btn btn-success btn-sm"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Confirm
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
