defmodule TreninoWeb.ConfigurationEditLive do
  @moduledoc """
  LiveView for editing a configuration.

  Supports both creating new configurations and editing existing ones.
  Configurations can be applied to any connected device.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents
  import TreninoWeb.SharedComponents

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session
  alias Trenino.Hardware.{ConfigId, Device, Input, Output}
  alias Trenino.Serial.Connection

  @impl true
  def mount(%{"config_id" => "new"}, _session, socket) do
    mount_new(socket)
  end

  @impl true
  def mount(%{"config_id" => config_id_str}, _session, socket) do
    case ConfigId.parse(config_id_str) do
      {:ok, config_id} ->
        mount_existing(socket, config_id)

      {:error, :invalid} ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid configuration ID")
         |> redirect(to: ~p"/")}
    end
  end

  @impl true
  def handle_params(%{"config_id" => "new"}, _uri, socket) do
    # Already in new mode, no changes needed
    {:noreply, socket}
  end

  @impl true
  def handle_params(%{"config_id" => config_id_str}, _uri, socket) do
    if socket.assigns.new_mode do
      handle_params_transition_from_new(socket, config_id_str)
    else
      # Already in existing mode, no changes needed
      {:noreply, socket}
    end
  end

  defp handle_params_transition_from_new(socket, config_id_str) do
    with {:ok, config_id} <- ConfigId.parse(config_id_str),
         true <- socket.assigns.device.config_id == config_id,
         {:ok, inputs} <- Hardware.list_inputs(socket.assigns.device.id),
         {:ok, matrices} <- Hardware.list_matrices(socket.assigns.device.id),
         {:ok, outputs} <- Hardware.list_outputs(socket.assigns.device.id) do
      {:noreply,
       socket
       |> assign(:new_mode, false)
       |> assign(:inputs, inputs)
       |> assign(:matrices, matrices)
       |> assign(:outputs, outputs)}
    else
      {:error, :invalid} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid configuration ID")
         |> redirect(to: ~p"/")}

      false ->
        {:noreply,
         socket
         |> put_flash(:error, "Configuration mismatch")
         |> redirect(to: ~p"/")}
    end
  end

  defp mount_new(socket) do
    if connected?(socket) do
      Hardware.subscribe_configuration()
    end

    {:ok, device} = Hardware.create_device(%{name: "New Configuration"})
    changeset = Device.changeset(device, %{})

    {:ok,
     socket
     |> assign(:device, device)
     |> assign(:device_form, to_form(changeset))
     |> assign(:inputs, [])
     |> assign(:matrices, [])
     |> assign(:outputs, [])
     |> assign(:input_values, %{})
     |> assign(:new_mode, true)
     |> assign(:active_port, nil)
     |> assign(:modal_open, false)
     |> assign(:form, to_form(Input.changeset(%Input{}, %{input_type: :analog, sensitivity: 5})))
     |> assign(:matrix_modal_open, false)
     |> assign(:matrix_row_pins_input, "")
     |> assign(:matrix_col_pins_input, "")
     |> assign(:matrix_errors, %{})
     |> assign(:testing_matrix, nil)
     |> assign(:matrix_tested_buttons, MapSet.new())
     |> assign(:output_modal_open, false)
     |> assign(:output_form, to_form(Output.changeset(%Output{}, %{})))
     |> assign(:output_states, %{})
     |> assign(:applying, false)
     |> assign(:calibrating_input, nil)
     |> assign(:calibration_session_state, nil)
     |> assign(:show_apply_modal, false)
     |> assign(:show_delete_modal, false)}
  end

  defp mount_existing(socket, config_id) do
    case Hardware.get_device_by_config_id(config_id) do
      {:ok, device} ->
        maybe_subscribe_on_connect(socket, config_id)

        {:ok, inputs} = Hardware.list_inputs(device.id)
        {:ok, matrices} = Hardware.list_matrices(device.id)
        {:ok, outputs} = Hardware.list_outputs(device.id)
        active_port = find_active_port(config_id)
        input_values = if active_port, do: Hardware.get_input_values(active_port), else: %{}
        changeset = Device.changeset(device, %{})

        {:ok,
         socket
         |> assign(:device, device)
         |> assign(:device_form, to_form(changeset))
         |> assign(:inputs, inputs)
         |> assign(:matrices, matrices)
         |> assign(:outputs, outputs)
         |> assign(:input_values, input_values)
         |> assign(:new_mode, false)
         |> assign(:active_port, active_port)
         |> assign(:modal_open, false)
         |> assign(
           :form,
           to_form(Input.changeset(%Input{}, %{input_type: :analog, sensitivity: 5}))
         )
         |> assign(:matrix_modal_open, false)
         |> assign(:matrix_row_pins_input, "")
         |> assign(:matrix_col_pins_input, "")
         |> assign(:matrix_errors, %{})
         |> assign(:testing_matrix, nil)
         |> assign(:matrix_tested_buttons, MapSet.new())
         |> assign(:output_modal_open, false)
         |> assign(:output_form, to_form(Output.changeset(%Output{}, %{})))
         |> assign(:output_states, %{})
         |> assign(:applying, false)
         |> assign(:calibrating_input, nil)
         |> assign(:calibration_session_state, nil)
         |> assign(:show_apply_modal, false)
         |> assign(:show_delete_modal, false)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Configuration not found")
         |> redirect(to: ~p"/")}
    end
  end

  defp find_active_port(config_id) do
    Connection.list_devices()
    |> Enum.find(&(&1.device_config_id == config_id && &1.status == :connected))
    |> then(fn
      nil -> nil
      device -> device.port
    end)
  end

  defp maybe_subscribe_on_connect(socket, config_id) do
    if connected?(socket) do
      Hardware.subscribe_configuration()
      active_port = find_active_port(config_id)
      if active_port, do: Hardware.subscribe_input_values(active_port)
    end
  end

  # Nav component events
  @impl true
  def handle_event("nav_toggle_dropdown", _, socket) do
    {:noreply, assign(socket, :nav_dropdown_open, !socket.assigns.nav_dropdown_open)}
  end

  @impl true
  def handle_event("nav_close_dropdown", _, socket) do
    {:noreply, assign(socket, :nav_dropdown_open, false)}
  end

  @impl true
  def handle_event("nav_scan_devices", _, socket) do
    Connection.scan()
    {:noreply, assign(socket, :nav_scanning, true)}
  end

  @impl true
  def handle_event("nav_disconnect_device", %{"port" => port}, socket) do
    Connection.disconnect(port)
    {:noreply, socket}
  end

  # Device name/description editing
  @impl true
  def handle_event("validate_device", %{"device" => params}, socket) do
    # Auto-save on change
    case Hardware.update_device(socket.assigns.device, params) do
      {:ok, device} ->
        changeset = Device.changeset(device, %{})

        socket =
          socket
          |> assign(:device, device)
          |> assign(:device_form, to_form(changeset))

        # Redirect from /new to the actual config page on first save
        socket =
          if socket.assigns.new_mode do
            push_patch(socket, to: ~p"/configurations/#{device.config_id}")
          else
            socket
          end

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, :device_form, to_form(changeset))}
    end
  end

  # Input management
  @impl true
  def handle_event("open_add_input_modal", _params, socket) do
    {:noreply, assign(socket, :modal_open, true)}
  end

  @impl true
  def handle_event("close_add_input_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:form, to_form(Input.changeset(%Input{}, %{input_type: :analog, sensitivity: 5})))
     |> assign(:matrix_row_pins_input, "")
     |> assign(:matrix_col_pins_input, "")
     |> assign(:matrix_errors, %{})}
  end

  @impl true
  def handle_event("validate_input", %{"input" => params}, socket) do
    changeset =
      %Input{}
      |> Input.changeset(Map.put(params, "device_id", socket.assigns.device.id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate_matrix_pins", params, socket) do
    # Handle partial updates - use existing value if not provided
    row_pins = Map.get(params, "row_pins", socket.assigns.matrix_row_pins_input)
    col_pins = Map.get(params, "col_pins", socket.assigns.matrix_col_pins_input)

    errors = validate_matrix_pins(row_pins, col_pins)

    {:noreply,
     socket
     |> assign(:matrix_row_pins_input, row_pins)
     |> assign(:matrix_col_pins_input, col_pins)
     |> assign(:matrix_errors, errors)}
  end

  @impl true
  def handle_event("add_input", %{"input" => params}, socket) do
    add_regular_input(socket, params)
  end

  # Matrix modal
  @impl true
  def handle_event("open_add_matrix_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:matrix_modal_open, true)
     |> assign(:matrix_row_pins_input, "")
     |> assign(:matrix_col_pins_input, "")
     |> assign(:matrix_errors, %{})}
  end

  @impl true
  def handle_event("close_add_matrix_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:matrix_modal_open, false)
     |> assign(:matrix_row_pins_input, "")
     |> assign(:matrix_col_pins_input, "")
     |> assign(:matrix_errors, %{})}
  end

  @impl true
  def handle_event("add_matrix", _params, socket) do
    add_matrix_input(socket, %{})
  end

  @impl true
  def handle_event("delete_input", %{"id" => id}, socket) do
    case Hardware.delete_input(String.to_integer(id)) do
      {:ok, _input} ->
        {:ok, inputs} = Hardware.list_inputs(socket.assigns.device.id)
        {:noreply, assign(socket, :inputs, inputs)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete input")}
    end
  end

  # Output management
  @impl true
  def handle_event("open_add_output_modal", _params, socket) do
    {:noreply, assign(socket, :output_modal_open, true)}
  end

  @impl true
  def handle_event("close_add_output_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:output_modal_open, false)
     |> assign(:output_form, to_form(Output.changeset(%Output{}, %{})))}
  end

  @impl true
  def handle_event("validate_output", %{"output" => params}, socket) do
    changeset =
      %Output{}
      |> Output.changeset(Map.put(params, "device_id", socket.assigns.device.id))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :output_form, to_form(changeset))}
  end

  @impl true
  def handle_event("add_output", %{"output" => params}, socket) do
    case Hardware.create_output(socket.assigns.device.id, params) do
      {:ok, _output} ->
        {:ok, outputs} = Hardware.list_outputs(socket.assigns.device.id)

        {:noreply,
         socket
         |> assign(:outputs, outputs)
         |> assign(:output_modal_open, false)
         |> assign(:output_form, to_form(Output.changeset(%Output{}, %{})))}

      {:error, changeset} ->
        {:noreply, assign(socket, :output_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_output", %{"id" => id}, socket) do
    case Hardware.delete_output(String.to_integer(id)) do
      {:ok, _output} ->
        {:ok, outputs} = Hardware.list_outputs(socket.assigns.device.id)
        {:noreply, assign(socket, :outputs, outputs)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete output")}
    end
  end

  @impl true
  def handle_event("toggle_output", %{"id" => id}, socket) do
    output_id = String.to_integer(id)
    output = Enum.find(socket.assigns.outputs, &(&1.id == output_id))

    if output && socket.assigns.active_port do
      # Get current state (default to false/off)
      current_state = Map.get(socket.assigns.output_states, output_id, false)
      new_state = !current_state

      # Send the command to the device
      value = if new_state, do: :high, else: :low
      Hardware.set_output(socket.assigns.active_port, output.pin, value)

      # Update the state
      output_states = Map.put(socket.assigns.output_states, output_id, new_state)
      {:noreply, assign(socket, :output_states, output_states)}
    else
      {:noreply, socket}
    end
  end

  # Apply configuration
  @impl true
  def handle_event("show_apply_modal", _params, socket) do
    {:noreply, assign(socket, :show_apply_modal, true)}
  end

  @impl true
  def handle_event("close_apply_modal", _params, socket) do
    {:noreply, assign(socket, :show_apply_modal, false)}
  end

  @impl true
  def handle_event("apply_to_device", %{"port" => port}, socket) do
    socket =
      socket
      |> assign(:applying, true)
      |> assign(:show_apply_modal, false)

    case Hardware.apply_configuration(port, socket.assigns.device.id) do
      {:ok, _config_id} ->
        {:noreply, socket}

      {:error, :no_inputs} ->
        {:noreply,
         socket
         |> assign(:applying, false)
         |> put_flash(:error, "Cannot apply empty configuration. Add at least one input.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:applying, false)
         |> put_flash(:error, "Failed to apply: #{inspect(reason)}")}
    end
  end

  # Delete configuration
  @impl true
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, true)}
  end

  @impl true
  def handle_event("close_delete_modal", _params, socket) do
    {:noreply, assign(socket, :show_delete_modal, false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    device = socket.assigns.device

    case Hardware.delete_device(device) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Configuration \"#{device.name}\" deleted")
         |> redirect(to: ~p"/")}

      {:error, :configuration_active} ->
        {:noreply,
         socket
         |> put_flash(:error, "Cannot delete: configuration is active on a connected device")
         |> assign(:show_delete_modal, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete: #{inspect(reason)}")
         |> assign(:show_delete_modal, false)}
    end
  end

  # Calibration
  @impl true
  def handle_event("start_calibration", %{"id" => id}, socket) do
    input = Enum.find(socket.assigns.inputs, &(&1.id == String.to_integer(id)))

    if input && socket.assigns.active_port do
      Session.subscribe(input.id)
      {:noreply, assign(socket, :calibrating_input, input)}
    else
      {:noreply, put_flash(socket, :error, "Apply configuration to a device before calibrating")}
    end
  end

  # Matrix Test
  @impl true
  def handle_event("start_matrix_test", %{"id" => id}, socket) do
    matrix = Enum.find(socket.assigns.matrices, &(&1.id == String.to_integer(id)))

    if matrix && socket.assigns.active_port do
      {:noreply, assign(socket, :testing_matrix, matrix)}
    else
      {:noreply, put_flash(socket, :error, "Apply configuration to a device before testing")}
    end
  end

  # Delete matrix
  @impl true
  def handle_event("delete_matrix", %{"id" => id}, socket) do
    case Hardware.delete_matrix(String.to_integer(id)) do
      {:ok, _matrix} ->
        {:ok, matrices} = Hardware.list_matrices(socket.assigns.device.id)
        {:noreply, assign(socket, :matrices, matrices)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete matrix")}
    end
  end

  # Inline name editing
  @impl true
  def handle_event("update_input_name", %{"id" => id, "value" => name}, socket) do
    input = Enum.find(socket.assigns.inputs, &(&1.id == String.to_integer(id)))

    if input do
      case Hardware.update_input(input, %{name: name}) do
        {:ok, _updated} ->
          {:ok, inputs} = Hardware.list_inputs(socket.assigns.device.id)
          {:noreply, assign(socket, :inputs, inputs)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update input name")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_output_name", %{"id" => id, "value" => name}, socket) do
    output = Enum.find(socket.assigns.outputs, &(&1.id == String.to_integer(id)))

    if output do
      case Hardware.update_output(output, %{name: name}) do
        {:ok, _updated} ->
          {:ok, outputs} = Hardware.list_outputs(socket.assigns.device.id)
          {:noreply, assign(socket, :outputs, outputs)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update output name")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_matrix_name", %{"id" => id, "value" => name}, socket) do
    matrix = Enum.find(socket.assigns.matrices, &(&1.id == String.to_integer(id)))

    if matrix do
      case Hardware.update_matrix(matrix, %{name: name}) do
        {:ok, _updated} ->
          {:ok, matrices} = Hardware.list_matrices(socket.assigns.device.id)
          {:noreply, assign(socket, :matrices, matrices)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update matrix name")}
      end
    else
      {:noreply, socket}
    end
  end

  # Private helpers for input creation

  defp add_regular_input(socket, params) do
    # For BLDC lever, auto-set pin to encoder_cs value
    params =
      if params["input_type"] in ["bldc_lever", :bldc_lever] do
        Map.put(params, "pin", params["encoder_cs"])
      else
        params
      end

    case Hardware.create_input(socket.assigns.device.id, params) do
      {:ok, _input} ->
        {:ok, inputs} = Hardware.list_inputs(socket.assigns.device.id)

        {:noreply,
         socket
         |> assign(:inputs, inputs)
         |> assign(:modal_open, false)
         |> assign(
           :form,
           to_form(Input.changeset(%Input{}, %{input_type: :analog, sensitivity: 5}))
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp add_matrix_input(socket, _params) do
    row_pins_input = socket.assigns.matrix_row_pins_input
    col_pins_input = socket.assigns.matrix_col_pins_input

    errors = validate_matrix_pins(row_pins_input, col_pins_input)

    if map_size(errors) > 0 do
      {:noreply, assign(socket, :matrix_errors, errors)}
    else
      row_pins = parse_pins(row_pins_input)
      col_pins = parse_pins(col_pins_input)

      # Create matrix with row/col pins - this also creates the virtual button inputs
      case Hardware.create_matrix(socket.assigns.device.id, %{
             name: "Matrix",
             row_pins: row_pins,
             col_pins: col_pins
           }) do
        {:ok, _matrix} ->
          {:ok, inputs} = Hardware.list_inputs(socket.assigns.device.id)
          {:ok, matrices} = Hardware.list_matrices(socket.assigns.device.id)

          {:noreply,
           socket
           |> assign(:inputs, inputs)
           |> assign(:matrices, matrices)
           |> assign(:matrix_modal_open, false)
           |> assign(:matrix_row_pins_input, "")
           |> assign(:matrix_col_pins_input, "")
           |> assign(:matrix_errors, %{})}

        {:error, changeset} ->
          error_message = format_changeset_errors(changeset)
          {:noreply, assign(socket, :matrix_errors, %{general: error_message})}
      end
    end
  end

  defp format_changeset_errors(changeset) do
    message =
      Enum.map_join(changeset.errors, ", ", fn {field, {msg, _opts}} ->
        "#{field}: #{msg}"
      end)

    if message == "", do: "Failed to create matrix", else: message
  end

  defp validate_matrix_pins(row_pins_str, col_pins_str) do
    row_pins = parse_pins(row_pins_str)
    col_pins = parse_pins(col_pins_str)

    %{}
    |> validate_pins_required(:row_pins, row_pins, "At least one row pin is required")
    |> validate_pins_required(:col_pins, col_pins, "At least one column pin is required")
    |> validate_pins_range(:row_pins, row_pins)
    |> validate_pins_range(:col_pins, col_pins)
    |> validate_pins_unique(:row_pins, row_pins)
    |> validate_pins_unique(:col_pins, col_pins)
    |> validate_pins_no_overlap(row_pins, col_pins)
  end

  defp validate_pins_required(errors, key, pins, message) do
    if Enum.empty?(pins), do: Map.put(errors, key, message), else: errors
  end

  defp validate_pins_range(errors, key, pins) do
    if Enum.any?(pins, &(&1 < 0 or &1 > 127)) do
      Map.put(errors, key, "Pins must be between 0 and 127")
    else
      errors
    end
  end

  defp validate_pins_unique(errors, key, pins) do
    if length(pins) != length(Enum.uniq(pins)) do
      Map.put(errors, key, "Duplicate pins are not allowed")
    else
      errors
    end
  end

  defp validate_pins_no_overlap(errors, row_pins, col_pins) do
    overlap = MapSet.intersection(MapSet.new(row_pins), MapSet.new(col_pins))

    if MapSet.size(overlap) > 0,
      do: Map.put(errors, :general, "Row and column pins cannot overlap"),
      else: errors
  end

  defp parse_pins(pins_str) when is_binary(pins_str) do
    pins_str
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.flat_map(fn s ->
      case Integer.parse(s) do
        {n, ""} -> [n]
        _ -> []
      end
    end)
  end

  defp parse_pins(_), do: []

  # handle_info callbacks

  @impl true
  def handle_info(:close_matrix_test, socket) do
    {:noreply, assign(socket, :testing_matrix, nil)}
  end

  # PubSub Event Handlers

  @impl true
  def handle_info({:calibration_result, {:ok, _calibration}}, socket) do
    {:ok, inputs} = Hardware.list_inputs(socket.assigns.device.id)

    {:noreply,
     socket
     |> assign(:inputs, inputs)
     |> assign(:calibrating_input, nil)
     |> put_flash(:info, "Calibration saved successfully")}
  end

  @impl true
  def handle_info({:calibration_result, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:calibrating_input, nil)
     |> put_flash(:error, "Calibration failed: #{inspect(reason)}")}
  end

  @impl true
  def handle_info(:calibration_cancelled, socket) do
    {:noreply, assign(socket, :calibrating_input, nil)}
  end

  @impl true
  def handle_info({:calibration_error, reason}, socket) do
    {:noreply,
     socket
     |> assign(:calibrating_input, nil)
     |> put_flash(:error, "Failed to start calibration: #{inspect(reason)}")}
  end

  @impl true
  def handle_info({event, state}, socket)
      when event in [:session_started, :step_changed, :sample_collected] do
    {:noreply, assign(socket, :calibration_session_state, state)}
  end

  @impl true
  def handle_info({:configuration_applied, port, device, _config_id}, socket) do
    # Subscribe to input values for the new active port
    Hardware.subscribe_input_values(port)

    {:noreply,
     socket
     |> assign(:device, device)
     |> assign(:new_mode, false)
     |> assign(:active_port, port)
     |> assign(:applying, false)
     |> put_flash(:info, "Configuration applied successfully")}
  end

  @impl true
  def handle_info({:configuration_failed, _port, _device_id, reason}, socket) do
    message =
      case reason do
        :timeout -> "Configuration timed out - device did not respond"
        :device_rejected -> "Device rejected the configuration"
        :no_inputs -> "Cannot apply empty configuration"
        _ -> "Failed to apply configuration"
      end

    {:noreply,
     socket
     |> assign(:applying, false)
     |> put_flash(:error, message)}
  end

  @impl true
  def handle_info({:input_value_updated, _port, pin, value}, socket) do
    new_values = Map.put(socket.assigns.input_values, pin, value)
    socket = assign(socket, :input_values, new_values)

    # Track tested buttons for matrix (virtual pins >= 128) when pressed
    socket =
      if pin >= 128 and value == 1 and socket.assigns.testing_matrix do
        update(socket, :matrix_tested_buttons, &MapSet.put(&1, pin))
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(:reset_matrix_test, socket) do
    {:noreply, assign(socket, :matrix_tested_buttons, MapSet.new())}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    socket = assign(socket, :nav_devices, devices)

    # Update active port if configuration is applied to a device
    config_id = socket.assigns.device.config_id
    active_port = find_active_port_in_list(devices, config_id)

    socket =
      if active_port != socket.assigns.active_port do
        if active_port do
          Hardware.subscribe_input_values(active_port)
          assign(socket, :active_port, active_port)
        else
          socket
          |> assign(:active_port, nil)
          |> assign(:input_values, %{})
        end
      else
        socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp find_active_port_in_list(devices, config_id) do
    devices
    |> Enum.find(&(&1.device_config_id == config_id && &1.status == :connected))
    |> then(fn
      nil -> nil
      device -> device.port
    end)
  end

  # Render

  @impl true
  def render(assigns) do
    connected_devices =
      assigns.nav_devices
      |> Enum.filter(&(&1.status == :connected))

    assigns = assign(assigns, :connected_devices, connected_devices)

    ~H"""
    <.breadcrumb items={[
      %{label: "Configurations", path: ~p"/"},
      %{label: @device.name || "New Configuration"}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <.device_header
          device={@device}
          device_form={@device_form}
          active_port={@active_port}
          new_mode={@new_mode}
          can_apply={
            (length(@inputs) > 0 or length(@matrices) > 0) and not Enum.empty?(@connected_devices)
          }
          applying={@applying}
        />

        <div class="bg-base-200/50 rounded-xl p-6 mt-6">
          <.inputs_section
            inputs={@inputs}
            input_values={@input_values}
            active_port={@active_port}
          />
        </div>

        <div class="bg-base-200/50 rounded-xl p-6 mt-6">
          <.matrices_section
            matrices={@matrices}
            input_values={@input_values}
            active_port={@active_port}
          />
        </div>

        <div class="bg-base-200/50 rounded-xl p-6 mt-6">
          <.outputs_section
            outputs={@outputs}
            active_port={@active_port}
            output_states={@output_states}
          />
        </div>

        <.danger_zone
          :if={not @new_mode}
          action_label="Delete Configuration"
          action_description="Permanently remove this configuration and all associated data"
          on_action="show_delete_modal"
          disabled={@active_port != nil}
          disabled_reason="Cannot delete while configuration is active on a device"
        />
      </div>
    </main>

    <.add_input_modal :if={@modal_open} form={@form} />

    <.add_matrix_modal
      :if={@matrix_modal_open}
      matrix_row_pins_input={@matrix_row_pins_input}
      matrix_col_pins_input={@matrix_col_pins_input}
      matrix_errors={@matrix_errors}
    />

    <.add_output_modal :if={@output_modal_open} form={@output_form} />

    <.apply_modal
      :if={@show_apply_modal}
      device={@device}
      connected_devices={@connected_devices}
    />

    <.delete_modal
      :if={@show_delete_modal}
      device={@device}
      active={@active_port != nil}
    />

    <.live_component
      :if={@calibrating_input}
      module={TreninoWeb.CalibrationWizard}
      id="calibration-wizard"
      input={@calibrating_input}
      port={@active_port}
      session_state={@calibration_session_state}
    />

    <.live_component
      :if={@testing_matrix}
      module={TreninoWeb.MatrixTestWizard}
      id="matrix-test-wizard"
      matrix={@testing_matrix}
      port={@active_port}
      input_values={@input_values}
      tested_buttons={@matrix_tested_buttons}
    />
    """
  end

  # Components

  attr :device, :map, required: true
  attr :device_form, :map, required: true
  attr :active_port, :string, default: nil
  attr :new_mode, :boolean, required: true
  attr :can_apply, :boolean, required: true
  attr :applying, :boolean, required: true

  defp device_header(assigns) do
    ~H"""
    <header>
      <.form for={@device_form} phx-change="validate_device">
        <div>
          <label class="label">
            <span class="label-text">Configuration Name</span>
          </label>
          <.input
            field={@device_form[:name]}
            type="text"
            class="input input-bordered w-full text-lg font-semibold"
            placeholder="e.g., Arduino Mega Controller"
          />
        </div>
        <div class="mt-3">
          <label class="label">
            <span class="label-text">Description</span>
          </label>
          <.input
            field={@device_form[:description]}
            type="textarea"
            class="textarea textarea-bordered w-full resize-none"
            placeholder="Add a description (optional)"
            rows="2"
          />
        </div>
        <div class="flex items-center gap-3 mt-4">
          <span class="text-xs text-base-content/50 font-mono">ID: {@device.config_id}</span>
          <span :if={@active_port} class="badge badge-success badge-sm gap-1">
            <span class="w-1.5 h-1.5 rounded-full bg-success-content animate-pulse" /> Active
          </span>
          <div class="ml-auto flex items-center gap-2">
            <button
              :if={@can_apply}
              type="button"
              phx-click="show_apply_modal"
              disabled={@applying}
              class="btn btn-outline btn-sm"
            >
              <.icon :if={@applying} name="hero-arrow-path" class="w-4 h-4 animate-spin" />
              <.icon :if={!@applying} name="hero-play" class="w-4 h-4" />
              {if @applying, do: "Applying...", else: "Apply to Device"}
            </button>
          </div>
        </div>
      </.form>
    </header>
    """
  end

  attr :inputs, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  defp inputs_section(assigns) do
    ~H"""
    <div>
      <.section_header title="Inputs" action_label="Add Input" on_action="open_add_input_modal" />

      <.empty_collection_state
        :if={Enum.empty?(@inputs)}
        icon="hero-plus-circle"
        message="No inputs configured"
        submessage="Add your first input to get started"
      />

      <.inputs_table
        :if={length(@inputs) > 0}
        inputs={@inputs}
        input_values={@input_values}
        active_port={@active_port}
      />
    </div>
    """
  end

  attr :inputs, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  defp inputs_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th class="text-center">Pin</th>
            <th>Name</th>
            <th>Type</th>
            <th>Value</th>
            <th class="w-32"></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={input <- @inputs} class="hover:bg-base-200/50">
            <td class="text-center font-mono">{input.pin}</td>
            <td>
              <input
                type="text"
                value={input.name || ""}
                placeholder="Unnamed"
                phx-blur="update_input_name"
                phx-value-id={input.id}
                class="input input-ghost input-xs w-full max-w-32 placeholder:italic placeholder:text-base-content/50"
              />
            </td>
            <td>
              <span class={[
                "badge badge-sm capitalize",
                input.input_type == :analog && "badge-info",
                input.input_type == :button && "badge-warning",
                input.input_type == :bldc_lever && "badge-accent"
              ]}>
                {if input.input_type == :bldc_lever, do: "BLDC", else: input.input_type}
              </span>
            </td>
            <td class="min-w-24">
              <.input_value
                raw_value={Map.get(@input_values, input.pin)}
                calibration={input.calibration}
                active={@active_port != nil}
                input_type={input.input_type}
              />
            </td>
            <td class="flex gap-1">
              <button
                :if={@active_port != nil && input.input_type == :analog}
                phx-click="start_calibration"
                phx-value-id={input.id}
                class="btn btn-ghost btn-xs text-primary hover:bg-primary/10"
              >
                <.icon name="hero-adjustments-horizontal" class="w-4 h-4" /> Calibrate
              </button>
              <button
                phx-click="delete_input"
                phx-value-id={input.id}
                class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                aria-label="Delete input"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  # Matrices section

  attr :matrices, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  defp matrices_section(assigns) do
    ~H"""
    <div>
      <.section_header title="Matrices" action_label="Add Matrix" on_action="open_add_matrix_modal" />

      <.empty_collection_state
        :if={Enum.empty?(@matrices)}
        icon="hero-squares-2x2"
        message="No matrices configured"
        submessage="Add a button matrix for multiple buttons using fewer pins"
      />

      <.matrices_table
        :if={length(@matrices) > 0}
        matrices={@matrices}
        input_values={@input_values}
        active_port={@active_port}
      />
    </div>
    """
  end

  attr :matrices, :list, required: true
  attr :input_values, :map, required: true
  attr :active_port, :string, default: nil

  defp matrices_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th>Name</th>
            <th>Size</th>
            <th>Buttons</th>
            <th class="w-32"></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={matrix <- @matrices} class="hover:bg-base-200/50">
            <td>
              <input
                type="text"
                value={matrix.name || ""}
                placeholder="Unnamed"
                phx-blur="update_matrix_name"
                phx-value-id={matrix.id}
                class="input input-ghost input-xs w-full max-w-32 font-medium placeholder:italic placeholder:text-base-content/50 placeholder:font-normal"
              />
            </td>
            <td class="font-mono text-sm">
              {length(matrix.row_pins)}x{length(matrix.col_pins)}
            </td>
            <td class="font-mono text-sm">
              {length(matrix.buttons)} buttons
            </td>
            <td class="flex gap-1">
              <button
                :if={@active_port != nil}
                phx-click="start_matrix_test"
                phx-value-id={matrix.id}
                class="btn btn-ghost btn-xs text-primary hover:bg-primary/10"
              >
                <.icon name="hero-squares-2x2" class="w-4 h-4" /> Test
              </button>
              <button
                phx-click="delete_matrix"
                phx-value-id={matrix.id}
                class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                aria-label="Delete matrix"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :raw_value, :integer, default: nil
  attr :calibration, :map, default: nil
  attr :active, :boolean, required: true
  attr :input_type, :atom, default: :analog

  defp input_value(assigns) do
    calibration = loaded_calibration(assigns.calibration)

    calibrated =
      if assigns.raw_value && calibration do
        Hardware.normalize_value(assigns.raw_value, calibration)
      else
        nil
      end

    assigns =
      assigns
      |> assign(:calibration, calibration)
      |> assign(:calibrated, calibrated)

    ~H"""
    <%!-- Not active --%>
    <span :if={!@active} class="text-base-content/50 italic text-sm">
      <.icon name="hero-lock-closed" class="w-3 h-3 inline mr-1" /> N/A
    </span>
    <%!-- Button inputs --%>
    <span :if={@active && @input_type == :button && is_nil(@raw_value)} class="text-base-content/50">
      &mdash;
    </span>
    <span
      :if={@active && @input_type == :button && @raw_value == 1}
      class="badge badge-success badge-xs"
    >
      Pressed
    </span>
    <span
      :if={@active && @input_type == :button && @raw_value == 0}
      class="badge badge-ghost badge-xs"
    >
      Released
    </span>
    <%!-- Analog inputs --%>
    <span :if={@active && @input_type == :analog && is_nil(@raw_value)} class="text-base-content/50">
      &mdash;
    </span>
    <span
      :if={@active && @input_type == :analog && !is_nil(@raw_value)}
      class="font-mono tabular-nums"
    >
      <span class="text-base-content/40 text-xs">{@raw_value}</span>
      <span :if={@calibrated} class="text-base-content/40 text-xs">/</span>
      <span :if={@calibrated}>{@calibrated}</span>
      <span :if={is_nil(@calibration)} class="text-base-content/50 text-xs italic ml-1">
        (uncalibrated)
      </span>
    </span>
    """
  end

  defp loaded_calibration(%Ecto.Association.NotLoaded{}), do: nil
  defp loaded_calibration(nil), do: nil
  defp loaded_calibration(calibration), do: calibration

  attr :outputs, :list, required: true
  attr :active_port, :string, default: nil
  attr :output_states, :map, default: %{}

  defp outputs_section(assigns) do
    ~H"""
    <div>
      <.section_header title="Outputs" action_label="Add Output" on_action="open_add_output_modal" />

      <.empty_collection_state
        :if={Enum.empty?(@outputs)}
        icon="hero-light-bulb"
        message="No outputs configured"
        submessage="Add LEDs or indicators to control"
      />

      <.outputs_table
        :if={length(@outputs) > 0}
        outputs={@outputs}
        active_port={@active_port}
        output_states={@output_states}
      />
    </div>
    """
  end

  attr :outputs, :list, required: true
  attr :active_port, :string, default: nil
  attr :output_states, :map, default: %{}

  defp outputs_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm bg-base-100 rounded-lg">
        <thead>
          <tr class="bg-base-200">
            <th class="text-center">Pin</th>
            <th>Name</th>
            <th :if={@active_port} class="text-center">Test</th>
            <th class="w-16"></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={output <- @outputs} class="hover:bg-base-200/50">
            <td class="text-center font-mono">{output.pin}</td>
            <td>
              <input
                type="text"
                value={output.name || ""}
                placeholder="Unnamed"
                phx-blur="update_output_name"
                phx-value-id={output.id}
                class="input input-ghost input-xs w-full max-w-40 placeholder:italic placeholder:text-base-content/50"
              />
            </td>
            <td :if={@active_port} class="text-center">
              <button
                phx-click="toggle_output"
                phx-value-id={output.id}
                class={[
                  "btn btn-xs",
                  if(Map.get(@output_states, output.id, false),
                    do: "btn-success",
                    else: "btn-ghost"
                  )
                ]}
                title={if Map.get(@output_states, output.id, false), do: "Turn off", else: "Turn on"}
              >
                <.icon
                  name={
                    if Map.get(@output_states, output.id, false),
                      do: "hero-bolt-solid",
                      else: "hero-bolt"
                  }
                  class="w-3 h-3"
                />
                <span class="text-xs">
                  {if Map.get(@output_states, output.id, false), do: "ON", else: "OFF"}
                </span>
              </button>
            </td>
            <td>
              <button
                phx-click="delete_output"
                phx-value-id={output.id}
                class="btn btn-ghost btn-xs text-error hover:bg-error/10"
                aria-label="Delete output"
              >
                <.icon name="hero-trash" class="w-4 h-4" />
              </button>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :form, :map, required: true

  defp add_input_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_input_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-semibold mb-4">Add Input</h2>

        <.form for={@form} phx-change="validate_input" phx-submit="add_input">
          <div class="space-y-4">
            <div>
              <label class="label">
                <span class="label-text">Name (optional)</span>
              </label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="e.g., Horn Button, Throttle"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <label class="label">
                <span class="label-text">Input Type</span>
              </label>
              <.input
                field={@form[:input_type]}
                type="select"
                options={[{"Analog", :analog}, {"Button", :button}, {"BLDC Lever", :bldc_lever}]}
                class="select select-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value not in [:bldc_lever, "bldc_lever"]}>
              <label class="label">
                <span class="label-text">Pin Number</span>
              </label>
              <.input
                field={@form[:pin]}
                type="number"
                placeholder="Enter pin number (0-254)"
                min="0"
                max="254"
                class="input input-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value in [:analog, "analog"]}>
              <label class="label">
                <span class="label-text">Sensitivity (1-10)</span>
              </label>
              <.input
                field={@form[:sensitivity]}
                type="number"
                min="1"
                max="10"
                class="input input-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value in [:button, "button"]}>
              <label class="label">
                <span class="label-text">Debounce (0-255 ms)</span>
              </label>
              <.input
                field={@form[:debounce]}
                type="number"
                min="0"
                max="255"
                placeholder="20"
                class="input input-bordered w-full"
              />
            </div>

            <div :if={@form[:input_type].value in [:bldc_lever, "bldc_lever"]} class="space-y-4">
              <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1">
                Motor Pins
              </div>
              <div class="grid grid-cols-3 gap-3">
                <div>
                  <label class="label"><span class="label-text text-xs">Phase A</span></label>
                  <.input
                    field={@form[:motor_pin_a]}
                    type="number"
                    min="0"
                    max="255"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <div>
                  <label class="label"><span class="label-text text-xs">Phase B</span></label>
                  <.input
                    field={@form[:motor_pin_b]}
                    type="number"
                    min="0"
                    max="255"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <div>
                  <label class="label"><span class="label-text text-xs">Phase C</span></label>
                  <.input
                    field={@form[:motor_pin_c]}
                    type="number"
                    min="0"
                    max="255"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
              </div>

              <div>
                <label class="label">
                  <span class="label-text text-xs">Enable (optional)</span>
                </label>
                <.input
                  field={@form[:motor_enable]}
                  type="number"
                  min="0"
                  max="255"
                  placeholder="None"
                  class="input input-bordered input-sm w-full"
                />
              </div>

              <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1 mt-2">
                Encoder
              </div>
              <div class="grid grid-cols-2 gap-3">
                <div>
                  <label class="label"><span class="label-text text-xs">SPI CS Pin</span></label>
                  <.input
                    field={@form[:encoder_cs]}
                    type="number"
                    min="0"
                    max="255"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <div>
                  <label class="label">
                    <span class="label-text text-xs">Resolution (bits)</span>
                  </label>
                  <.input
                    field={@form[:encoder_bits]}
                    type="number"
                    min="1"
                    max="255"
                    placeholder="14"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
              </div>

              <div class="text-sm font-medium text-base-content/70 border-b border-base-300 pb-1 mt-2">
                Motor Parameters
              </div>
              <div class="grid grid-cols-3 gap-3">
                <div>
                  <label class="label"><span class="label-text text-xs">Pole Pairs</span></label>
                  <.input
                    field={@form[:pole_pairs]}
                    type="number"
                    min="1"
                    max="255"
                    placeholder="11"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <div>
                  <label class="label"><span class="label-text text-xs">Voltage (0.1V)</span></label>
                  <.input
                    field={@form[:voltage]}
                    type="number"
                    min="1"
                    max="255"
                    placeholder="120"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
                <div>
                  <label class="label">
                    <span class="label-text text-xs">Current Limit (A)</span>
                  </label>
                  <.input
                    field={@form[:current_limit]}
                    type="number"
                    min="0"
                    max="25.5"
                    step="0.1"
                    placeholder="0"
                    class="input input-bordered input-sm w-full"
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_input_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add Input
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :matrix_row_pins_input, :string, required: true
  attr :matrix_col_pins_input, :string, required: true
  attr :matrix_errors, :map, required: true

  defp add_matrix_modal(assigns) do
    row_pins = parse_pins(assigns.matrix_row_pins_input)
    col_pins = parse_pins(assigns.matrix_col_pins_input)
    num_rows = length(row_pins)
    num_cols = length(col_pins)
    total_buttons = num_rows * num_cols

    assigns =
      assigns
      |> assign(:num_rows, num_rows)
      |> assign(:num_cols, num_cols)
      |> assign(:total_buttons, total_buttons)
      |> assign(:row_pins, row_pins)
      |> assign(:col_pins, col_pins)

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_matrix_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md mx-4 p-6 max-h-[90vh] overflow-y-auto">
        <h2 class="text-xl font-semibold mb-4">Add Matrix</h2>

        <form phx-change="validate_matrix_pins" phx-submit="add_matrix" class="space-y-4">
          <div class="bg-base-200 rounded-lg p-4">
            <p class="text-sm text-base-content/70 mb-3">
              Enter GPIO pin numbers for rows and columns, separated by commas.
            </p>

            <div class="space-y-3">
              <div>
                <label class="label py-1">
                  <span class="label-text text-sm">Row Pins</span>
                </label>
                <input
                  type="text"
                  name="row_pins"
                  value={@matrix_row_pins_input}
                  placeholder="e.g., 2, 3, 4, 5"
                  phx-debounce="300"
                  class={[
                    "input input-bordered input-sm w-full",
                    @matrix_errors[:row_pins] && "input-error"
                  ]}
                />
                <p :if={@matrix_errors[:row_pins]} class="text-error text-xs mt-1">
                  {@matrix_errors[:row_pins]}
                </p>
              </div>

              <div>
                <label class="label py-1">
                  <span class="label-text text-sm">Column Pins</span>
                </label>
                <input
                  type="text"
                  name="col_pins"
                  value={@matrix_col_pins_input}
                  placeholder="e.g., 8, 9, 10"
                  phx-debounce="300"
                  class={[
                    "input input-bordered input-sm w-full",
                    @matrix_errors[:col_pins] && "input-error"
                  ]}
                />
                <p :if={@matrix_errors[:col_pins]} class="text-error text-xs mt-1">
                  {@matrix_errors[:col_pins]}
                </p>
              </div>

              <p :if={@matrix_errors[:general]} class="text-error text-sm">
                {@matrix_errors[:general]}
              </p>
            </div>
          </div>

          <%!-- Grid Preview --%>
          <div :if={@num_rows > 0 and @num_cols > 0} class="bg-base-200 rounded-lg p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-sm font-medium">Grid Preview</span>
              <span class="badge badge-secondary badge-sm">
                {@num_rows}x{@num_cols} = {@total_buttons} buttons
              </span>
            </div>

            <div class="overflow-x-auto">
              <table class="text-xs">
                <thead>
                  <tr>
                    <th class="p-1"></th>
                    <th
                      :for={{col_pin, col_idx} <- Enum.with_index(@col_pins)}
                      class="p-1 text-center font-mono text-base-content/70"
                    >
                      C{col_idx}<br /><span class="text-[10px]">({col_pin})</span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr :for={{row_pin, row_idx} <- Enum.with_index(@row_pins)}>
                    <td class="p-1 font-mono text-base-content/70">
                      R{row_idx} <span class="text-[10px]">({row_pin})</span>
                    </td>
                    <td :for={{_col_pin, col_idx} <- Enum.with_index(@col_pins)} class="p-1">
                      <div class="w-8 h-6 bg-base-300 rounded flex items-center justify-center text-[10px] font-mono">
                        {128 + row_idx * @num_cols + col_idx}
                      </div>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
            <p class="text-[10px] text-base-content/50 mt-2">
              Virtual pin = 128 + (row x cols + col)
            </p>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_matrix_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add Matrix
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  attr :form, :map, required: true

  defp add_output_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_output_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-xl font-semibold mb-4">Add Output</h2>

        <.form for={@form} phx-change="validate_output" phx-submit="add_output">
          <div class="space-y-4">
            <div>
              <label class="label">
                <span class="label-text">Pin Number</span>
              </label>
              <.input
                field={@form[:pin]}
                type="number"
                placeholder="Enter pin number (0-255)"
                min="0"
                max="255"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <label class="label">
                <span class="label-text">Name (optional)</span>
              </label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="e.g., Brake Warning LED"
                class="input input-bordered w-full"
              />
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_output_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add Output
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  attr :device, :map, required: true
  attr :connected_devices, :list, required: true

  defp apply_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_apply_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-lg font-semibold mb-4">Apply Configuration</h3>
        <p class="text-sm text-base-content/70 mb-6">
          Select a device to apply "<span class="font-medium">{@device.name}</span>" to:
        </p>

        <div class="space-y-2">
          <button
            :for={device <- @connected_devices}
            type="button"
            phx-click="apply_to_device"
            phx-value-port={device.port}
            class="w-full flex items-center gap-3 p-3 rounded-lg border border-base-300 hover:bg-base-200 transition-colors text-left"
          >
            <span class="w-2 h-2 rounded-full bg-success" />
            <div class="min-w-0 flex-1">
              <p class="font-medium truncate">{device.port}</p>
              <p :if={device.device_version} class="text-xs text-base-content/60">
                v{device.device_version}
              </p>
            </div>
          </button>
        </div>

        <div class="mt-6 flex justify-end">
          <button type="button" phx-click="close_apply_modal" class="btn btn-ghost">
            Cancel
          </button>
        </div>
      </div>
    </div>
    """
  end

  attr :device, :map, required: true
  attr :active, :boolean, required: true

  defp delete_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div class="fixed inset-0 bg-black/50" phx-click="close_delete_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl max-w-md w-full p-6">
        <h3 class="text-lg font-semibold mb-4 text-error">Delete Configuration</h3>

        <div :if={@active} class="alert alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span class="text-sm">This configuration is currently active on a connected device.</span>
        </div>

        <p class="text-sm text-base-content/70 mb-6">
          Are you sure you want to delete "<span class="font-medium">{@device.name}</span>"?
          This will permanently delete the configuration and all its inputs and calibration data.
        </p>

        <div class="flex justify-end gap-2">
          <button type="button" phx-click="close_delete_modal" class="btn btn-ghost">
            Cancel
          </button>
          <button
            :if={not @active}
            type="button"
            phx-click="confirm_delete"
            class="btn btn-error"
          >
            <.icon name="hero-trash" class="w-4 h-4" /> Delete
          </button>
        </div>
      </div>
    </div>
    """
  end
end
