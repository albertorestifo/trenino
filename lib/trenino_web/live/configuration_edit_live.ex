defmodule TreninoWeb.ConfigurationEditLive do
  @moduledoc """
  LiveView for editing a configuration.

  Supports both creating new configurations and editing existing ones.
  Configurations can be applied to any connected device.
  """

  alias Trenino.Hardware.StepperManager

  use TreninoWeb, :live_view

  require Logger

  import TreninoWeb.NavComponents
  import TreninoWeb.SharedComponents
  import TreninoWeb.ConfigurationEditLive.Modals
  import TreninoWeb.ConfigurationEditLive.Sections

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session
  alias Trenino.Hardware.{ConfigId, Device, HT16K33, Input, Matrix, Output}
  alias Trenino.Serial.Connection
  alias TreninoWeb.MatrixTestWizard

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
         |> put_flash(
           :error,
           "That configuration link is not valid. Pick a configuration from Devices."
         )
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
       |> assign(:page_title, socket.assigns.device.name)
       |> assign(:new_mode, false)
       |> assign(:inputs, inputs)
       |> assign(:matrices, matrices)
       |> assign(:outputs, outputs)}
    else
      {:error, :invalid} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "That configuration link is not valid. Pick a configuration from Devices."
         )
         |> redirect(to: ~p"/")}

      false ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "That configuration changed while it was opening. Pick it again from Devices."
         )
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
     |> assign(:page_title, "New configuration")
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
     |> assign(:show_delete_modal, false)
     |> assign(:i2c_modules, [])
     |> assign(:stepper_count, 0)
     |> assign(:stepper_axes, [])
     |> assign(:i2c_modal_open, false)
     |> assign(:i2c_modal_module, nil)}
  end

  defp mount_existing(socket, config_id) do
    case Hardware.get_device_by_config_id(config_id) do
      {:ok, device} ->
        maybe_subscribe_on_connect(socket, config_id)
        if connected?(socket), do: StepperManager.subscribe(device.id)

        {:ok, inputs} = Hardware.list_inputs(device.id)
        {:ok, matrices} = Hardware.list_matrices(device.id)
        {:ok, outputs} = Hardware.list_outputs(device.id)
        i2c_modules = Hardware.list_i2c_modules(device.id)
        active_port = find_active_port(config_id)
        input_values = if active_port, do: Hardware.get_input_values(active_port), else: %{}
        changeset = Device.changeset(device, %{})

        {:ok,
         socket
         |> assign(:page_title, device.name)
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
         |> assign(:show_delete_modal, false)
         |> assign(:i2c_modules, i2c_modules)
         |> assign(:stepper_count, length(Hardware.list_stepper_axes(device.id)))
         |> assign(:stepper_axes, Hardware.list_stepper_axes(device.id))
         |> assign(:i2c_modal_open, false)
         |> assign(:i2c_modal_module, nil)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(
           :error,
           "That configuration no longer exists. Pick another one from Devices."
         )
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

  @impl true
  def handle_event("nav_retry_simulator", _, socket) do
    Trenino.Simulator.retry_connection()
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "The input could not be deleted. Try again; if it keeps failing, reload the page."
         )}
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "The output could not be deleted. Try again; if it keeps failing, reload the page."
         )}
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

  # I2C module management
  @impl true
  def handle_event("open_add_i2c_modal", _params, socket) do
    {:noreply, socket |> assign(:i2c_modal_open, true) |> assign(:i2c_modal_module, nil)}
  end

  @impl true
  def handle_event("open_edit_i2c_modal", %{"id" => id_str}, socket) do
    case Hardware.get_i2c_module(String.to_integer(id_str)) do
      {:ok, mod} ->
        {:noreply, socket |> assign(:i2c_modal_open, true) |> assign(:i2c_modal_module, mod)}

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That I2C module no longer exists. Reload the page to see the current list."
         )}
    end
  end

  @impl true
  def handle_event("close_i2c_modal", _params, socket) do
    {:noreply, socket |> assign(:i2c_modal_open, false) |> assign(:i2c_modal_module, nil)}
  end

  @impl true
  def handle_event("delete_i2c_module", %{"id" => id_str}, socket) do
    case Hardware.get_i2c_module(String.to_integer(id_str)) do
      {:ok, mod} ->
        case Hardware.delete_i2c_module(mod) do
          {:ok, _} ->
            i2c_modules = Hardware.list_i2c_modules(socket.assigns.device.id)
            {:noreply, assign(socket, :i2c_modules, i2c_modules)}

          {:error, _reason} ->
            {:noreply,
             put_flash(
               socket,
               :error,
               "The I2C module could not be deleted. Try again; if it keeps failing, reload the page."
             )}
        end

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That I2C module no longer exists. Reload the page to see the current list."
         )}
    end
  end

  @impl true
  def handle_event("test_display", %{"id" => id_str}, socket) do
    mod = Enum.find(socket.assigns.i2c_modules, &(&1.id == String.to_integer(id_str)))

    if mod && socket.assigns.active_port do
      port = socket.assigns.active_port
      texts = display_test_texts(mod.params.num_digits)
      first = List.first(texts)
      bytes = HT16K33.encode_string(first, mod.params)
      Hardware.write_segments(port, mod.i2c_address, bytes)

      texts
      |> Enum.drop(1)
      |> Enum.with_index(1)
      |> Enum.each(fn {_text, step} ->
        Process.send_after(self(), {:display_test_step, mod.id, step}, step * 1000)
      end)
    end

    {:noreply, socket}
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

      {:error, :firmware_update_required} ->
        {:noreply,
         socket
         |> assign(:applying, false)
         |> put_flash(
           :error,
           "Stepper gauges need firmware 3.1 or newer. Update the device firmware, then apply again."
         )}

      {:error, reason} ->
        Logger.error("Failed to apply configuration to #{port}: #{inspect(reason)}")

        {:noreply,
         socket
         |> assign(:applying, false)
         |> put_flash(
           :error,
           "The configuration could not be applied. Check the USB cable and reconnect, then apply again."
         )}
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
         |> put_flash(
           :error,
           "This configuration is active on a connected controller. Disconnect the controller, then delete it."
         )
         |> assign(:show_delete_modal, false)}

      {:error, reason} ->
        Logger.error("Failed to delete configuration #{device.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(
           :error,
           "The configuration could not be deleted. Try again; if it keeps failing, reload the page."
         )
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
      {:noreply, assign(socket, :testing_matrix, MatrixTestWizard.matrix_spec(matrix))}
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "The matrix could not be deleted. Try again; if it keeps failing, reload the page."
         )}
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
          {:noreply,
           put_flash(
             socket,
             :error,
             "The input name could not be saved. Try again; if it keeps failing, reload the page."
           )}
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
          {:noreply,
           put_flash(
             socket,
             :error,
             "The output name could not be saved. Try again; if it keeps failing, reload the page."
           )}
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
          {:noreply,
           put_flash(
             socket,
             :error,
             "The matrix name could not be saved. Try again; if it keeps failing, reload the page."
           )}
      end
    else
      {:noreply, socket}
    end
  end

  # Private helpers for input creation

  defp add_regular_input(socket, params) do
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
      row_pins = Matrix.parse_pins(row_pins_input)
      col_pins = Matrix.parse_pins(col_pins_input)

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
    row_pins = Matrix.parse_pins(row_pins_str)
    col_pins = Matrix.parse_pins(col_pins_str)

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

  defp calibration_failure_message(reason) do
    Logger.error("Calibration failed: #{inspect(reason)}")

    "Calibration failed. Start the calibration again; if it keeps failing, reconnect the controller."
  end

  @doc false
  @spec configuration_failure_message(term()) :: String.t()
  def configuration_failure_message(:timeout),
    do: "The controller did not respond. Check the USB cable and reconnect, then apply again."

  def configuration_failure_message(:device_rejected),
    do: "The controller rejected the configuration. Update the firmware, then apply again."

  def configuration_failure_message(:no_inputs),
    do: "This configuration is empty. Add at least one input, then apply again."

  def configuration_failure_message(reason) do
    Logger.error("Configuration apply failed: #{inspect(reason)}")
    "The configuration could not be applied. Check the USB cable and reconnect, then apply again."
  end

  defp calibration_start_failure_message(reason) do
    Logger.error("Calibration could not start: #{inspect(reason)}")
    "Calibration could not start. Check that the controller is connected, then try again."
  end

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
     |> put_flash(:info, "Calibration saved")}
  end

  @impl true
  def handle_info({:calibration_result, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> assign(:calibrating_input, nil)
     |> put_flash(:error, calibration_failure_message(reason))}
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
     |> put_flash(:error, calibration_start_failure_message(reason))}
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
     |> put_flash(:info, "Configuration applied")}
  end

  @impl true
  def handle_info({:configuration_failed, _port, _device_id, reason}, socket) do
    {:noreply,
     socket
     |> assign(:applying, false)
     |> put_flash(:error, configuration_failure_message(reason))}
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
  def handle_info(:i2c_module_saved, socket) do
    i2c_modules = Hardware.list_i2c_modules(socket.assigns.device.id)

    {:noreply,
     socket
     |> assign(:i2c_modules, i2c_modules)
     |> assign(:i2c_modal_open, false)
     |> assign(:i2c_modal_module, nil)}
  end

  @impl true
  def handle_info({:display_test_step, mod_id, step}, socket) do
    mod = Enum.find(socket.assigns.i2c_modules, &(&1.id == mod_id))

    if mod && socket.assigns.active_port do
      texts = display_test_texts(mod.params.num_digits)

      case Enum.at(texts, step) do
        nil ->
          :ok

        text ->
          bytes = HT16K33.encode_string(text, mod.params)
          Hardware.write_segments(socket.assigns.active_port, mod.i2c_address, bytes)
      end
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:stepper_updated, device_id, snapshot}, socket) do
    if socket.assigns.device.id == device_id do
      send_update(TreninoWeb.StepperAxisFormComponent, id: "stepper-setup", snapshot: snapshot)
    end

    {:noreply, socket}
  end

  def handle_info({:stepper_axis_saved, _axis}, socket) do
    axes = Hardware.list_stepper_axes(socket.assigns.device.id)
    {:noreply, assign(socket, stepper_count: length(axes), stepper_axes: axes)}
  end

  def handle_info({:gauge_wizard_closed, axis_id}, socket) do
    send_update(TreninoWeb.StepperAxisFormComponent, id: "stepper-setup", wizard_closed: axis_id)
    {:noreply, socket}
  end

  def handle_info({:dial_calibration_saved, calibration}, socket) do
    # Re-render the axis list so every axis card shows the saved dial status.
    if Enum.any?(socket.assigns.stepper_axes, &(&1.id == calibration.stepper_axis_id)) do
      send_update(TreninoWeb.StepperAxisFormComponent, id: "stepper-setup", dial_saved: true)
    end

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp display_test_texts(4), do: ["8888", "1234", "ABCD", "    "]
  defp display_test_texts(8), do: ["88888888", "12345678", "ABCDEFGH", "        "]
  defp display_test_texts(_), do: ["8888", "1234", "ABCD", "    "]

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

    assigns =
      assigns
      |> assign(:connected_devices, connected_devices)
      |> assign(:has_parts, has_parts?(assigns))
      |> assign(:apply_needed, apply_needed?(assigns))
      |> assign(:apply_unknown, apply_unknown?(assigns))
      |> assign(:nav_items, nav_items(assigns))

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
          can_apply={@has_parts and not Enum.empty?(@connected_devices)}
          has_parts={@has_parts}
          device_connected={not Enum.empty?(@connected_devices)}
          apply_needed={@apply_needed}
          apply_unknown={@apply_unknown}
          applying={@applying}
        />

        <.section_nav
          :if={not @new_mode}
          label="Hardware configuration sections"
          items={@nav_items}
          class="mt-6"
        />

        <.section_group id="controls-group" title="Controls">
          <.inputs_section
            inputs={@inputs}
            input_values={@input_values}
            active_port={@active_port}
          />

          <.matrices_section matrices={@matrices} active_port={@active_port} />
        </.section_group>

        <.section_group id="feedback-group" title="Feedback">
          <.outputs_section
            outputs={@outputs}
            active_port={@active_port}
            output_states={@output_states}
          />

          <.i2c_modules_section
            i2c_modules={@i2c_modules}
            new_mode={@new_mode}
            active_port={@active_port}
          />

          <.new_gauges_section :if={@new_mode} />

          <.live_component
            :if={not @new_mode}
            module={TreninoWeb.StepperAxisFormComponent}
            id="stepper-setup"
            device_id={@device.id}
          />
        </.section_group>

        <.danger_zone
          :if={not @new_mode}
          action_label="Delete configuration"
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
      allcall_warning={Hardware.allcall_warning(@device.id)}
    />

    <.delete_modal
      :if={@show_delete_modal}
      device={@device}
      active={@active_port != nil}
    />

    <%!-- I2C module modal --%>
    <.i2c_display_modal
      :if={@i2c_modal_open}
      i2c_modal_module={@i2c_modal_module}
      device_id={@device.id}
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
      spec={@testing_matrix}
      port={@active_port}
      input_values={@input_values}
      tested_buttons={@matrix_tested_buttons}
    />
    """
  end

  # Anchor nav entries, one per section, each counting what its section's badge counts.
  defp nav_items(assigns) do
    [
      %{id: "inputs", label: "Inputs", count: length(assigns.inputs)},
      %{id: "matrices", label: "Matrices", count: length(assigns.matrices)},
      %{id: "outputs", label: "Outputs", count: length(assigns.outputs)},
      %{id: "displays", label: "Displays", count: length(assigns.i2c_modules)},
      %{id: "stepper-axes", label: "Gauges", count: assigns.stepper_count}
    ]
  end

  defp has_parts?(assigns) do
    assigns.inputs != [] or assigns.matrices != [] or assigns.i2c_modules != [] or
      assigns.stepper_count > 0
  end

  # The device only learns the configuration on Apply, so compare what is saved now
  # against the fingerprint recorded when the device last confirmed one.
  defp apply_needed?(assigns), do: config_status(assigns) in [:unapplied, :unknown]

  # With no recorded fingerprint (older or never-applied configuration) we cannot tell
  # whether the device matches, so the banner says so instead of claiming a difference.
  defp apply_unknown?(assigns), do: config_status(assigns) == :unknown

  defp config_status(%{new_mode: true}), do: :applied

  defp config_status(assigns) do
    current =
      Hardware.config_fingerprint(
        assigns.inputs,
        assigns.matrices,
        assigns.i2c_modules,
        assigns.stepper_axes
      )

    case Hardware.config_status(assigns.device, current) do
      :unknown -> if has_parts?(assigns), do: :unknown, else: :applied
      status -> status
    end
  end
end
