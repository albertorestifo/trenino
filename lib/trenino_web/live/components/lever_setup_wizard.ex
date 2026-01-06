defmodule TreninoWeb.LeverSetupWizard do
  @moduledoc """
  Unified wizard for setting up train lever elements.

  Guides users through the complete lever configuration flow:
  1. Select calibrated hardware lever
  2. Find simulator endpoint (via API explorer or auto-detect)
  3. Explain auto-calibration requirements
  4. Run auto-calibration to detect notches (using LeverAnalyzer)
  5. Map notch positions to hardware ranges (with visual wobble capture)
  6. Test the mapping with live position feedback

  ## Usage

      <.live_component
        module={TreninoWeb.LeverSetupWizard}
        id="lever-setup-wizard"
        element={@element}
        client={@simulator_client}
      />

  ## Events sent to parent

  - `{:lever_setup_complete, element_id}` - When setup is complete
  - `{:lever_setup_cancelled, element_id}` - When user cancels
  """

  use TreninoWeb, :live_component

  alias Trenino.Hardware
  alias Trenino.Train
  alias Trenino.Train.Calibration.NotchMappingSession
  alias Trenino.Train.Element

  # Steps for new lever setup (includes explanation step)
  @steps_new [
    :select_input,
    :find_endpoint,
    :explain_calibration,
    :run_calibration,
    :map_notches
  ]

  # Steps for editing existing lever (skips explanation step)
  @steps_edit [
    :select_input,
    :find_endpoint,
    :run_calibration,
    :map_notches
  ]

  @impl true
  def mount(socket) do
    {:ok, assign(socket, :initialized, false)}
  end

  @impl true
  def update(%{element: %Element{} = element} = assigns, socket) do
    socket =
      socket
      |> assign(:element, element)
      |> assign(:client, assigns.client)

    # Initialize on first mount
    socket =
      if socket.assigns.initialized do
        socket
      else
        initialize_wizard(socket, element)
      end

    # Handle forwarded events from parent
    socket = handle_explorer_event(assigns, socket)

    {:ok, socket}
  end

  def update(%{mapping_state_update: state}, socket) do
    # Forward mapping state updates from parent
    {:ok, assign(socket, :mapping_state, state)}
  end

  def update(%{calibration_result: result}, socket) do
    # Handle calibration result from parent
    {:ok, apply_calibration_result(socket, result)}
  end

  def update(assigns, socket) do
    socket = handle_explorer_event(assigns, socket)
    {:ok, socket}
  end

  # Initialize wizard state
  defp initialize_wizard(socket, %Element{} = element) do
    # Get all calibrated analog inputs
    available_inputs =
      Hardware.list_all_inputs()
      |> Enum.filter(&(&1.input_type == :analog))

    # Check for existing lever config
    existing_config = element.lever_config
    existing_binding = get_existing_input_binding(existing_config)
    existing_input_id = get_existing_input_id(existing_binding)
    existing_endpoints = get_existing_endpoints(existing_config)

    # Determine if we're in editing mode (existing config allows non-linear navigation)
    editing_mode = has_existing_config?(existing_config)
    steps = if editing_mode, do: @steps_edit, else: @steps_new

    socket
    |> assign(:current_step, :select_input)
    |> assign(:available_inputs, available_inputs)
    |> assign(:selected_input_id, existing_input_id)
    |> assign(:selected_input, get_existing_input(existing_binding, available_inputs))
    |> assign(:detected_endpoints, existing_endpoints)
    |> assign(:show_auto_detect, false)
    |> assign(:calibration_status, :idle)
    |> assign(:calibration_progress, 0.0)
    |> assign(:calibration_error, nil)
    |> assign(:lever_type, get_existing_lever_type(existing_config))
    |> assign(:notches, get_existing_notches(existing_config))
    |> assign(:mapping_session_pid, nil)
    |> assign(:mapping_state, nil)
    # Edit mode tracking
    |> assign(:editing_mode, editing_mode)
    |> assign(:steps, steps)
    |> assign(:original_input_id, existing_input_id)
    |> assign(:original_endpoints, existing_endpoints)
    |> assign(:needs_redo, MapSet.new())
    |> assign(:steps_configured, compute_configured_steps(existing_config, existing_input_id))
    |> assign(:initialized, true)
  end

  defp get_existing_lever_type(nil), do: nil
  defp get_existing_lever_type(%{lever_type: lever_type}), do: lever_type

  defp get_existing_input_binding(nil), do: nil
  defp get_existing_input_binding(%{input_binding: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_existing_input_binding(%{input_binding: binding}), do: binding

  defp get_existing_input_id(nil), do: nil
  defp get_existing_input_id(%{input_id: id}), do: id

  defp get_existing_input(nil, _), do: nil
  defp get_existing_input(%{input_id: id}, inputs), do: Enum.find(inputs, &(&1.id == id))

  defp get_existing_endpoints(nil), do: nil

  defp get_existing_endpoints(config) do
    if config.value_endpoint do
      %{
        min_endpoint: config.min_endpoint,
        max_endpoint: config.max_endpoint,
        value_endpoint: config.value_endpoint,
        notch_count_endpoint: config.notch_count_endpoint,
        notch_index_endpoint: config.notch_index_endpoint
      }
    else
      nil
    end
  end

  defp get_existing_notches(nil), do: []
  defp get_existing_notches(%{notches: %Ecto.Association.NotLoaded{}}), do: []
  defp get_existing_notches(%{notches: notches}) when is_list(notches), do: notches
  defp get_existing_notches(_), do: []

  # Check if lever has an existing configuration (editing mode)
  # Edit mode is enabled when the lever has been at least partially configured
  # (endpoints set OR calibration done), allowing non-linear navigation
  defp has_existing_config?(nil), do: false
  defp has_existing_config?(%Ecto.Association.NotLoaded{}), do: false

  defp has_existing_config?(config) do
    # Consider it "existing" if either:
    # - Endpoints have been configured (value_endpoint set), OR
    # - Calibration has been done (lever_type set)
    config.value_endpoint != nil or config.lever_type != nil
  end

  # Compute which steps are already configured when entering edit mode
  defp compute_configured_steps(nil, _input_id), do: MapSet.new()
  defp compute_configured_steps(%Ecto.Association.NotLoaded{}, _input_id), do: MapSet.new()

  defp compute_configured_steps(config, input_id) do
    steps = MapSet.new()

    # Step 1: select_input - configured if we have an input bound
    steps = if input_id != nil, do: MapSet.put(steps, :select_input), else: steps

    # Step 2: find_endpoint - configured if we have value_endpoint
    steps = if config.value_endpoint != nil, do: MapSet.put(steps, :find_endpoint), else: steps

    # Step 3: explain_calibration - always configured (it's informational)
    steps = MapSet.put(steps, :explain_calibration)

    # Step 4: run_calibration - configured if lever_type is set
    steps = if config.lever_type != nil, do: MapSet.put(steps, :run_calibration), else: steps

    # Step 5: map_notches - configured if notches have input ranges
    steps =
      if has_mapped_notches?(config.notches), do: MapSet.put(steps, :map_notches), else: steps

    steps
  end

  defp has_mapped_notches?(%Ecto.Association.NotLoaded{}), do: false
  defp has_mapped_notches?(nil), do: false
  defp has_mapped_notches?([]), do: false

  defp has_mapped_notches?(notches) when is_list(notches) do
    Enum.all?(notches, fn n -> n.input_min != nil and n.input_max != nil end)
  end

  # Check if navigation to a step is allowed
  # Can navigate to a step if no earlier step needs redo (can't skip over steps that need work)
  defp can_navigate_to?(assigns, target_step) do
    steps = assigns.steps
    needs_redo = assigns.needs_redo
    target_idx = Enum.find_index(steps, &(&1 == target_step))

    if target_idx do
      steps
      |> Enum.take(target_idx)
      |> Enum.all?(fn step -> not MapSet.member?(needs_redo, step) end)
    else
      false
    end
  end

  # Handle forwarded events from parent
  defp handle_explorer_event(%{explorer_event: {:auto_configure, endpoints}}, socket) do
    socket
    |> assign(:detected_endpoints, endpoints)
    |> maybe_invalidate_for_endpoint_change(endpoints)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: {:select, field, path}}, socket) do
    endpoints = socket.assigns.detected_endpoints || %{}
    updated_endpoints = Map.put(endpoints, field, path)

    socket
    |> assign(:detected_endpoints, updated_endpoints)
    |> maybe_invalidate_for_endpoint_change(updated_endpoints)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: {:auto_detect_result, _change}}, socket) do
    socket
    |> assign(:show_auto_detect, false)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :auto_detect_cancelled}, socket) do
    socket
    |> assign(:show_auto_detect, false)
    |> assign(:explorer_event, nil)
  end

  defp handle_explorer_event(%{explorer_event: :close}, socket) do
    send(self(), {:lever_setup_cancelled, socket.assigns.element.id})
    assign(socket, :explorer_event, nil)
  end

  defp handle_explorer_event(_assigns, socket), do: socket

  # Invalidate downstream steps when endpoints change
  defp maybe_invalidate_for_endpoint_change(socket, new_endpoints) do
    if socket.assigns.editing_mode and
         endpoints_changed?(socket.assigns.original_endpoints, new_endpoints) do
      socket
      |> update(:needs_redo, &MapSet.put(&1, :run_calibration))
      |> update(:needs_redo, &MapSet.put(&1, :map_notches))
    else
      # If reverting back to original endpoints, clear the invalidations
      if socket.assigns.editing_mode and
           not endpoints_changed?(socket.assigns.original_endpoints, new_endpoints) do
        socket
        |> update(:needs_redo, &MapSet.delete(&1, :run_calibration))
        |> update(:needs_redo, &MapSet.delete(&1, :map_notches))
      else
        socket
      end
    end
  end

  defp endpoints_changed?(nil, _new), do: true
  defp endpoints_changed?(_old, nil), do: true

  defp endpoints_changed?(old, new) do
    old[:min_endpoint] != new[:min_endpoint] or
      old[:max_endpoint] != new[:max_endpoint] or
      old[:value_endpoint] != new[:value_endpoint]
  end

  # Event handlers

  @impl true
  def handle_event("select_input", %{"input-id" => input_id_str}, socket) do
    input_id = String.to_integer(input_id_str)
    selected_input = Enum.find(socket.assigns.available_inputs, &(&1.id == input_id))

    # In edit mode, if input changed from original, invalidate mapping step
    socket =
      if socket.assigns.editing_mode and input_id != socket.assigns.original_input_id do
        update(socket, :needs_redo, &MapSet.put(&1, :map_notches))
      else
        # If reverting back to original input, clear the invalidation
        if socket.assigns.editing_mode and input_id == socket.assigns.original_input_id do
          update(socket, :needs_redo, &MapSet.delete(&1, :map_notches))
        else
          socket
        end
      end

    {:noreply,
     socket
     |> assign(:selected_input_id, input_id)
     |> assign(:selected_input, selected_input)}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    current_step = socket.assigns.current_step
    steps = socket.assigns.steps
    next_step = get_next_step(current_step, steps)

    socket =
      case next_step do
        :run_calibration ->
          # Set running state and request parent to run calibration
          request_calibration(socket)

        :map_notches ->
          start_notch_mapping(socket)

        _ ->
          socket
      end

    {:noreply, assign(socket, :current_step, next_step)}
  end

  @impl true
  def handle_event("prev_step", _params, socket) do
    current_step = socket.assigns.current_step
    steps = socket.assigns.steps
    prev_step = get_prev_step(current_step, steps)

    socket =
      case current_step do
        :map_notches ->
          stop_notch_mapping(socket)

        _ ->
          socket
      end

    {:noreply, assign(socket, :current_step, prev_step)}
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
  def handle_event("skip_calibration", _params, socket) do
    # Skip to map_notches step, user will add notches manually
    {:noreply, assign(socket, :current_step, :map_notches)}
  end

  @impl true
  def handle_event("go_to_step", %{"step" => step_name}, socket) do
    step = String.to_existing_atom(step_name)

    if socket.assigns.editing_mode and can_navigate_to?(socket.assigns, step) do
      socket =
        socket
        |> maybe_stop_mapping_session_if_leaving()
        |> assign(:current_step, step)
        |> maybe_start_step_resources(step)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_capturing", _params, socket) do
    if socket.assigns.mapping_session_pid do
      NotchMappingSession.start_capturing(socket.assigns.mapping_session_pid)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_capturing", _params, socket) do
    if socket.assigns.mapping_session_pid do
      NotchMappingSession.stop_capturing(socket.assigns.mapping_session_pid)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("capture_range", _params, socket) do
    if socket.assigns.mapping_session_pid do
      case NotchMappingSession.capture_range(socket.assigns.mapping_session_pid) do
        :ok ->
          {:noreply, socket}

        {:error, :no_samples} ->
          {:noreply, put_flash(socket, :error, "No samples collected. Move the lever first.")}

        {:error, :no_range_detected} ->
          {:noreply, put_flash(socket, :error, "No range detected. Move the lever.")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Capture failed: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("reset_samples", _params, socket) do
    if socket.assigns.mapping_session_pid do
      NotchMappingSession.reset_samples(socket.assigns.mapping_session_pid)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("go_to_notch", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    if socket.assigns.mapping_session_pid do
      NotchMappingSession.go_to_notch(socket.assigns.mapping_session_pid, index)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_and_finish", _params, socket) do
    if socket.assigns.mapping_session_pid do
      case NotchMappingSession.save_mapping(socket.assigns.mapping_session_pid) do
        :ok ->
          # Save succeeded, close the wizard
          send(self(), {:lever_setup_complete, socket.assigns.element.id})
          {:noreply, socket}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Save failed: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("finish", _params, socket) do
    send(self(), {:lever_setup_complete, socket.assigns.element.id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    stop_notch_mapping(socket)
    send(self(), {:lever_setup_cancelled, socket.assigns.element.id})
    {:noreply, socket}
  end

  # Note: NotchMappingSession events are forwarded from parent LiveView via assigns
  # since LiveComponents don't support handle_info

  # Private helpers

  # Stop mapping session if leaving :map_notches step
  defp maybe_stop_mapping_session_if_leaving(socket) do
    if socket.assigns.current_step == :map_notches do
      stop_notch_mapping(socket)
    else
      socket
    end
  end

  # Start resources needed for a step when navigating to it
  defp maybe_start_step_resources(socket, :run_calibration) do
    # When navigating to calibration step, start calibration
    request_calibration(socket)
  end

  defp maybe_start_step_resources(socket, :map_notches) do
    # When navigating to mapping step, start the mapping session
    start_notch_mapping(socket)
  end

  defp maybe_start_step_resources(socket, _step), do: socket

  defp get_next_step(current, steps) do
    current_index = Enum.find_index(steps, &(&1 == current))
    Enum.at(steps, current_index + 1, current)
  end

  defp get_prev_step(current, steps) do
    current_index = Enum.find_index(steps, &(&1 == current))
    Enum.at(steps, max(current_index - 1, 0), current)
  end

  defp request_calibration(socket) do
    element = socket.assigns.element
    endpoints = socket.assigns.detected_endpoints

    # Get the control path from detected endpoints
    value_endpoint = endpoints[:value_endpoint]
    control_path = derive_control_path(endpoints, value_endpoint)

    config_params = %{
      min_endpoint: endpoints[:min_endpoint],
      max_endpoint: endpoints[:max_endpoint],
      value_endpoint: value_endpoint,
      notch_count_endpoint: endpoints[:notch_count_endpoint],
      notch_index_endpoint: endpoints[:notch_index_endpoint]
    }

    # Send message to parent to run calibration asynchronously
    send(self(), {:run_lever_calibration, element.id, control_path, config_params})

    # Set running state immediately so UI shows loading spinner
    assign(socket, :calibration_status, :running)
  end

  defp apply_calibration_result(socket, {:ok, updated_config}) do
    config_with_notches = Trenino.Repo.preload(updated_config, :notches)

    socket
    |> assign(:calibration_status, :complete)
    |> assign(:notches, config_with_notches.notches)
    |> assign(:lever_type, updated_config.lever_type)
    # Clear run_calibration from needs_redo since calibration completed
    |> update(:needs_redo, &MapSet.delete(&1, :run_calibration))
  end

  defp apply_calibration_result(socket, {:error, reason}) do
    socket
    |> assign(:calibration_status, :error)
    |> assign(:calibration_error, format_calibration_error(reason))
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

  defp start_notch_mapping(socket) do
    element = socket.assigns.element
    selected_input = socket.assigns.selected_input

    # Need to bind the input first if not already bound
    lever_config = get_fresh_lever_config(element.id)

    if lever_config && selected_input do
      # Bind input if needed
      case ensure_input_bound(lever_config.id, selected_input.id) do
        {:ok, _} ->
          # Subscribe to mapping events
          Train.subscribe_notch_mapping(lever_config.id)

          # Find port for the device
          port = find_port_for_device(selected_input.device.config_id)
          calibration = selected_input.calibration

          if port && calibration do
            opts = [
              lever_config: Trenino.Repo.preload(lever_config, :notches),
              port: port,
              pin: selected_input.pin,
              calibration: calibration
            ]

            case Train.start_notch_mapping(opts) do
              {:ok, pid} ->
                # Start the mapping process (moves from :ready to first notch)
                NotchMappingSession.start_mapping(pid)
                state = NotchMappingSession.get_public_state(pid)

                socket
                |> assign(:mapping_session_pid, pid)
                |> assign(:mapping_state, state)

              {:error, reason} ->
                put_flash(socket, :error, "Failed to start mapping: #{inspect(reason)}")
            end
          else
            put_flash(socket, :error, "Device not connected or input not calibrated")
          end

        {:error, reason} ->
          put_flash(socket, :error, "Failed to bind input: #{inspect(reason)}")
      end
    else
      put_flash(socket, :error, "Missing lever config or selected input")
    end
  end

  defp stop_notch_mapping(socket) do
    if socket.assigns.mapping_session_pid do
      NotchMappingSession.cancel(socket.assigns.mapping_session_pid)
    end

    socket
    |> assign(:mapping_session_pid, nil)
    |> assign(:mapping_state, nil)
  end

  defp get_fresh_lever_config(element_id) do
    case Train.get_element(element_id, preload: [lever_config: :notches]) do
      {:ok, element} -> element.lever_config
      _ -> nil
    end
  end

  defp ensure_input_bound(lever_config_id, input_id) do
    Train.bind_input(lever_config_id, input_id)
  end

  defp find_port_for_device(config_id) when is_integer(config_id) do
    alias Trenino.Serial.Connection, as: SerialConnection

    SerialConnection.list_devices()
    |> Enum.find_value(fn device_conn ->
      if device_conn.device_config_id == config_id and device_conn.status == :connected do
        device_conn.port
      end
    end)
  end

  defp find_port_for_device(_), do: nil

  defp step_number(step, steps) do
    Enum.find_index(steps, &(&1 == step)) + 1
  end

  defp step_label(:select_input), do: "Select Input"
  defp step_label(:find_endpoint), do: "Find in Simulator"
  defp step_label(:explain_calibration), do: "Calibration Info"
  defp step_label(:run_calibration), do: "Detect Notches"
  defp step_label(:map_notches), do: "Map Positions"

  defp can_proceed_from?(:select_input, assigns), do: assigns.selected_input_id != nil

  defp can_proceed_from?(:find_endpoint, assigns) do
    endpoints = assigns.detected_endpoints

    endpoints != nil and
      endpoints[:min_endpoint] != nil and
      endpoints[:max_endpoint] != nil and
      endpoints[:value_endpoint] != nil
  end

  defp can_proceed_from?(:run_calibration, assigns), do: assigns.calibration_status == :complete

  defp can_proceed_from?(:map_notches, assigns) do
    state = assigns.mapping_state
    state != nil and state[:all_captured] == true
  end

  # Render

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="absolute inset-0 bg-black/50" phx-click="cancel" phx-target={@myself} />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <.wizard_header
          element={@element}
          current_step={@current_step}
          steps={@steps}
          editing_mode={@editing_mode}
          needs_redo={@needs_redo}
          steps_configured={@steps_configured}
          myself={@myself}
        />

        <div class="flex-1 overflow-hidden flex flex-col">
          <.step_content
            current_step={@current_step}
            socket_assigns={assigns}
            myself={@myself}
          />
        </div>
      </div>
    </div>
    """
  end

  # Header with step indicators
  attr :element, Element, required: true
  attr :current_step, :atom, required: true
  attr :steps, :list, required: true
  attr :editing_mode, :boolean, required: true
  attr :needs_redo, :any, required: true
  attr :steps_configured, :any, required: true
  attr :myself, :any, required: true

  defp wizard_header(assigns) do
    ~H"""
    <div class="p-4 border-b border-base-300">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-lg font-semibold">Configure Lever</h2>
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

      <div class="flex items-center gap-1 mt-4 overflow-x-auto">
        <.step_indicator
          :for={step <- @steps}
          step={step}
          steps={@steps}
          current_step={@current_step}
          editing_mode={@editing_mode}
          needs_redo={@needs_redo}
          steps_configured={@steps_configured}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  attr :step, :atom, required: true
  attr :steps, :list, required: true
  attr :current_step, :atom, required: true
  attr :editing_mode, :boolean, required: true
  attr :needs_redo, :any, required: true
  attr :steps_configured, :any, required: true
  attr :myself, :any, required: true

  defp step_indicator(assigns) do
    steps = assigns.steps
    step_num = step_number(assigns.step, steps)
    total_steps = length(steps)
    is_active = assigns.step == assigns.current_step
    needs_redo = MapSet.member?(assigns.needs_redo, assigns.step)

    # In edit mode, use steps_configured to show completion status
    # In new mode, only show completed for steps before current
    is_configured =
      if assigns.editing_mode do
        MapSet.member?(assigns.steps_configured, assigns.step)
      else
        current_num = step_number(assigns.current_step, steps)
        step_num < current_num
      end

    # In edit mode, check if this step is navigable
    is_navigable =
      assigns.editing_mode and
        assigns.step != assigns.current_step and
        can_navigate_to?(assigns, assigns.step)

    assigns =
      assigns
      |> assign(:step_num, step_num)
      |> assign(:total_steps, total_steps)
      |> assign(:is_active, is_active)
      |> assign(:is_configured, is_configured)
      |> assign(:needs_redo, needs_redo)
      |> assign(:is_navigable, is_navigable)
      |> assign(:label, step_label(assigns.step))

    ~H"""
    <div class="flex items-center">
      <div
        class={[
          "flex items-center gap-1.5",
          @is_navigable && "cursor-pointer hover:opacity-80"
        ]}
        phx-click={@is_navigable && "go_to_step"}
        phx-value-step={@is_navigable && @step}
        phx-target={@is_navigable && @myself}
      >
        <div class={[
          "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium transition-colors",
          @is_active && "bg-primary text-primary-content",
          @is_configured && not @is_active && not @needs_redo && "bg-success text-success-content",
          @needs_redo && "bg-warning text-warning-content",
          (not @is_active and not @is_configured and not @needs_redo) &&
            "bg-base-300 text-base-content/50"
        ]}>
          <.icon
            :if={@is_configured and not @is_active and not @needs_redo}
            name="hero-check"
            class="w-4 h-4"
          />
          <.icon :if={@needs_redo} name="hero-exclamation-triangle" class="w-4 h-4" />
          <span :if={@is_active or (not @is_configured and not @needs_redo)}>{@step_num}</span>
        </div>
        <span class={[
          "text-xs whitespace-nowrap",
          @is_active && "font-medium",
          @is_configured && not @is_active && not @needs_redo && "text-success",
          @needs_redo && "text-warning font-medium",
          (not @is_active and not @is_configured and not @needs_redo) && "text-base-content/50"
        ]}>
          {@label}
        </span>
      </div>
      <div :if={@step_num < @total_steps} class="w-4 h-px bg-base-300 mx-1" />
    </div>
    """
  end

  # Step content dispatcher
  attr :current_step, :atom, required: true
  attr :socket_assigns, :map, required: true
  attr :myself, :any, required: true

  defp step_content(%{current_step: :select_input} = assigns) do
    ~H"""
    <.step_select_input
      available_inputs={@socket_assigns.available_inputs}
      selected_input_id={@socket_assigns.selected_input_id}
      can_proceed={can_proceed_from?(:select_input, @socket_assigns)}
      myself={@myself}
    />
    """
  end

  defp step_content(%{current_step: :find_endpoint} = assigns) do
    ~H"""
    <.step_find_endpoint
      client={@socket_assigns.client}
      detected_endpoints={@socket_assigns.detected_endpoints}
      show_auto_detect={@socket_assigns.show_auto_detect}
      can_proceed={can_proceed_from?(:find_endpoint, @socket_assigns)}
      myself={@myself}
    />
    """
  end

  defp step_content(%{current_step: :explain_calibration} = assigns) do
    ~H"""
    <.step_explain_calibration myself={@myself} />
    """
  end

  defp step_content(%{current_step: :run_calibration} = assigns) do
    ~H"""
    <.step_run_calibration
      calibration_status={@socket_assigns.calibration_status}
      calibration_progress={@socket_assigns.calibration_progress}
      calibration_error={@socket_assigns.calibration_error}
      lever_type={@socket_assigns.lever_type}
      notches={@socket_assigns.notches}
      can_proceed={can_proceed_from?(:run_calibration, @socket_assigns)}
      myself={@myself}
    />
    """
  end

  defp step_content(%{current_step: :map_notches} = assigns) do
    ~H"""
    <.step_map_notches
      mapping_state={@socket_assigns.mapping_state}
      can_proceed={can_proceed_from?(:map_notches, @socket_assigns)}
      myself={@myself}
    />
    """
  end

  # Step 1: Select Input
  attr :available_inputs, :list, required: true
  attr :selected_input_id, :integer, default: nil
  attr :can_proceed, :boolean, required: true
  attr :myself, :any, required: true

  defp step_select_input(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <div class="max-w-lg mx-auto">
        <h3 class="text-lg font-semibold mb-2">Select Hardware Input</h3>
        <p class="text-sm text-base-content/60 mb-4">
          Choose a calibrated lever to control this element. Only calibrated analog inputs are shown.
        </p>

        <div :if={Enum.empty?(@available_inputs)} class="alert alert-warning">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <div>
            <p class="font-medium">No calibrated levers available</p>
            <p class="text-sm">Calibrate a lever in Device Settings first.</p>
          </div>
        </div>

        <div :if={not Enum.empty?(@available_inputs)} class="space-y-2">
          <label
            :for={input <- @available_inputs}
            class={[
              "flex items-center gap-3 p-4 rounded-lg border cursor-pointer transition-colors",
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
              class="radio radio-primary"
            />
            <div class="flex-1">
              <div class="font-medium">{input.device.name}</div>
              <div class="text-sm text-base-content/60">
                Pin {input.pin}
                <span :if={input.calibration} class="text-success">
                  — Calibrated
                </span>
              </div>
            </div>
          </label>
        </div>
      </div>
    </div>

    <.step_footer can_proceed={@can_proceed} show_back={false} myself={@myself} />
    """
  end

  # Step 2: Find Endpoint
  attr :client, :any, required: true
  attr :detected_endpoints, :map, default: nil
  attr :show_auto_detect, :boolean, default: false
  attr :can_proceed, :boolean, required: true
  attr :myself, :any, required: true

  defp step_find_endpoint(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col overflow-hidden">
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
          Move the lever in the simulator to detect it, or browse the API tree below
        </p>
      </div>

      <div class="flex-1 overflow-hidden flex flex-col">
        <.live_component
          module={TreninoWeb.ApiExplorerComponent}
          id="lever-wizard-api-explorer"
          field={:endpoint}
          client={@client}
          mode={:lever}
          embedded={true}
        />
      </div>

      <div :if={@detected_endpoints} class="p-4 border-t border-base-300 bg-base-200/50">
        <h4 class="text-sm font-medium mb-2">Detected Endpoints</h4>
        <div class="grid grid-cols-3 gap-2 text-xs font-mono">
          <div class="truncate" title={@detected_endpoints[:min_endpoint]}>
            <span class="text-base-content/60">Min:</span> {@detected_endpoints[:min_endpoint] || "—"}
          </div>
          <div class="truncate" title={@detected_endpoints[:max_endpoint]}>
            <span class="text-base-content/60">Max:</span> {@detected_endpoints[:max_endpoint] || "—"}
          </div>
          <div class="truncate" title={@detected_endpoints[:value_endpoint]}>
            <span class="text-base-content/60">Value:</span> {@detected_endpoints[:value_endpoint] ||
              "—"}
          </div>
        </div>
      </div>

      <.live_component
        :if={@show_auto_detect}
        module={TreninoWeb.AutoDetectComponent}
        id="lever-wizard-auto-detect"
        client={@client}
      />
    </div>

    <.step_footer can_proceed={@can_proceed} show_back={true} myself={@myself} />
    """
  end

  # Step 3: Explain Calibration
  attr :myself, :any, required: true

  defp step_explain_calibration(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <div class="max-w-lg mx-auto text-center">
        <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-primary/10 flex items-center justify-center">
          <.icon name="hero-cog-6-tooth" class="w-8 h-8 text-primary" />
        </div>

        <h3 class="text-lg font-semibold mb-2">Auto-Calibration</h3>
        <p class="text-base-content/70 mb-6">
          The system will detect notch positions by stepping through the lever range and reading simulator values.
        </p>

        <div class="text-left bg-base-200 rounded-lg p-4 space-y-3">
          <h4 class="font-medium">Before continuing, ensure:</h4>
          <ul class="space-y-2">
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>The train is loaded and stationary</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>The lever can move freely (no physics locks)</span>
            </li>
            <li class="flex items-start gap-2">
              <.icon name="hero-check-circle" class="w-5 h-5 text-success flex-shrink-0 mt-0.5" />
              <span>Train key is in and reverser is neutral (if applicable)</span>
            </li>
          </ul>
        </div>

        <div class="mt-6">
          <p class="text-sm text-base-content/50">
            This process takes about 5-10 seconds.
          </p>
        </div>
      </div>
    </div>

    <div class="p-4 border-t border-base-300 flex justify-between">
      <button phx-click="prev_step" phx-target={@myself} class="btn btn-ghost">
        <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
      </button>
      <div class="flex gap-2">
        <button phx-click="skip_calibration" phx-target={@myself} class="btn btn-ghost">
          Skip (Manual)
        </button>
        <button phx-click="next_step" phx-target={@myself} class="btn btn-primary">
          Start Calibration <.icon name="hero-arrow-right" class="w-4 h-4" />
        </button>
      </div>
    </div>
    """
  end

  # Step 4: Run Calibration
  attr :calibration_status, :atom, required: true
  attr :calibration_progress, :float, required: true
  attr :calibration_error, :string, default: nil
  attr :lever_type, :atom, default: nil
  attr :notches, :list, default: []
  attr :can_proceed, :boolean, required: true
  attr :myself, :any, required: true

  defp step_run_calibration(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <div class="max-w-lg mx-auto text-center">
        <div :if={@calibration_status == :running}>
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-primary/10 flex items-center justify-center">
            <span class="loading loading-spinner loading-lg text-primary"></span>
          </div>
          <h3 class="text-lg font-semibold mb-2">Analyzing Lever...</h3>
          <p class="text-base-content/70 mb-4">
            Sweeping through lever positions and reading values.
          </p>
          <p class="text-sm text-base-content/50 mt-2">
            This may take 10-15 seconds
          </p>
        </div>

        <div :if={@calibration_status == :complete}>
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-success/10 flex items-center justify-center">
            <.icon name="hero-check-circle" class="w-8 h-8 text-success" />
          </div>
          <h3 class="text-lg font-semibold mb-2">Analysis Complete!</h3>
          <p class="text-base-content/70 mb-2">
            Detected as <span class="font-semibold">{format_lever_type(@lever_type)}</span> lever
          </p>
          <p class="text-base-content/60 text-sm mb-4">
            Found {length(@notches)} notches
          </p>

          <div class="text-left bg-base-200 rounded-lg p-4 max-h-48 overflow-y-auto">
            <div
              :for={{notch, idx} <- Enum.with_index(@notches)}
              class="flex items-center justify-between py-2 border-b border-base-300 last:border-0"
            >
              <div class="flex items-center gap-2">
                <span class={[
                  "w-6 h-6 rounded-full flex items-center justify-center text-xs font-medium",
                  notch.type == :gate && "bg-warning/20 text-warning",
                  notch.type == :linear && "bg-info/20 text-info"
                ]}>
                  {if notch.type == :gate, do: "G", else: "L"}
                </span>
                <span class="font-medium">{notch.description || "Notch #{idx}"}</span>
              </div>
              <span class="font-mono text-sm text-base-content/60">
                {format_notch_value(notch)}
              </span>
            </div>
          </div>
        </div>

        <div :if={@calibration_status == :error}>
          <div class="w-16 h-16 mx-auto mb-4 rounded-full bg-error/10 flex items-center justify-center">
            <.icon name="hero-exclamation-circle" class="w-8 h-8 text-error" />
          </div>
          <h3 class="text-lg font-semibold mb-2">Calibration Failed</h3>
          <p class="text-error mb-4">{@calibration_error}</p>
        </div>
      </div>
    </div>

    <.step_footer
      can_proceed={@can_proceed}
      show_back={@calibration_status != :running}
      myself={@myself}
    />
    """
  end

  defp format_notch_value(%{type: :gate, value: value}) when is_number(value) do
    Float.round(value, 2)
  end

  defp format_notch_value(%{type: :linear, min_value: min, max_value: max})
       when is_number(min) and is_number(max) do
    "#{Float.round(min, 2)} – #{Float.round(max, 2)}"
  end

  defp format_notch_value(_), do: "—"

  defp format_lever_type(:discrete), do: "Discrete"
  defp format_lever_type(:continuous), do: "Continuous"
  defp format_lever_type(:hybrid), do: "Hybrid"
  defp format_lever_type(_), do: "Unknown"

  defp format_calibration_error(:no_client), do: "Simulator not connected"
  defp format_calibration_error(:no_control_path), do: "Could not determine control path"
  defp format_calibration_error(:insufficient_samples), do: "Could not collect enough samples"

  defp format_calibration_error({:http_error, code, msg}),
    do: "Simulator error: #{code} - #{msg}"

  defp format_calibration_error(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp format_calibration_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_calibration_error(reason), do: inspect(reason)

  # Step 5: Map Notches
  attr :mapping_state, :map, default: nil
  attr :can_proceed, :boolean, required: true
  attr :myself, :any, required: true

  defp step_map_notches(assigns) do
    ~H"""
    <div class="flex-1 overflow-y-auto p-6">
      <div :if={is_nil(@mapping_state)} class="flex items-center justify-center h-full">
        <span class="loading loading-spinner loading-lg text-primary"></span>
      </div>

      <div :if={@mapping_state} class="max-w-2xl mx-auto">
        <h3 class="text-lg font-semibold mb-2">Map Hardware Positions</h3>
        <p class="text-sm text-base-content/60 mb-4">
          Move your physical lever to capture the range for each notch.
          Lever direction will be automatically detected when you save.
        </p>

        <%!-- Lever Visualization (no live indicator - just shows notch positions) --%>
        <.live_component
          module={TreninoWeb.LeverVisualization}
          id="lever-viz"
          notches={@mapping_state.notches}
          captured_ranges={@mapping_state.captured_ranges}
          total_travel={@mapping_state.total_travel}
          current_notch_index={@mapping_state.current_notch_index}
          event_target={@myself}
        />

        <%!-- Current notch mapping panel --%>
        <div :if={@mapping_state.current_notch} class="mt-6 bg-base-200 rounded-lg p-4">
          <div class="flex items-center justify-between mb-4">
            <div>
              <h4 class="font-semibold">{@mapping_state.current_notch.description}</h4>
              <p class="text-sm text-base-content/60">
                {if @mapping_state.current_notch.type == :gate,
                  do: "Wiggle the lever within this position",
                  else: "Sweep through the full range"}
              </p>
            </div>
            <span class={[
              "badge",
              @mapping_state.current_notch.type == :gate && "badge-warning",
              @mapping_state.current_notch.type == :linear && "badge-info"
            ]}>
              {if @mapping_state.current_notch.type == :gate, do: "Gate", else: "Linear"}
            </span>
          </div>

          <div :if={@mapping_state.is_capturing} class="space-y-4">
            <div class="grid grid-cols-3 gap-4 text-center">
              <div>
                <div class="text-2xl font-mono font-bold text-info">
                  {format_calibrated(@mapping_state.current_min)}
                </div>
                <div class="text-xs text-base-content/60">Min</div>
              </div>
              <div>
                <div class="text-3xl font-mono font-bold text-primary">
                  {format_calibrated(@mapping_state.current_value)}
                </div>
                <div class="text-xs text-base-content/60">Current</div>
              </div>
              <div>
                <div class="text-2xl font-mono font-bold text-info">
                  {format_calibrated(@mapping_state.current_max)}
                </div>
                <div class="text-xs text-base-content/60">Max</div>
              </div>
            </div>

            <div class="flex items-center justify-center gap-4 text-sm text-base-content/60">
              {@mapping_state.sample_count} samples collected
            </div>

            <div class="flex justify-center gap-2">
              <button phx-click="reset_samples" phx-target={@myself} class="btn btn-ghost btn-sm">
                Reset
              </button>
              <button phx-click="stop_capturing" phx-target={@myself} class="btn btn-ghost btn-sm">
                Stop
              </button>
              <button
                phx-click="capture_range"
                phx-target={@myself}
                disabled={not @mapping_state.can_capture}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-check" class="w-4 h-4" /> Capture
              </button>
            </div>
          </div>

          <div :if={not @mapping_state.is_capturing} class="text-center">
            <div class="text-3xl font-mono font-bold text-primary mb-4">
              {format_calibrated(@mapping_state.current_value)}
            </div>
            <button phx-click="start_capturing" phx-target={@myself} class="btn btn-primary">
              <.icon name="hero-play" class="w-4 h-4" /> Start Capturing
            </button>
          </div>
        </div>

        <%!-- Preview step (when all captured) --%>
        <div :if={@mapping_state.current_step == :preview} class="mt-6 text-center">
          <div class="w-12 h-12 mx-auto mb-4 rounded-full bg-success/10 flex items-center justify-center">
            <.icon name="hero-check-circle" class="w-6 h-6 text-success" />
          </div>
          <h4 class="font-semibold mb-2">All Notches Mapped!</h4>
          <p class="text-sm text-base-content/60 mb-4">
            Review the mapping above, then save to continue.
          </p>
          <button phx-click="save_and_finish" phx-target={@myself} class="btn btn-primary">
            <.icon name="hero-check" class="w-4 h-4" /> Save Mapping
          </button>
        </div>
      </div>
    </div>

    <.step_footer can_proceed={false} show_back={true} myself={@myself} />
    """
  end

  defp format_calibrated(nil), do: "—"
  defp format_calibrated(value) when is_integer(value), do: Integer.to_string(value)

  defp format_calibrated(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 0)

  # Step footer
  attr :can_proceed, :boolean, required: true
  attr :show_back, :boolean, default: true
  attr :myself, :any, required: true

  defp step_footer(assigns) do
    ~H"""
    <div class="p-4 border-t border-base-300 flex justify-between">
      <button
        :if={@show_back}
        phx-click="prev_step"
        phx-target={@myself}
        class="btn btn-ghost"
      >
        <.icon name="hero-arrow-left" class="w-4 h-4" /> Back
      </button>
      <div :if={not @show_back}></div>
      <button
        phx-click="next_step"
        phx-target={@myself}
        disabled={not @can_proceed}
        class="btn btn-primary"
      >
        Continue <.icon name="hero-arrow-right" class="w-4 h-4" />
      </button>
    </div>
    """
  end
end
