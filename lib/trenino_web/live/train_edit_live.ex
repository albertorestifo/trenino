defmodule TreninoWeb.TrainEditLive do
  @moduledoc """
  LiveView for editing a train configuration.

  Supports both creating new trains and editing existing ones.
  Allows managing train elements (levers, etc.) and their configurations.
  """

  alias Trenino.Train.GaugeController

  use TreninoWeb, :live_view

  require Logger

  import TreninoWeb.NavComponents
  import TreninoWeb.SharedComponents

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.ControlDetectionSession
  alias Trenino.Train, as: TrainContext

  alias Trenino.Train.{
    ButtonController,
    DisplayController,
    Element,
    Identifier,
    LeverConfig,
    LeverInputBinding,
    OutputController,
    Train,
    TrainIdentifier
  }

  alias Trenino.Train.LeverController
  alias Trenino.Train.ScriptRunner
  alias TreninoWeb.SequenceManagerComponent

  @impl true
  def mount(%{"train_id" => "new"} = params, _session, socket) do
    mount_new(socket, params)
  end

  @impl true
  def mount(%{"train_id" => train_id_str}, _session, socket) do
    case Integer.parse(train_id_str) do
      {train_id, ""} ->
        mount_existing(socket, train_id)

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid train ID")
         |> redirect(to: ~p"/trains")}
    end
  end

  defp mount_new(socket, params) do
    if connected?(socket) do
      TrainContext.subscribe()
    end

    # Check for pre-filled identifier from URL query params
    identifier = params["identifier"] || ""

    # Extract a suggested name from the identifier if present
    suggested_name =
      if identifier != "" do
        Identifier.extract_train_name(identifier)
      else
        ""
      end

    train = %Train{
      name: suggested_name,
      description: nil,
      identifiers: [%TrainIdentifier{identifier: identifier}]
    }

    changeset = Train.changeset(train, %{})

    {:ok,
     socket
     |> assign(:train, train)
     |> assign(:train_form, to_form(changeset))
     |> assign(:elements, [])
     |> assign(:new_mode, true)
     |> assign(:active_train, TrainContext.get_active_train())
     |> assign(:current_identifier, TrainContext.get_current_identifier())
     |> assign(:display_hardware_available, Hardware.list_all_i2c_modules() != [])
     |> assign(:modal_open, false)
     |> assign(:element_form, to_form(Element.changeset(%Element{}, %{type: :lever})))
     |> assign(:show_delete_modal, false)
     |> assign(:show_api_explorer, false)
     |> assign(:api_explorer_field, nil)
     |> assign(:binding_button_element, nil)
     |> assign(:available_button_inputs, [])
     |> assign(:show_config_wizard, false)
     |> assign(:config_wizard_element, nil)
     |> assign(:config_wizard_mode, nil)
     |> assign(:config_wizard_event, nil)
     |> assign(:show_lever_setup_wizard, false)
     |> assign(:lever_setup_element, nil)
     |> assign(:lever_setup_event, nil)
     |> assign(:sequences, [])
     |> assign(:output_bindings, [])
     |> assign(:show_output_wizard, false)
     |> assign(:output_wizard_binding, nil)
     |> assign(:output_wizard_event, nil)
     |> assign(:available_outputs, [])
     |> assign(:display_bindings, [])
     |> assign(:show_display_wizard, false)
     |> assign(:display_wizard_binding, nil)
     |> assign(:display_wizard_event, nil)
     |> assign(:sequence_manager_event, nil)
     |> assign(:value_polling_target, nil)
     |> assign(:scripts, [])}
  end

  defp mount_existing(socket, train_id) do
    case TrainContext.get_train(train_id,
           preload: [
             :identifiers,
             elements: [
               lever_config: [:notches, input_binding: [input: :device]],
               button_binding: [input: :device]
             ]
           ]
         ) do
      {:ok, train} ->
        if connected?(socket) do
          TrainContext.subscribe()
        end

        changeset = Train.changeset(train, %{})
        sequences = TrainContext.list_sequences(train.id)
        output_bindings = TrainContext.list_output_bindings(train.id)
        display_bindings = TrainContext.list_display_bindings(train.id)
        if connected?(socket), do: GaugeController.subscribe(train.id)
        scripts = TrainContext.list_scripts(train.id)
        available_outputs = load_available_outputs()

        {:ok,
         socket
         |> assign(:train, train)
         |> assign(:train_form, to_form(changeset))
         |> assign(:elements, train.elements)
         |> assign(:new_mode, false)
         |> assign(:active_train, TrainContext.get_active_train())
         |> assign(:current_identifier, TrainContext.get_current_identifier())
         |> assign(:display_hardware_available, Hardware.list_all_i2c_modules() != [])
         |> assign(:modal_open, false)
         |> assign(:element_form, to_form(Element.changeset(%Element{}, %{type: :lever})))
         |> assign(:show_delete_modal, false)
         |> assign(:show_api_explorer, false)
         |> assign(:api_explorer_field, nil)
         |> assign(:binding_button_element, nil)
         |> assign(:available_button_inputs, [])
         |> assign(:show_config_wizard, false)
         |> assign(:config_wizard_element, nil)
         |> assign(:config_wizard_mode, nil)
         |> assign(:config_wizard_event, nil)
         |> assign(:show_lever_setup_wizard, false)
         |> assign(:lever_setup_element, nil)
         |> assign(:lever_setup_event, nil)
         |> assign(:sequences, sequences)
         |> assign(:output_bindings, output_bindings)
         |> assign(:show_output_wizard, false)
         |> assign(:output_wizard_binding, nil)
         |> assign(:output_wizard_event, nil)
         |> assign(:available_outputs, available_outputs)
         |> assign(:display_bindings, display_bindings)
         |> assign(:show_display_wizard, false)
         |> assign(:display_wizard_binding, nil)
         |> assign(:display_wizard_event, nil)
         |> assign(:sequence_manager_event, nil)
         |> assign(:value_polling_target, nil)
         |> assign(:scripts, scripts)}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Train not found")
         |> redirect(to: ~p"/trains")}
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

  # Train name/description editing
  @impl true
  def handle_event("validate_train", %{"train" => params}, socket) do
    changeset =
      socket.assigns.train
      |> Train.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :train_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_train", %{"train" => params}, socket) do
    save_train(socket, params)
  end

  @impl true
  def handle_event("use_current_train_id", _params, socket) do
    identifier = socket.assigns.current_identifier

    if socket.assigns.nav_simulator_status.status == :connected and is_binary(identifier) and
         identifier != "" do
      changeset = socket.assigns.train_form.source
      identifiers = Ecto.Changeset.get_field(changeset, :identifiers, [])
      values = Enum.map(identifiers, & &1.identifier)

      identifiers =
        cond do
          identifier in values -> identifiers
          values == [""] or values == [nil] -> [%TrainIdentifier{identifier: identifier}]
          true -> identifiers ++ [%TrainIdentifier{identifier: identifier}]
        end

      params = %{
        "name" => Ecto.Changeset.get_field(changeset, :name),
        "description" => Ecto.Changeset.get_field(changeset, :description),
        "identifiers" => Enum.map(identifiers, &Map.take(&1, [:id, :identifier]))
      }

      changeset = Train.changeset(socket.assigns.train, params)

      {:noreply, assign(socket, :train_form, to_form(changeset))}
    else
      {:noreply, socket}
    end
  end

  # Element management
  @impl true
  def handle_event("open_add_element_modal", _params, socket) do
    {:noreply, assign(socket, :modal_open, true)}
  end

  @impl true
  def handle_event("close_add_element_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:modal_open, false)
     |> assign(:element_form, to_form(Element.changeset(%Element{}, %{type: :lever})))}
  end

  @impl true
  def handle_event("validate_element", %{"element" => params}, socket) do
    changeset =
      %Element{}
      |> Element.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :element_form, to_form(changeset))}
  end

  @impl true
  def handle_event("add_element", %{"element" => params}, socket) do
    case TrainContext.create_element(socket.assigns.train.id, params) do
      {:ok, element} ->
        {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)

        socket =
          socket
          |> assign(:elements, elements)
          |> assign(:modal_open, false)
          |> assign(:element_form, to_form(Element.changeset(%Element{}, %{type: :lever})))

        # Automatically open configuration wizard if simulator is connected
        simulator_status = socket.assigns.nav_simulator_status

        if simulator_status.status == :connected and simulator_status.client != nil do
          open_config_wizard_for_element(socket, element)
        else
          {:noreply, socket}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :element_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("delete_element", %{"id" => id}, socket) do
    case TrainContext.get_element(String.to_integer(id)) do
      {:ok, element} ->
        case TrainContext.delete_element(element) do
          {:ok, _} ->
            {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)
            {:noreply, assign(socket, :elements, elements)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete element")}
        end

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Element not found")}
    end
  end

  # Lever configuration - requires simulator to be connected
  @impl true
  def handle_event("configure_lever", %{"id" => id}, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status != :connected or simulator_status.client == nil do
      {:noreply, put_flash(socket, :error, "Connect to the simulator to configure elements")}
    else
      open_lever_config_wizard(socket, String.to_integer(id))
    end
  end

  # Button configuration - requires simulator to be connected
  @impl true
  def handle_event("configure_button", %{"id" => id}, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status != :connected or simulator_status.client == nil do
      {:noreply, put_flash(socket, :error, "Connect to the simulator to configure elements")}
    else
      open_button_config_wizard(socket, String.to_integer(id))
    end
  end

  # Delete train
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
    train = socket.assigns.train

    case TrainContext.delete_train(train) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Train \"#{train.name}\" deleted")
         |> redirect(to: ~p"/trains")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete: #{inspect(reason)}")
         |> assign(:show_delete_modal, false)}
    end
  end

  # API Explorer events
  @impl true
  def handle_event("open_api_explorer", %{"field" => field}, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status == :connected and simulator_status.client != nil do
      {:noreply,
       socket
       |> assign(:show_api_explorer, true)
       |> assign(:api_explorer_field, String.to_existing_atom(field))}
    else
      {:noreply, put_flash(socket, :error, "Simulator not connected")}
    end
  end

  # Output binding events
  @impl true
  def handle_event("open_add_output_binding", _params, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status != :connected or simulator_status.client == nil do
      {:noreply, put_flash(socket, :error, "Connect to the simulator to add output bindings")}
    else
      if Enum.empty?(socket.assigns.available_outputs) do
        {:noreply,
         put_flash(socket, :error, "No outputs configured. Add outputs to a device first.")}
      else
        {:noreply,
         socket
         |> assign(:show_output_wizard, true)
         |> assign(:output_wizard_binding, nil)}
      end
    end
  end

  @impl true
  def handle_event("configure_output_binding", %{"id" => id_str}, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status != :connected or simulator_status.client == nil do
      {:noreply,
       put_flash(socket, :error, "Connect to the simulator to configure output bindings")}
    else
      case TrainContext.get_output_binding(String.to_integer(id_str)) do
        {:ok, binding} ->
          {:noreply,
           socket
           |> assign(:show_output_wizard, true)
           |> assign(:output_wizard_binding, binding)}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Output binding not found")}
      end
    end
  end

  @impl true
  def handle_event("delete_output_binding", %{"id" => id_str}, socket) do
    case TrainContext.get_output_binding(String.to_integer(id_str)) do
      {:ok, binding} ->
        case TrainContext.delete_output_binding(binding) do
          {:ok, _} ->
            OutputController.reload_bindings()
            output_bindings = TrainContext.list_output_bindings(socket.assigns.train.id)
            {:noreply, assign(socket, :output_bindings, output_bindings)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete output binding")}
        end

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Output binding not found")}
    end
  end

  # Display binding events
  @impl true
  def handle_event("open_add_display_binding", _params, socket) do
    simulator_status = socket.assigns.nav_simulator_status

    if simulator_status.status != :connected or simulator_status.client == nil or
         not socket.assigns.display_hardware_available do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Connect the simulator and add a hardware display before creating a binding"
       )}
    else
      {:noreply,
       socket |> assign(:show_display_wizard, true) |> assign(:display_wizard_binding, nil)}
    end
  end

  @impl true
  def handle_event("configure_display_binding", %{"id" => id_str}, socket) do
    case TrainContext.get_display_binding(String.to_integer(id_str)) do
      {:ok, binding} ->
        {:noreply,
         socket |> assign(:show_display_wizard, true) |> assign(:display_wizard_binding, binding)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Display binding not found")}
    end
  end

  @impl true
  def handle_event("delete_display_binding", %{"id" => id_str}, socket) do
    case TrainContext.get_display_binding(String.to_integer(id_str)) do
      {:ok, binding} ->
        case TrainContext.delete_display_binding(binding) do
          {:ok, _} ->
            DisplayController.reload_bindings()
            display_bindings = TrainContext.list_display_bindings(socket.assigns.train.id)
            {:noreply, assign(socket, :display_bindings, display_bindings)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete display binding")}
        end

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Display binding not found")}
    end
  end

  # Script events
  @impl true
  def handle_event("toggle_script_enabled", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case TrainContext.get_script(id) do
      {:ok, script} ->
        {:ok, _} = TrainContext.update_script(script, %{enabled: !script.enabled})
        ScriptRunner.reload_scripts()
        scripts = TrainContext.list_scripts(socket.assigns.train.id)
        {:noreply, assign(socket, :scripts, scripts)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Script not found")}
    end
  end

  @impl true
  def handle_event("delete_script", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case TrainContext.get_script(id) do
      {:ok, script} ->
        {:ok, _} = TrainContext.delete_script(script)
        ScriptRunner.reload_scripts()
        scripts = TrainContext.list_scripts(socket.assigns.train.id)
        {:noreply, assign(socket, :scripts, scripts)}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Script not found")}
    end
  end

  # PubSub events
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  @impl true
  def handle_info({:train_detected, %{train: train} = detected}, socket) do
    {:noreply,
     socket
     |> assign(:active_train, train)
     |> assign(
       :current_identifier,
       Map.get(detected, :identifier, socket.assigns.current_identifier)
     )}
  end

  @impl true
  def handle_info({:multiple_trains_match, %{identifier: identifier}}, socket) do
    {:noreply, assign(socket, :current_identifier, identifier)}
  end

  @impl true
  def handle_info({:train_changed, train}, socket) do
    {:noreply, assign(socket, :active_train, train)}
  end

  @impl true
  def handle_info({:detection_error, reason}, socket) do
    component_id = socket.assigns[:auto_detect_component_id]

    if component_id do
      send_update(TreninoWeb.AutoDetectComponent,
        id: component_id,
        detection_result: {:error, reason}
      )
    end

    {:noreply, socket}
  end

  # Auto-detect: start session asynchronously
  @impl true
  def handle_info({:start_detection_session, component_id, client}, socket) do
    result = ControlDetectionSession.start(client, self())

    send_update(TreninoWeb.AutoDetectComponent,
      id: component_id,
      session_started: result
    )

    # Start countdown timer if session started successfully
    # Also store the component ID for later updates
    socket =
      if match?({:ok, _}, result) do
        Process.send_after(self(), {:tick_countdown, component_id}, 1000)
        assign(socket, :auto_detect_component_id, component_id)
      else
        socket
      end

    {:noreply, socket}
  end

  # Auto-detect control messages from ControlDetectionSession
  @impl true
  def handle_info({:control_detected, changes}, socket) do
    component_id = socket.assigns[:auto_detect_component_id]

    if component_id do
      send_update(TreninoWeb.AutoDetectComponent,
        id: component_id,
        detection_result: {:detected, changes}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:detection_timeout}, socket) do
    component_id = socket.assigns[:auto_detect_component_id]

    if component_id do
      send_update(TreninoWeb.AutoDetectComponent,
        id: component_id,
        detection_result: :timeout
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:tick_countdown, component_id}, socket) do
    remaining = Map.get(socket.assigns, :auto_detect_countdown, 30) - 1

    if remaining > 0 and socket.assigns[:show_auto_detect] do
      send_update(TreninoWeb.AutoDetectComponent,
        id: component_id,
        countdown_tick: remaining
      )

      Process.send_after(self(), {:tick_countdown, component_id}, 1000)
      {:noreply, assign(socket, :auto_detect_countdown, remaining)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:auto_detect_selected, change}, socket) do
    # Forward to appropriate wizard
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply,
         socket
         |> assign(:show_auto_detect, false)
         |> assign(:auto_detect_status, nil)
         |> assign(:lever_setup_event, {:auto_detect_result, change})}

      socket.assigns.show_config_wizard ->
        {:noreply,
         socket
         |> assign(:show_auto_detect, false)
         |> assign(:auto_detect_status, nil)
         |> assign(:config_wizard_event, {:auto_detect_result, change})}

      true ->
        # Try forwarding to EndpointSelectorComponent (used by SequenceManagerComponent)
        send_update(TreninoWeb.EndpointSelectorComponent,
          id: "sequence-command-endpoint-selector",
          explorer_event: {:auto_detect_result, change}
        )

        {:noreply, assign(socket, :show_auto_detect, false)}
    end
  end

  @impl true
  def handle_info({:auto_detect_cancelled}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply,
         socket
         |> assign(:show_auto_detect, false)
         |> assign(:auto_detect_status, nil)
         |> assign(:lever_setup_event, :auto_detect_cancelled)}

      socket.assigns.show_config_wizard ->
        {:noreply,
         socket
         |> assign(:show_auto_detect, false)
         |> assign(:auto_detect_status, nil)
         |> assign(:config_wizard_event, :auto_detect_cancelled)}

      true ->
        # Try forwarding to EndpointSelectorComponent (used by SequenceManagerComponent)
        send_update(TreninoWeb.EndpointSelectorComponent,
          id: "sequence-command-endpoint-selector",
          explorer_event: :auto_detect_cancelled
        )

        {:noreply,
         socket
         |> assign(:show_auto_detect, false)
         |> assign(:auto_detect_status, nil)}
    end
  end

  # Notch mapping session events - forward to appropriate wizard
  @impl true
  def handle_info({:session_started, state}, socket) do
    forward_mapping_state(socket, state)
  end

  @impl true
  def handle_info({:step_changed, state}, socket) do
    forward_mapping_state(socket, state)
  end

  @impl true
  def handle_info({:sample_updated, state}, socket) do
    forward_mapping_state(socket, state)
  end

  @impl true
  def handle_info({:capture_started, state}, socket) do
    forward_mapping_state(socket, state)
  end

  @impl true
  def handle_info({:capture_stopped, state}, socket) do
    forward_mapping_state(socket, state)
  end

  @impl true
  def handle_info({:mapping_result, {:ok, _updated_config}}, socket) do
    {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)
    LeverController.reload_bindings()

    {:noreply, assign(socket, :elements, elements)}
  end

  @impl true
  def handle_info({:mapping_result, {:error, _reason}}, socket) do
    {:noreply, socket}
  end

  # API Explorer component events - forward to appropriate wizard
  @impl true
  def handle_info({:api_explorer_select, "gauge:" <> _ = field, path}, socket) do
    send_update(TreninoWeb.GaugeBindingWizard, id: "gauge-setup", explorer_event: {field, path})
    {:noreply, socket}
  end

  def handle_info({:api_explorer_select, field, path}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply, assign(socket, :lever_setup_event, {:select, field, path})}

      socket.assigns.show_config_wizard ->
        {:noreply, assign(socket, :config_wizard_event, {:select, field, path})}

      socket.assigns.show_output_wizard ->
        {:noreply, assign(socket, :output_wizard_event, {:select, field, path})}

      socket.assigns.show_display_wizard ->
        {:noreply, assign(socket, :display_wizard_event, {:select, field, path})}

      true ->
        # Try forwarding to EndpointSelectorComponent (used by SequenceManagerComponent)
        send_update(TreninoWeb.EndpointSelectorComponent,
          id: "sequence-command-endpoint-selector",
          explorer_event: {:select, field, path}
        )

        {:noreply,
         socket
         |> assign(:show_api_explorer, false)
         |> assign(:api_explorer_field, nil)}
    end
  end

  @impl true
  def handle_info({:api_explorer_close}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply, assign(socket, :lever_setup_event, :close)}

      socket.assigns.show_config_wizard ->
        {:noreply, assign(socket, :config_wizard_event, :close)}

      socket.assigns.show_output_wizard ->
        {:noreply, assign(socket, :output_wizard_event, :close)}

      socket.assigns.show_display_wizard ->
        {:noreply, assign(socket, :display_wizard_event, :close)}

      true ->
        # Try forwarding to EndpointSelectorComponent (used by SequenceManagerComponent)
        send_update(TreninoWeb.EndpointSelectorComponent,
          id: "sequence-command-endpoint-selector",
          explorer_event: :close
        )

        {:noreply,
         socket
         |> assign(:show_api_explorer, false)
         |> assign(:api_explorer_field, nil)}
    end
  end

  @impl true
  def handle_info({:api_explorer_auto_configure, endpoints}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply, assign(socket, :lever_setup_event, {:auto_configure, endpoints})}

      socket.assigns.show_config_wizard ->
        {:noreply, assign(socket, :config_wizard_event, {:auto_configure, endpoints})}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:api_explorer_individual_selection}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply, assign(socket, :lever_setup_event, :individual_selection)}

      socket.assigns.show_config_wizard ->
        {:noreply, assign(socket, :config_wizard_event, :individual_selection)}

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:api_explorer_button_detected, detection}, socket) do
    if socket.assigns.show_config_wizard do
      {:noreply, assign(socket, :config_wizard_event, {:button_detected, detection})}
    else
      # Forward to EndpointSelectorComponent (used by SequenceManagerComponent)
      # Convert button detection to a select event with the endpoint path
      send_update(TreninoWeb.EndpointSelectorComponent,
        id: "sequence-command-endpoint-selector",
        explorer_event: {:select, :endpoint, detection.endpoint}
      )

      {:noreply, socket}
    end
  end

  # Configuration wizard completion events
  @impl true
  def handle_info({:configuration_complete, element_id, :ok}, socket) do
    {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)

    # Reload controller bindings based on type
    element = Enum.find(elements, &(&1.id == element_id))

    if element do
      case element.type do
        :lever -> LeverController.reload_bindings()
        :button -> ButtonController.reload_bindings()
        _ -> :ok
      end
    end

    {:noreply,
     socket
     |> assign(:elements, elements)
     |> assign(:show_config_wizard, false)
     |> assign(:config_wizard_element, nil)
     |> assign(:config_wizard_mode, nil)
     |> assign(:config_wizard_event, nil)
     |> put_flash(:info, "Configuration saved")}
  end

  @impl true
  def handle_info({:configuration_cancelled, _element_id}, socket) do
    cancel_value_polling(socket)

    {:noreply,
     socket
     |> assign(:show_config_wizard, false)
     |> assign(:config_wizard_element, nil)
     |> assign(:config_wizard_mode, nil)
     |> assign(:config_wizard_event, nil)
     |> assign(:button_detection_inputs, nil)
     |> assign(:value_polling_timer, nil)}
  end

  # Output binding wizard events
  @impl true
  def handle_info({:output_binding_saved, _binding}, socket) do
    output_bindings = TrainContext.list_output_bindings(socket.assigns.train.id)

    {:noreply,
     socket
     |> assign(:output_bindings, output_bindings)
     |> assign(:show_output_wizard, false)
     |> assign(:output_wizard_binding, nil)
     |> assign(:output_wizard_event, nil)
     |> put_flash(:info, "Output binding saved")}
  end

  @impl true
  def handle_info(:output_binding_cancelled, socket) do
    {:noreply,
     socket
     |> assign(:show_output_wizard, false)
     |> assign(:output_wizard_binding, nil)
     |> assign(:output_wizard_event, nil)}
  end

  # Display binding wizard events
  @impl true
  def handle_info({:display_binding_saved, _binding}, socket) do
    display_bindings = TrainContext.list_display_bindings(socket.assigns.train.id)

    {:noreply,
     socket
     |> assign(:display_bindings, display_bindings)
     |> assign(:show_display_wizard, false)
     |> assign(:display_wizard_binding, nil)
     |> assign(:display_wizard_event, nil)}
  end

  @impl true
  def handle_info(:display_binding_cancelled, socket) do
    {:noreply,
     socket
     |> assign(:show_display_wizard, false)
     |> assign(:display_wizard_binding, nil)
     |> assign(:display_wizard_event, nil)}
  end

  # Value polling for button ON/OFF detection using API subscriptions
  # Subscription ID 999 is reserved for button value detection
  @value_detection_subscription_id 999

  @impl true
  def handle_info({:start_value_polling, endpoint}, socket) do
    client = socket.assigns.nav_simulator_status.client
    cancel_value_polling(socket)

    Logger.debug("[ValuePolling] Attempting to subscribe to: #{inspect(endpoint)}")

    # Determine polling target based on which component is active
    polling_target =
      if socket.assigns.show_config_wizard, do: :config_wizard, else: :endpoint_selector

    if client && endpoint do
      # Clean up any existing subscription and create a new one
      SimulatorClient.unsubscribe(client, @value_detection_subscription_id)

      case SimulatorClient.subscribe(client, endpoint, @value_detection_subscription_id) do
        {:ok, _} ->
          Logger.info("[ValuePolling] Subscribed to #{endpoint}")
          # Start polling the subscription (every 200ms)
          {:ok, timer_ref} = :timer.send_interval(200, :poll_value_subscription)

          {:noreply,
           socket
           |> assign(:value_polling_timer, timer_ref)
           |> assign(:value_polling_target, polling_target)}

        {:error, reason} ->
          Logger.warning("[ValuePolling] Failed to subscribe: #{inspect(reason)}")
          {:noreply, socket}
      end
    else
      Logger.warning("[ValuePolling] Missing client or endpoint")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:stop_value_polling, socket) do
    client = socket.assigns.nav_simulator_status.client
    cancel_value_polling(socket)

    # Clean up subscription
    if client do
      SimulatorClient.unsubscribe(client, @value_detection_subscription_id)
    end

    {:noreply, assign(socket, :value_polling_timer, nil)}
  end

  @impl true
  def handle_info(:poll_value_subscription, socket) do
    client = socket.assigns.nav_simulator_status.client
    polling_target = socket.assigns[:value_polling_target] || :config_wizard

    if client do
      case SimulatorClient.get_subscription(client, @value_detection_subscription_id) do
        {:ok, %{"Entries" => [%{"Values" => values} | _]}} when map_size(values) > 0 ->
          value =
            values
            |> Map.values()
            |> List.first()
            |> then(&Float.round(&1 * 1.0, 2))

          send_polled_value_to_component(polling_target, value)

        {:ok, response} ->
          Logger.debug("[ValuePolling] Unexpected response: #{inspect(response)}")
          :ok

        {:error, _reason} ->
          :ok
      end
    end

    {:noreply, socket}
  end

  # Lever setup wizard events
  @impl true
  def handle_info({:lever_setup_complete, element_id}, socket) do
    {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)
    LeverController.reload_bindings()

    # Close the wizard and update element list
    {:noreply,
     socket
     |> assign(:elements, elements)
     |> assign(:show_lever_setup_wizard, false)
     |> assign(:lever_setup_element, nil)
     |> assign(:lever_setup_event, nil)
     |> put_flash(
       :info,
       "Lever '#{get_element_name(elements, element_id)}' configured successfully"
     )}
  end

  @impl true
  def handle_info({:lever_setup_cancelled, _element_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_lever_setup_wizard, false)
     |> assign(:lever_setup_element, nil)
     |> assign(:lever_setup_event, nil)}
  end

  @impl true
  def handle_info({:run_lever_calibration, element_id, control_path, config_params}, socket) do
    # Run lever calibration and send result back to wizard
    client = socket.assigns.nav_simulator_status.client
    element = socket.assigns.lever_setup_element

    result =
      if client && element && element.id == element_id do
        run_lever_calibration(client, control_path, element, config_params)
      else
        {:error, :invalid_state}
      end

    send_update(TreninoWeb.LeverSetupWizard,
      id: "lever-setup-wizard",
      calibration_result: result
    )

    {:noreply, socket}
  end

  # Button detection for configuration wizard
  @impl true
  def handle_info({:start_button_detection, available_inputs}, socket) do
    # Build lookup of pin -> input_id for quick detection
    # Subscribe to input values from all ports that have button inputs
    ports =
      available_inputs
      |> Enum.map(& &1.device.config_id)
      |> Enum.uniq()
      |> Enum.map(&ConfigurationManager.config_id_to_port/1)
      |> Enum.reject(&is_nil/1)

    Enum.each(ports, &Hardware.subscribe_input_values/1)

    # Build a lookup map: {config_id, pin} -> input_id
    input_lookup =
      available_inputs
      |> Enum.map(fn input ->
        {{input.device.config_id, input.pin}, input.id}
      end)
      |> Map.new()

    {:noreply, assign(socket, :button_detection_inputs, input_lookup)}
  end

  @impl true
  def handle_info(:stop_button_detection, socket) do
    {:noreply, assign(socket, :button_detection_inputs, nil)}
  end

  @impl true
  def handle_info({:input_value_updated, port, pin, value}, socket) do
    # Check if we're in button detection mode and a button was pressed
    if socket.assigns[:button_detection_inputs] && value == 1 do
      # Look up which input this corresponds to
      config_id = ConfigurationManager.port_to_config_id(port)

      case Map.get(socket.assigns.button_detection_inputs, {config_id, pin}) do
        nil ->
          {:noreply, socket}

        input_id ->
          # Found the button! Send to wizard component
          send_update(TreninoWeb.ConfigurationWizardComponent,
            id: "config-wizard",
            button_detected_input_id: input_id
          )

          {:noreply, assign(socket, :button_detection_inputs, nil)}
      end
    else
      {:noreply, socket}
    end
  end

  # Sequence manager component events
  @impl true
  def handle_info({SequenceManagerComponent, :sequences_changed}, socket) do
    sequences = TrainContext.list_sequences(socket.assigns.train.id)
    {:noreply, assign(socket, :sequences, sequences)}
  end

  # EndpointSelectorComponent events - forward to SequenceManagerComponent
  @impl true
  def handle_info(
        {:endpoint_selector, "sequence-command-endpoint-selector", _event} = full_event,
        socket
      ) do
    {:noreply, assign(socket, :sequence_manager_event, full_event)}
  end

  @impl true
  def handle_info({:gauge_binding_updated, id, status}, socket) do
    send_update(TreninoWeb.GaugeBindingWizard, id: "gauge-setup", runtime_event: {id, status})
    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # Private functions

  defp send_polled_value_to_component(:config_wizard, value) do
    send_update(TreninoWeb.ConfigurationWizardComponent,
      id: "config-wizard",
      value_polling_result: value
    )
  end

  defp send_polled_value_to_component(:endpoint_selector, value) do
    send_update(TreninoWeb.EndpointSelectorComponent,
      id: "sequence-command-endpoint-selector",
      value_polling_result: value
    )
  end

  defp forward_mapping_state(socket, state) do
    if socket.assigns.show_lever_setup_wizard do
      send_update(TreninoWeb.LeverSetupWizard,
        id: "lever-setup-wizard",
        mapping_state_update: state
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp run_lever_calibration(client, control_path, element, config_params) do
    alias Trenino.Simulator.LeverAnalyzer
    alias Trenino.Train

    case LeverAnalyzer.analyze(client, control_path, restore_position: nil) do
      {:ok, analysis_result} ->
        # Check database for existing config (not the stale preloaded data)
        # This handles re-calibration within the same wizard session
        case Train.get_lever_config(element.id) do
          {:ok, existing_config} ->
            Train.update_lever_config_with_analysis(
              existing_config,
              config_params,
              analysis_result
            )

          {:error, :not_found} ->
            Train.create_lever_config_with_analysis(element.id, config_params, analysis_result)
        end

      {:error, _reason} = error ->
        error
    end
  end

  defp open_config_wizard_for_element(socket, %Element{type: :lever} = element) do
    open_lever_config_wizard(socket, element.id)
  end

  defp open_config_wizard_for_element(socket, %Element{type: :button} = element) do
    open_button_config_wizard(socket, element.id)
  end

  defp open_lever_config_wizard(socket, element_id) do
    case TrainContext.get_element(element_id,
           preload: [
             lever_config: [:notches, input_binding: [input: [device: [], calibration: []]]]
           ]
         ) do
      {:ok, element} ->
        {:noreply,
         socket
         |> assign(:show_lever_setup_wizard, true)
         |> assign(:lever_setup_element, element)
         |> assign(:lever_setup_event, nil)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp open_button_config_wizard(socket, element_id) do
    case TrainContext.get_element(element_id, preload: [button_binding: [input: :device]]) do
      {:ok, element} ->
        available_inputs =
          Hardware.list_all_inputs(include_uncalibrated: true, include_virtual_buttons: true)

        button_inputs = Enum.filter(available_inputs, &(&1.input_type == :button))
        sequences = TrainContext.list_sequences(socket.assigns.train.id)

        {:noreply,
         socket
         |> assign(:show_api_explorer, false)
         |> assign(:show_config_wizard, true)
         |> assign(:config_wizard_element, element)
         |> assign(:config_wizard_mode, :button)
         |> assign(:config_wizard_event, nil)
         |> assign(:available_button_inputs, button_inputs)
         |> assign(:sequences, sequences)}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp get_element_name(elements, element_id) do
    case Enum.find(elements, &(&1.id == element_id)) do
      nil -> "Element"
      element -> element.name
    end
  end

  defp cancel_value_polling(socket) do
    if timer_ref = socket.assigns[:value_polling_timer] do
      :timer.cancel(timer_ref)
    end
  end

  defp save_train(%{assigns: %{new_mode: true}} = socket, params) do
    case TrainContext.create_train(params) do
      {:ok, train} ->
        # Sync detection to check if the new train matches current simulator state
        TrainContext.sync()

        {:noreply,
         socket
         |> put_flash(:info, "Train created")
         |> redirect(to: ~p"/trains/#{train.id}")}

      {:error, changeset} ->
        {:noreply, assign(socket, :train_form, to_form(changeset))}
    end
  end

  defp save_train(socket, params) do
    case TrainContext.update_train(socket.assigns.train, params) do
      {:ok, train} ->
        changeset = Train.changeset(train, %{})

        {:noreply,
         socket
         |> assign(:train, train)
         |> assign(:train_form, to_form(changeset))
         |> put_flash(:info, "Train saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, :train_form, to_form(changeset))}
    end
  end

  defp load_available_outputs do
    devices = Hardware.list_configurations(preload: :outputs)

    devices
    |> Enum.flat_map(fn device ->
      Enum.map(device.outputs, fn output ->
        %{output | device: device}
      end)
    end)
  end

  # Render

  @impl true
  def render(assigns) do
    is_active =
      assigns.active_train != nil and
        assigns.train.id != nil and
        assigns.active_train.id == assigns.train.id

    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <.breadcrumb items={[
      %{label: "Trains", path: ~p"/trains"},
      %{label: if(@new_mode, do: "New train", else: @train.name)}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <.train_header
          train={@train}
          train_form={@train_form}
          is_active={@is_active}
          new_mode={@new_mode}
          current_identifier={@current_identifier}
          simulator_connected={@nav_simulator_status.status == :connected}
        />

        <div
          :if={not @new_mode and @nav_simulator_status.status != :connected}
          class="alert alert-warning mt-6"
        >
          <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
          <span>
            Simulator not connected. Connect to the simulator to configure elements and test sequences.
          </span>
        </div>

        <nav
          :if={not @new_mode}
          aria-label="Train configuration sections"
          class="flex flex-wrap gap-2 mt-6 border-b border-base-300 pb-3 text-sm"
        >
          <a href="#controls" class="btn btn-ghost btn-sm">Controls</a>
          <a href="#displays-lights" class="btn btn-ghost btn-sm">Displays &amp; lights</a>
          <a href="#automation" class="btn btn-ghost btn-sm">Automation</a>
        </nav>

        <section
          :if={not @new_mode}
          id="controls"
          class="scroll-mt-36 mt-6"
          aria-labelledby="controls-title"
        >
          <h2 id="controls-title" class="text-lg font-semibold mb-3">Controls</h2>
          <div class="bg-base-200/50 rounded-xl p-4 sm:p-6">
            <.elements_section elements={@elements} is_active={@is_active} />
          </div>
        </section>

        <section
          :if={not @new_mode}
          id="displays-lights"
          class="scroll-mt-36 mt-8"
          aria-labelledby="displays-lights-title"
        >
          <h2 id="displays-lights-title" class="text-lg font-semibold mb-3">Displays &amp; lights</h2>
          <.live_component
            module={TreninoWeb.GaugeBindingWizard}
            id="gauge-setup"
            train_id={@train.id}
            client={@nav_simulator_status.client}
          />
          <div class="bg-base-200/50 rounded-xl p-4 sm:p-6 space-y-6">
            <.display_bindings_section
              display_bindings={@display_bindings}
              simulator_connected={@nav_simulator_status.status == :connected}
              hardware_available={@display_hardware_available}
            />
            <div class="border-t border-base-300 pt-6">
              <.output_bindings_section
                output_bindings={@output_bindings}
                simulator_connected={@nav_simulator_status.status == :connected}
              />
            </div>
          </div>
        </section>

        <section
          :if={not @new_mode}
          id="automation"
          class="scroll-mt-36 mt-8"
          aria-labelledby="automation-title"
        >
          <h2 id="automation-title" class="text-lg font-semibold mb-3">Automation</h2>
          <details open={not Enum.empty?(@sequences)} class="py-3">
            <summary class="cursor-pointer text-base font-semibold">
              Sequences ({length(@sequences)})
            </summary>
            <.live_component
              module={SequenceManagerComponent}
              id="sequence-manager"
              train_id={@train.id}
              sequences={@sequences}
              client={@nav_simulator_status.client}
              explorer_event={@sequence_manager_event}
            />
          </details>
          <div class="bg-base-200/50 rounded-xl p-4 sm:p-6 mt-4">
            <.scripts_section scripts={@scripts} train_id={@train.id} />
          </div>
        </section>

        <.danger_zone
          :if={not @new_mode}
          action_label="Delete Train"
          action_description="Permanently remove this train and all associated elements and calibration data"
          on_action="show_delete_modal"
          disabled={@is_active}
          disabled_reason="Cannot delete while train is currently active"
        />
      </div>
    </main>

    <.add_element_modal :if={@modal_open} form={@element_form} />

    <.confirmation_modal
      :if={@show_delete_modal}
      on_close="close_delete_modal"
      on_confirm="confirm_delete"
      title="Delete Train"
      item_name={@train.name}
      description="This will permanently delete the train configuration and all its elements and calibration data."
      is_active={@is_active}
      active_warning="This train is currently active in the simulator."
    />

    <.live_component
      :if={@show_api_explorer}
      module={TreninoWeb.ApiExplorerComponent}
      id="api-explorer"
      field={@api_explorer_field}
      client={@nav_simulator_status.client}
    />

    <.live_component
      :if={@show_config_wizard and @nav_simulator_status.client != nil}
      module={TreninoWeb.ConfigurationWizardComponent}
      id="config-wizard"
      mode={@config_wizard_mode}
      element={@config_wizard_element}
      client={@nav_simulator_status.client}
      available_inputs={@available_button_inputs}
      explorer_event={@config_wizard_event}
    />

    <.live_component
      :if={@show_lever_setup_wizard and @nav_simulator_status.client != nil}
      module={TreninoWeb.LeverSetupWizard}
      id="lever-setup-wizard"
      element={@lever_setup_element}
      client={@nav_simulator_status.client}
      explorer_event={@lever_setup_event}
    />

    <.live_component
      :if={@show_output_wizard and @nav_simulator_status.client != nil}
      module={TreninoWeb.OutputBindingWizard}
      id="output-binding-wizard"
      train_id={@train.id}
      client={@nav_simulator_status.client}
      available_outputs={@available_outputs}
      binding={@output_wizard_binding}
      explorer_event={@output_wizard_event}
    />

    <.live_component
      :if={@show_display_wizard}
      module={TreninoWeb.DisplayBindingWizard}
      id="display-binding-wizard"
      train_id={@train.id}
      client={@nav_simulator_status.client}
      binding={@display_wizard_binding}
      explorer_event={@display_wizard_event}
    />
    """
  end

  # Components

  attr :train, :map, required: true
  attr :train_form, :map, required: true
  attr :is_active, :boolean, required: true
  attr :new_mode, :boolean, required: true

  attr :current_identifier, :string, default: nil
  attr :simulator_connected, :boolean, default: false

  defp train_header(assigns) do
    ~H"""
    <header>
      <h1 class="text-2xl font-semibold mb-4">{if @new_mode, do: "New train", else: "Edit train"}</h1>
      <.form
        id="train-form"
        for={@train_form}
        phx-change="validate_train"
        phx-submit="save_train"
      >
        <div>
          <.input
            label="Train Name"
            field={@train_form[:name]}
            type="text"
            class="input input-bordered w-full text-lg font-semibold"
            placeholder="e.g., BR Class 66"
          />
        </div>
        <div class="mt-3">
          <.input
            label="Description"
            field={@train_form[:description]}
            type="textarea"
            class="textarea textarea-bordered w-full resize-none"
            placeholder="Add a description (optional)"
            rows="2"
          />
        </div>
        <div class="mt-3">
          <h2 class="text-sm font-medium mb-2">Train Identifiers</h2>
          <p id="train-identifiers-hint" class="text-xs text-base-content/60 mb-3">
            Use the simulator train ID shown on the Trains page, or connect to use it here. Each entry matches any train ID that starts with that text. Keep the full ID for one variant, or shorten the end to match several variants.
          </p>
          <div :if={@simulator_connected && @current_identifier} class="mb-3 space-y-2">
            <p class="text-xs text-base-content/60">
              Current simulator train ID:
              <span class="font-mono break-all">{@current_identifier}</span>
            </p>
            <button
              id="use-current-train-id"
              type="button"
              phx-click="use_current_train_id"
              class="btn btn-outline btn-sm"
            >Use current train ID</button>
          </div>
          <p :if={not @simulator_connected} class="text-xs text-base-content/60 mb-3">
            <.link navigate={~p"/settings"} class="link">Connect to the simulator</.link>
            to use the current train ID, or enter one below.
          </p>
          <div class="space-y-2">
            <.inputs_for :let={identifier_form} field={@train_form[:identifiers]}>
              <div class="flex items-start gap-2">
                <input
                  type="hidden"
                  name="train[identifiers_sort][]"
                  value={identifier_form.index}
                />
                <div class="flex-1 min-w-0">
                  <.input
                    field={identifier_form[:identifier]}
                    type="text"
                    label={"Identifier #{identifier_form.index + 1}"}
                    aria-describedby="train-identifiers-hint"
                    class="input input-bordered w-full font-mono"
                    placeholder="e.g., BR_Class_66"
                  />
                </div>
                <button
                  type="button"
                  name="train[identifiers_drop][]"
                  value={identifier_form.index}
                  phx-click={Phoenix.LiveView.JS.dispatch("change")}
                  class="btn btn-ghost btn-sm text-error mt-6 shrink-0"
                  disabled={
                    length(Ecto.Changeset.get_field(@train_form.source, :identifiers, [])) <= 1
                  }
                  title={
                    if length(Ecto.Changeset.get_field(@train_form.source, :identifiers, [])) <= 1,
                      do: "Keep at least one identifier",
                      else: "Remove identifier"
                  }
                  aria-label={"Remove identifier #{identifier_form.index + 1}"}
                >
                  <.icon name="hero-trash" class="w-4 h-4" />
                </button>
              </div>
            </.inputs_for>
            <input type="hidden" name="train[identifiers_drop][]" />
            <button
              type="button"
              name="train[identifiers_sort][]"
              value="new"
              phx-click={Phoenix.LiveView.JS.dispatch("change")}
              class="btn btn-ghost btn-sm"
            >
              <.icon name="hero-plus" class="w-4 h-4" /> Add identifier
            </button>
            <p
              :for={{message, options} <- @train_form[:identifiers].errors}
              class="text-sm text-error"
            >
              {TreninoWeb.CoreComponents.translate_error({message, options})}
            </p>
          </div>
        </div>
        <div class="flex items-center gap-3 mt-4">
          <span :if={@is_active} class="badge badge-success badge-sm gap-1">
            <span class="w-1.5 h-1.5 rounded-full bg-success-content animate-pulse" /> Active
          </span>
          <button type="submit" class="btn btn-primary btn-sm ml-auto">
            <.icon name="hero-check" class="w-4 h-4" />
            {if @new_mode, do: "Create Train", else: "Save"}
          </button>
        </div>
      </.form>
    </header>
    """
  end

  attr :elements, :list, required: true
  attr :is_active, :boolean, required: true

  defp elements_section(assigns) do
    ~H"""
    <div>
      <.section_header title="Elements" action_label="Add Element" on_action="open_add_element_modal" />

      <.compact_empty_state
        :if={Enum.empty?(@elements)}
        message="No elements configured"
        submessage="Add elements to control train functions"
      />

      <div :if={not Enum.empty?(@elements)} class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Type</th>
              <th>Status</th>
              <th class="w-24"></th>
            </tr>
          </thead>
          <tbody>
            <.element_row
              :for={element <- @elements}
              element={element}
              is_active={@is_active}
            />
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :output_bindings, :list, required: true
  attr :simulator_connected, :boolean, required: true

  defp output_bindings_section(assigns) do
    ~H"""
    <div>
      <.section_header
        title="Outputs"
        action_label="Add Output Binding"
        on_action="open_add_output_binding"
      />

      <.compact_empty_state
        :if={Enum.empty?(@output_bindings)}
        message="No output bindings configured"
        submessage="Bind outputs to API values to control LEDs based on simulator data"
      />

      <div :if={not Enum.empty?(@output_bindings)} class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Endpoint</th>
              <th>Condition</th>
              <th>Output</th>
              <th class="w-24"></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={binding <- @output_bindings} class="hover:bg-base-200/50">
              <td class="font-medium">{binding.name}</td>
              <td class="font-mono text-xs max-w-[200px] truncate" title={binding.endpoint}>
                {binding.endpoint}
              </td>
              <td class="text-sm">
                <.condition_display
                  operator={binding.operator}
                  value_a={binding.value_a}
                  value_b={binding.value_b}
                />
              </td>
              <td class="text-sm">
                <span class="badge badge-info badge-sm">{binding.output_type}</span>
                <span class="text-base-content/60 ml-1">
                  {binding.output.name || "Pin #{binding.output.pin}"}
                </span>
              </td>
              <td>
                <div class="flex gap-1">
                  <button
                    phx-click="configure_output_binding"
                    phx-value-id={binding.id}
                    class="btn btn-ghost btn-xs"
                    title="Configure"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
                  </button>
                  <button
                    phx-click="delete_output_binding"
                    phx-value-id={binding.id}
                    class="btn btn-ghost btn-xs text-error"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :display_bindings, :list, required: true
  attr :simulator_connected, :boolean, required: true
  attr :hardware_available, :boolean, required: true

  defp display_bindings_section(assigns) do
    ~H"""
    <div>
      <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
        <h3 class="text-base font-semibold">Displays</h3>
        <button
          type="button"
          id="add-display-binding"
          phx-click="open_add_display_binding"
          class="btn btn-outline btn-sm"
          disabled={not @simulator_connected or not @hardware_available}
          aria-describedby="display-prerequisites"
        >
          <.icon name="hero-plus" class="w-4 h-4" /> Add display binding
        </button>
      </div>
      <div id="display-prerequisites" class="text-sm text-base-content/70 space-y-2">
        <p :if={not @simulator_connected}>
          <.link navigate={~p"/settings"} class="link">Connect to the simulator</.link>
          to choose a value for your display.
        </p>
        <p :if={not @hardware_available}>
          <.link navigate={~p"/"} class="link">Add a display to a hardware configuration</.link>
          before creating a binding.
        </p>
      </div>
      <p :if={Enum.empty?(@display_bindings)} class="text-sm text-base-content/60 py-3">
        No display bindings configured. Show simulator values on your hardware displays.
      </p>
      <ul :if={not Enum.empty?(@display_bindings)} class="divide-y divide-base-300">
        <li :for={binding <- @display_bindings} class="py-4 space-y-3">
          <div class="min-w-0">
            <p class="font-medium break-words">{binding.name}</p>
            <p class="text-xs text-base-content/60 mt-1 break-words">
              {if binding.i2c_module,
                do: binding.i2c_module.name || "Display #{binding.i2c_module_id}",
                else: "Display unavailable"}
            </p>
            <p class="font-mono text-xs break-all mt-2">{binding.endpoint}</p>
            <p class="font-mono text-xs text-base-content/60 mt-1">
              {binding.format_string}
              <span :if={binding.unit == "kmh"} class="badge badge-xs ml-1">m/s → km/h</span>
              <span :if={binding.unit == "mph"} class="badge badge-xs ml-1">m/s → mph</span>
            </p>
          </div>
          <div class="flex flex-wrap gap-2">
            <button
              id={"edit-display-binding-#{binding.id}"}
              phx-click="configure_display_binding"
              phx-value-id={binding.id}
              class="btn btn-ghost btn-sm"
              aria-label={"Edit display binding #{binding.name}"}
            >
              <.icon name="hero-pencil" class="w-4 h-4" /> Edit
            </button>
            <button
              phx-click="delete_display_binding"
              phx-value-id={binding.id}
              class="btn btn-ghost btn-sm text-error"
              aria-label={"Delete display binding #{binding.name}"}
              data-confirm="Delete this display binding?"
            >
              <.icon name="hero-trash" class="w-4 h-4" /> Delete
            </button>
          </div>
        </li>
      </ul>
    </div>
    """
  end

  attr :message, :string, required: true
  attr :submessage, :string, default: nil

  defp compact_empty_state(assigns) do
    ~H"""
    <div class="py-3 text-sm text-base-content/60">
      <p>{@message}</p>
      <p :if={@submessage} class="text-xs mt-1">{@submessage}</p>
    </div>
    """
  end

  attr :scripts, :list, required: true
  attr :train_id, :integer, required: true

  defp scripts_section(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-base font-semibold">Scripts</h3>
        <.link navigate={~p"/trains/#{@train_id}/scripts/new"} class="btn btn-outline btn-sm">
          <.icon name="hero-plus" class="w-4 h-4" /> Add Script
        </.link>
      </div>

      <.compact_empty_state
        :if={Enum.empty?(@scripts)}
        message="No scripts configured"
        submessage="Add Lua scripts to automate actions based on simulator data"
      />

      <div :if={not Enum.empty?(@scripts)} class="overflow-x-auto">
        <table class="table table-sm bg-base-100 rounded-lg">
          <thead>
            <tr class="bg-base-200">
              <th>Name</th>
              <th>Triggers</th>
              <th>Enabled</th>
              <th class="w-24"></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={script <- @scripts} class="hover:bg-base-200/50">
              <td class="font-medium">{script.name}</td>
              <td class="text-sm text-base-content/60">
                {length(script.triggers)} trigger{if length(script.triggers) != 1, do: "s"}
              </td>
              <td>
                <input
                  type="checkbox"
                  class="toggle toggle-sm toggle-success"
                  checked={script.enabled}
                  phx-click="toggle_script_enabled"
                  phx-value-id={script.id}
                />
              </td>
              <td>
                <div class="flex gap-1">
                  <.link
                    navigate={~p"/trains/#{@train_id}/scripts/#{script.id}"}
                    class="btn btn-ghost btn-xs"
                    title="Edit"
                  >
                    <.icon name="hero-pencil-square" class="w-4 h-4" />
                  </.link>
                  <button
                    phx-click="delete_script"
                    phx-value-id={script.id}
                    class="btn btn-ghost btn-xs text-error"
                    title="Delete"
                    data-confirm="Are you sure you want to delete this script?"
                  >
                    <.icon name="hero-trash" class="w-4 h-4" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :operator, :atom, required: true
  attr :value_a, :float, default: nil
  attr :value_b, :float, default: nil

  defp condition_display(assigns) do
    ~H"""
    <span class="font-mono">
      <%= case @operator do %>
        <% :eq_true -> %>
          = true
        <% :eq_false -> %>
          = false
        <% :gt -> %>
          &gt; {@value_a}
        <% :gte -> %>
          &ge; {@value_a}
        <% :lt -> %>
          &lt; {@value_a}
        <% :lte -> %>
          &le; {@value_a}
        <% :between -> %>
          {@value_a} - {@value_b}
      <% end %>
    </span>
    """
  end

  attr :element, :map, required: true
  attr :is_active, :boolean, required: true

  defp element_row(assigns) do
    {status_badges, configure_action} = element_status(assigns.element)

    assigns =
      assigns
      |> assign(:status_badges, status_badges)
      |> assign(:configure_action, configure_action)

    ~H"""
    <tr class="hover:bg-base-200/50">
      <td class="font-medium">
        <div class="flex items-center gap-2">
          <.icon
            name={element_type_icon(@element.type)}
            class="w-4 h-4 text-base-content/50"
          />
          {@element.name}
        </div>
      </td>
      <td>
        <span class="badge badge-ghost badge-sm capitalize">{@element.type}</span>
      </td>
      <td>
        <span
          :for={{variant, label} <- @status_badges}
          class={["badge badge-sm", badge_variant_class(variant)]}
        >
          {label}
        </span>
      </td>
      <td>
        <div class="flex gap-1">
          <button
            :if={@configure_action}
            phx-click={@configure_action}
            phx-value-id={@element.id}
            class="btn btn-ghost btn-xs"
            title="Configure"
          >
            <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
          </button>
          <button
            phx-click="delete_element"
            phx-value-id={@element.id}
            class="btn btn-ghost btn-xs text-error"
            title="Delete"
          >
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
      </td>
    </tr>
    """
  end

  defp element_status(%{type: :lever} = element) do
    {lever_status_badge(element), "configure_lever"}
  end

  defp element_status(%{type: :button} = element) do
    {button_status_badge(element), "configure_button"}
  end

  defp element_status(_element) do
    {[{:ghost, "Unknown"}], nil}
  end

  defp lever_status_badge(element) do
    lever_config = get_lever_config(element)
    input_binding = get_input_binding(lever_config)
    has_input_ranges = has_notch_input_ranges?(lever_config)

    cond do
      has_input_ranges -> [{:success, "Ready"}]
      input_binding -> [{:info, "Needs mapping"}]
      lever_config -> [{:warning, "Needs input"}]
      true -> [{:ghost, "Not configured"}]
    end
  end

  defp button_status_badge(element) do
    button_binding = get_button_binding(element)

    cond do
      button_binding && button_fully_configured?(button_binding) -> [{:success, "Ready"}]
      button_binding -> [{:info, "Partial"}]
      true -> [{:ghost, "Not configured"}]
    end
  end

  defp element_type_icon(:lever), do: "hero-adjustments-vertical"
  defp element_type_icon(:button), do: "hero-cursor-arrow-rays"
  defp element_type_icon(_), do: "hero-cube"

  defp badge_variant_class(:success), do: "badge-success"
  defp badge_variant_class(:warning), do: "badge-warning"
  defp badge_variant_class(:info), do: "badge-info"
  defp badge_variant_class(:error), do: "badge-error"
  defp badge_variant_class(_), do: "badge-ghost"

  defp button_fully_configured?(%{mode: :sequence} = binding) do
    binding.on_sequence_id != nil or binding.off_sequence_id != nil
  end

  defp button_fully_configured?(%{mode: :keystroke} = binding) do
    binding.keystroke != nil and binding.keystroke != ""
  end

  defp button_fully_configured?(binding) do
    binding.endpoint != nil
  end

  defp get_lever_config(%Element{lever_config: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_lever_config(%Element{lever_config: config}), do: config

  defp get_input_binding(nil), do: nil
  defp get_input_binding(%LeverConfig{input_binding: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_input_binding(%LeverConfig{input_binding: nil}), do: nil

  defp get_input_binding(%LeverConfig{
         input_binding: %LeverInputBinding{input: %Ecto.Association.NotLoaded{}}
       }),
       do: nil

  defp get_input_binding(%LeverConfig{input_binding: binding}), do: binding

  defp has_notch_input_ranges?(nil), do: false

  defp has_notch_input_ranges?(%LeverConfig{notches: notches}) when is_list(notches) do
    Enum.any?(notches, fn notch ->
      notch.input_min != nil and notch.input_max != nil
    end)
  end

  defp has_notch_input_ranges?(_), do: false

  defp get_button_binding(%Element{button_binding: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_button_binding(%Element{button_binding: nil}), do: nil
  defp get_button_binding(%Element{button_binding: binding}), do: binding

  attr :form, :map, required: true

  defp add_element_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_add_element_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-md mx-4 p-6">
        <h2 class="text-xl font-semibold mb-4">Add Element</h2>

        <.form
          id="add-element-form"
          for={@form}
          phx-change="validate_element"
          phx-submit="add_element"
        >
          <div class="space-y-4">
            <div>
              <label class="label">
                <span class="label-text">Element Name</span>
              </label>
              <.input
                field={@form[:name]}
                type="text"
                placeholder="e.g., Throttle, Reverser"
                class="input input-bordered w-full"
              />
            </div>

            <div>
              <label class="label">
                <span class="label-text">Type</span>
              </label>
              <.input
                field={@form[:type]}
                type="select"
                options={[{"Lever", :lever}, {"Button", :button}]}
                class="select select-bordered w-full"
              />
              <p class="text-xs text-base-content/50 mt-1">
                Lever for analog inputs, Button for digital inputs
              </p>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_add_element_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              Add Element
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
