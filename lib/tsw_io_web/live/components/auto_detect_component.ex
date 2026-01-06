defmodule TswIoWeb.AutoDetectComponent do
  @moduledoc """
  Live component for auto-detecting simulator controls.

  Provides a UI for:
  - Starting detection session
  - Showing listening state with countdown
  - Displaying detected controls
  - Selecting from multiple detected controls

  ## Usage

      <.live_component
        module={TswIoWeb.AutoDetectComponent}
        id="auto-detect"
        client={@simulator_client}
        on_select={fn endpoint -> ... end}
        on_cancel={fn -> ... end}
      />

  ## Events

  Sends these messages to the parent LiveView:
  - `{:auto_detect_selected, %{endpoint: ..., control_name: ...}}`
  - `{:auto_detect_cancelled}`
  """

  use TswIoWeb, :live_component

  alias TswIo.Simulator.ControlDetectionSession

  @impl true
  def mount(socket) do
    {:ok,
     assign(socket,
       status: :idle,
       session_pid: nil,
       detected_changes: [],
       selected_index: 0,
       timeout_remaining: 30,
       error_message: nil
     )}
  end

  @impl true
  def update(%{detection_result: {:detected, changes}}, socket) do
    # Received detection results from parent
    {:ok,
     assign(socket,
       status: :detected,
       detected_changes: changes,
       selected_index: 0
     )}
  end

  def update(%{detection_result: :timeout}, socket) do
    {:ok, assign(socket, status: :timeout)}
  end

  def update(%{detection_result: {:error, reason}}, socket) do
    {:ok,
     assign(socket,
       status: :error,
       error_message: format_error(reason)
     )}
  end

  def update(%{countdown_tick: remaining}, socket) do
    {:ok, assign(socket, timeout_remaining: remaining)}
  end

  def update(%{session_started: {:ok, pid}}, socket) do
    # Session started successfully, now listening
    {:ok,
     assign(socket,
       status: :listening,
       session_pid: pid
     )}
  end

  def update(%{session_started: {:error, reason}}, socket) do
    {:ok,
     assign(socket,
       status: :error,
       error_message: format_error(reason)
     )}
  end

  def update(assigns, socket) do
    socket =
      socket
      |> assign(:client, assigns.client)
      |> assign(:id, assigns.id)

    {:ok, socket}
  end

  @impl true
  def handle_event("start_detection", _params, socket) do
    # Show loading state immediately, start session async
    component_id = socket.assigns.id
    client = socket.assigns.client
    send(self(), {:start_detection_session, component_id, client})

    {:noreply,
     assign(socket,
       status: :starting,
       timeout_remaining: 30,
       error_message: nil
     )}
  end

  def handle_event("cancel", _params, socket) do
    if socket.assigns.session_pid && Process.alive?(socket.assigns.session_pid) do
      ControlDetectionSession.stop(socket.assigns.session_pid)
    end

    send(self(), {:auto_detect_cancelled})
    {:noreply, assign(socket, status: :idle, session_pid: nil)}
  end

  def handle_event("select_control", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    {:noreply, assign(socket, selected_index: index)}
  end

  def handle_event("use_selected", _params, socket) do
    selected = Enum.at(socket.assigns.detected_changes, socket.assigns.selected_index)
    send(self(), {:auto_detect_selected, selected})
    {:noreply, assign(socket, status: :idle, session_pid: nil)}
  end

  def handle_event("detect_another", _params, socket) do
    # Reset and start again
    handle_event("start_detection", %{}, assign(socket, status: :idle, detected_changes: []))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md">
        <div class="p-4 border-b border-base-300">
          <div class="flex items-center justify-between">
            <h2 class="text-lg font-semibold">Auto-Detect Control</h2>
            <button
              type="button"
              phx-click="cancel"
              phx-target={@myself}
              class="btn btn-ghost btn-sm btn-circle"
            >
              <.icon name="hero-x-mark" class="w-5 h-5" />
            </button>
          </div>
        </div>

        <div class="p-6">
          <.idle_state :if={@status == :idle} myself={@myself} />
          <.starting_state :if={@status == :starting} />
          <.listening_state :if={@status == :listening} timeout_remaining={@timeout_remaining} />
          <.detected_state
            :if={@status == :detected}
            myself={@myself}
            detected_changes={@detected_changes}
            selected_index={@selected_index}
          />
          <.timeout_state :if={@status == :timeout} myself={@myself} />
          <.error_state :if={@status == :error} myself={@myself} error_message={@error_message} />
        </div>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true

  defp idle_state(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="text-5xl">
        <.icon name="hero-cursor-arrow-rays" class="w-16 h-16 mx-auto text-primary" />
      </div>
      <div>
        <h3 class="font-semibold text-lg">Ready to Detect</h3>
        <p class="text-sm text-base-content/60 mt-1">
          Click start, then interact with a control in the simulator
        </p>
      </div>
      <button type="button" phx-click="start_detection" phx-target={@myself} class="btn btn-primary">
        <.icon name="hero-play" class="w-4 h-4" /> Start Detection
      </button>
    </div>
    """
  end

  defp starting_state(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="relative">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>
      <div>
        <h3 class="font-semibold text-lg">Setting Up...</h3>
        <p class="text-sm text-base-content/60 mt-1">
          Discovering controls in the simulator
        </p>
      </div>
    </div>
    """
  end

  attr :timeout_remaining, :integer, required: true

  defp listening_state(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="relative">
        <span class="loading loading-ring loading-lg text-primary"></span>
      </div>
      <div>
        <h3 class="font-semibold text-lg">Listening...</h3>
        <p class="text-sm text-base-content/60 mt-1">
          Interact with a control in Train Sim World
        </p>
        <p class="text-sm text-base-content/60">
          Press a button, move a lever, or flip a switch
        </p>
      </div>
      <div class="text-xs text-base-content/40">
        Timeout in: {@timeout_remaining}s
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :detected_changes, :list, required: true
  attr :selected_index, :integer, required: true

  defp detected_state(assigns) do
    single_change = length(assigns.detected_changes) == 1
    assigns = assign(assigns, :single_change, single_change)

    ~H"""
    <div class="space-y-4">
      <div class="flex items-center gap-3 text-success">
        <.icon name="hero-check-circle" class="w-8 h-8" />
        <div>
          <h3 class="font-semibold text-lg">
            {if @single_change, do: "Control Detected!", else: "Multiple Controls Detected"}
          </h3>
          <p :if={not @single_change} class="text-sm text-base-content/60">
            Select the control you want to use
          </p>
        </div>
      </div>

      <div class="space-y-2">
        <label
          :for={{change, index} <- Enum.with_index(@detected_changes)}
          class={[
            "flex items-start gap-3 p-3 rounded-lg border cursor-pointer transition-colors",
            @selected_index == index && "border-primary bg-primary/10",
            @selected_index != index && "border-base-300 hover:border-base-content/30"
          ]}
        >
          <input
            :if={not @single_change}
            type="radio"
            name="selected-control"
            checked={@selected_index == index}
            phx-click="select_control"
            phx-value-index={index}
            phx-target={@myself}
            class="radio radio-sm radio-primary mt-1"
          />
          <div class="flex-1">
            <div class="font-medium">{change.control_name}</div>
            <div class="text-xs text-base-content/60 font-mono">{change.endpoint}</div>
            <div class="text-xs text-base-content/50 mt-1">
              Value changed: {Float.round(change.previous_value * 1.0, 2)} -> {Float.round(
                change.current_value * 1.0,
                2
              )}
            </div>
          </div>
        </label>
      </div>

      <div class="flex justify-between pt-4">
        <button
          type="button"
          phx-click="detect_another"
          phx-target={@myself}
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-arrow-path" class="w-4 h-4" /> Detect Another
        </button>
        <button type="button" phx-click="use_selected" phx-target={@myself} class="btn btn-primary">
          <.icon name="hero-check" class="w-4 h-4" /> Use This Control
        </button>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true

  defp timeout_state(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="text-5xl">
        <.icon name="hero-clock" class="w-16 h-16 mx-auto text-warning" />
      </div>
      <div>
        <h3 class="font-semibold text-lg">Detection Timed Out</h3>
        <p class="text-sm text-base-content/60 mt-1">
          No control changes were detected within 30 seconds
        </p>
        <p class="text-sm text-base-content/60">
          Make sure you're in the cab of the active train
        </p>
      </div>
      <div class="flex justify-center gap-2">
        <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
          Cancel
        </button>
        <button type="button" phx-click="detect_another" phx-target={@myself} class="btn btn-primary">
          <.icon name="hero-arrow-path" class="w-4 h-4" /> Try Again
        </button>
      </div>
    </div>
    """
  end

  attr :myself, :any, required: true
  attr :error_message, :string, required: true

  defp error_state(assigns) do
    ~H"""
    <div class="text-center space-y-4">
      <div class="text-5xl">
        <.icon name="hero-exclamation-triangle" class="w-16 h-16 mx-auto text-error" />
      </div>
      <div>
        <h3 class="font-semibold text-lg">Detection Failed</h3>
        <p class="text-sm text-base-content/60 mt-1">
          {@error_message}
        </p>
      </div>
      <div class="flex justify-center gap-2">
        <button type="button" phx-click="cancel" phx-target={@myself} class="btn btn-ghost">
          Cancel
        </button>
        <button type="button" phx-click="detect_another" phx-target={@myself} class="btn btn-primary">
          <.icon name="hero-arrow-path" class="w-4 h-4" /> Try Again
        </button>
      </div>
    </div>
    """
  end

  # Private functions

  defp format_error(:no_client), do: "Simulator not connected"
  defp format_error({:list_failed, _}), do: "Failed to query simulator controls"
  defp format_error(:no_subscriptions_created), do: "No controls found to monitor"
  defp format_error(reason), do: "Error: #{inspect(reason)}"
end
