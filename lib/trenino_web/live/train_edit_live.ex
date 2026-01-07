defmodule TreninoWeb.TrainEditLive do
  @moduledoc """
  LiveView for editing a train configuration.

  Supports both creating new trains and editing existing ones.
  Allows managing train elements (levers, etc.) and their configurations.
  """

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
  alias Trenino.Train.{ButtonController, Element, Identifier, LeverConfig, LeverInputBinding, Train}
  alias Trenino.Train.LeverController
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

    train = %Train{name: suggested_name, description: nil, identifier: identifier}
    changeset = Train.changeset(train, %{})

    {:ok,
     socket
     |> assign(:train, train)
     |> assign(:train_form, to_form(changeset))
     |> assign(:elements, [])
     |> assign(:new_mode, true)
     |> assign(:active_train, TrainContext.get_active_train())
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
     |> assign(:sequences, [])}
  end

  defp mount_existing(socket, train_id) do
    case TrainContext.get_train(train_id,
           preload: [
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

        {:ok,
         socket
         |> assign(:train, train)
         |> assign(:train_form, to_form(changeset))
         |> assign(:elements, train.elements)
         |> assign(:new_mode, false)
         |> assign(:active_train, TrainContext.get_active_train())
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
         |> assign(:sequences, sequences)}

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
  def handle_info({:train_detected, %{train: train}}, socket) do
    {:noreply, assign(socket, :active_train, train)}
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
  def handle_info({:api_explorer_select, field, path}, socket) do
    cond do
      socket.assigns.show_lever_setup_wizard ->
        {:noreply, assign(socket, :lever_setup_event, {:select, field, path})}

      socket.assigns.show_config_wizard ->
        {:noreply, assign(socket, :config_wizard_event, {:select, field, path})}

      true ->
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

      true ->
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

  # Value polling for button ON/OFF detection using API subscriptions
  # Subscription ID 999 is reserved for button value detection
  @value_detection_subscription_id 999

  @impl true
  def handle_info({:start_value_polling, endpoint}, socket) do
    client = socket.assigns.nav_simulator_status.client
    cancel_value_polling(socket)

    Logger.debug("[ValuePolling] Attempting to subscribe to: #{inspect(endpoint)}")

    if client && endpoint do
      # Clean up any existing subscription and create a new one
      SimulatorClient.unsubscribe(client, @value_detection_subscription_id)

      case SimulatorClient.subscribe(client, endpoint, @value_detection_subscription_id) do
        {:ok, _} ->
          Logger.info("[ValuePolling] Subscribed to #{endpoint}")
          # Start polling the subscription (every 200ms)
          {:ok, timer_ref} = :timer.send_interval(200, :poll_value_subscription)
          {:noreply, assign(socket, :value_polling_timer, timer_ref)}

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

    if client do
      case SimulatorClient.get_subscription(client, @value_detection_subscription_id) do
        {:ok, %{"Entries" => [%{"Values" => values} | _]}} when map_size(values) > 0 ->
          # Extract the first value from the Values map
          value =
            values
            |> Map.values()
            |> List.first()
            |> then(&Float.round(&1 * 1.0, 2))

          send_update(TreninoWeb.ConfigurationWizardComponent,
            id: "config-wizard",
            value_polling_result: value
          )

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

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Private functions

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

    case LeverAnalyzer.analyze(client, control_path, restore_position: 0.5) do
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
      %{label: @train.name || "New Train"}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <.train_header
          train={@train}
          train_form={@train_form}
          is_active={@is_active}
          new_mode={@new_mode}
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

        <div :if={not @new_mode} class="bg-base-200/50 rounded-xl p-6 mt-6">
          <.elements_section elements={@elements} is_active={@is_active} />
        </div>

        <.live_component
          :if={not @new_mode}
          module={SequenceManagerComponent}
          id="sequence-manager"
          train_id={@train.id}
          sequences={@sequences}
        />

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
    """
  end

  # Components

  attr :train, :map, required: true
  attr :train_form, :map, required: true
  attr :is_active, :boolean, required: true
  attr :new_mode, :boolean, required: true

  defp train_header(assigns) do
    ~H"""
    <header>
      <.form for={@train_form} phx-change="validate_train" phx-submit="save_train">
        <div>
          <label class="label">
            <span class="label-text">Train Name</span>
          </label>
          <.input
            field={@train_form[:name]}
            type="text"
            class="input input-bordered w-full text-lg font-semibold"
            placeholder="e.g., BR Class 66"
          />
        </div>
        <div class="mt-3">
          <label class="label">
            <span class="label-text">Description</span>
          </label>
          <.input
            field={@train_form[:description]}
            type="textarea"
            class="textarea textarea-bordered w-full resize-none"
            placeholder="Add a description (optional)"
            rows="2"
          />
        </div>
        <div class="mt-3">
          <label class="label">
            <span class="label-text">Train Identifier</span>
          </label>
          <.input
            field={@train_form[:identifier]}
            type="text"
            class="input input-bordered w-full font-mono"
            placeholder="e.g., BR_Class_66"
          />
          <p class="text-xs text-base-content/50 mt-1">
            This identifier is used to automatically detect when this train is active in the simulator.
          </p>
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
    <div class="mb-6">
      <.section_header title="Elements" action_label="Add Element" on_action="open_add_element_modal" />

      <.empty_collection_state
        :if={Enum.empty?(@elements)}
        icon="hero-adjustments-horizontal"
        message="No elements configured"
        submessage="Add elements to control train functions"
      />

      <div :if={not Enum.empty?(@elements)} class="space-y-3">
        <.lever_element_card
          :for={element <- Enum.filter(@elements, &(&1.type == :lever))}
          element={element}
          is_active={@is_active}
        />
        <.button_element_card
          :for={element <- Enum.filter(@elements, &(&1.type == :button))}
          element={element}
          is_active={@is_active}
        />
      </div>
    </div>
    """
  end

  attr :element, :map, required: true
  attr :is_active, :boolean, required: true

  defp lever_element_card(assigns) do
    lever_config = get_lever_config(assigns.element)
    is_calibrated = lever_config != nil and lever_config.calibrated_at != nil
    notch_count = if lever_config, do: length(lever_config.notches || []), else: 0
    input_binding = get_input_binding(lever_config)
    has_input_ranges = has_notch_input_ranges?(lever_config)

    assigns =
      assigns
      |> assign(:lever_config, lever_config)
      |> assign(:is_calibrated, is_calibrated)
      |> assign(:notch_count, notch_count)
      |> assign(:input_binding, input_binding)
      |> assign(:has_input_ranges, has_input_ranges)

    ~H"""
    <div class="bg-base-100 rounded-lg border border-base-300 p-4">
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <.icon name="hero-adjustments-vertical" class="w-5 h-5 text-base-content/50" />
            <h4 class="font-medium">{@element.name}</h4>
            <span class="badge badge-ghost badge-sm capitalize">{@element.type}</span>
          </div>

          <%!-- Configuration Progress Stepper --%>
          <div class="mt-3 flex items-center gap-2 text-xs">
            <div class={[
              "flex items-center gap-1 px-2 py-1 rounded",
              if(@lever_config,
                do: "bg-success/10 text-success",
                else: "bg-base-200 text-base-content/50"
              )
            ]}>
              <.icon
                name={if @lever_config, do: "hero-check-circle", else: "hero-cog-6-tooth"}
                class="w-3.5 h-3.5"
              />
              <span>Endpoints</span>
            </div>
            <.icon name="hero-chevron-right" class="w-3 h-3 text-base-content/30" />
            <div class={[
              "flex items-center gap-1 px-2 py-1 rounded",
              cond do
                @input_binding -> "bg-success/10 text-success"
                @lever_config -> "bg-primary/10 text-primary"
                true -> "bg-base-200 text-base-content/50"
              end
            ]}>
              <.icon
                name={if @input_binding, do: "hero-check-circle", else: "hero-link"}
                class="w-3.5 h-3.5"
              />
              <span>Input</span>
            </div>
            <.icon name="hero-chevron-right" class="w-3 h-3 text-base-content/30" />
            <div class={[
              "flex items-center gap-1 px-2 py-1 rounded",
              cond do
                @has_input_ranges -> "bg-success/10 text-success"
                @input_binding -> "bg-primary/10 text-primary"
                true -> "bg-base-200 text-base-content/50"
              end
            ]}>
              <.icon
                name={if @has_input_ranges, do: "hero-check-circle", else: "hero-queue-list"}
                class="w-3.5 h-3.5"
              />
              <span>Mapping</span>
            </div>
          </div>

          <%!-- Status indicators --%>
          <div
            :if={@lever_config && !@input_binding}
            class="mt-3 p-2 bg-warning/10 border border-warning/30 rounded-lg"
          >
            <div class="flex items-start gap-2">
              <.icon
                name="hero-exclamation-triangle"
                class="w-4 h-4 text-warning flex-shrink-0 mt-0.5"
              />
              <div class="text-xs">
                <p class="font-medium text-warning">No hardware input bound</p>
                <p class="text-base-content/70">Bind a calibrated input to control this lever.</p>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            phx-click="configure_lever"
            phx-value-id={@element.id}
            class="btn btn-sm btn-primary gap-1"
          >
            <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
            {if @lever_config, do: "Edit", else: "Configure"}
          </button>
          <button
            phx-click="delete_element"
            phx-value-id={@element.id}
            class="btn btn-ghost btn-sm text-error"
            title="Delete"
          >
            <.icon name="hero-trash" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
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

  # Button element components

  attr :element, :map, required: true
  attr :is_active, :boolean, required: true

  defp button_element_card(assigns) do
    button_binding = get_button_binding(assigns.element)
    has_endpoint = button_binding != nil and button_binding.endpoint != nil

    assigns =
      assigns
      |> assign(:button_binding, button_binding)
      |> assign(:has_endpoint, has_endpoint)

    ~H"""
    <div class="bg-base-100 rounded-lg border border-base-300 p-4">
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <.icon name="hero-finger-print" class="w-5 h-5 text-base-content/50" />
            <h4 class="font-medium">{@element.name}</h4>
            <span class="badge badge-warning badge-sm capitalize">{@element.type}</span>
          </div>

          <%!-- Configuration Progress --%>
          <div class="mt-3 flex items-center gap-2 text-xs">
            <div class={[
              "flex items-center gap-1 px-2 py-1 rounded",
              if(@button_binding,
                do: "bg-success/10 text-success",
                else: "bg-base-200 text-base-content/50"
              )
            ]}>
              <.icon
                name={if @button_binding, do: "hero-check-circle", else: "hero-link"}
                class="w-3.5 h-3.5"
              />
              <span>Bound</span>
            </div>
            <.icon name="hero-chevron-right" class="w-3 h-3 text-base-content/30" />
            <div class={[
              "flex items-center gap-1 px-2 py-1 rounded",
              if(@has_endpoint,
                do: "bg-success/10 text-success",
                else: "bg-base-200 text-base-content/50"
              )
            ]}>
              <.icon
                name={if @has_endpoint, do: "hero-check-circle", else: "hero-cog-6-tooth"}
                class="w-3.5 h-3.5"
              />
              <span>Configured</span>
            </div>
          </div>

          <%!-- Show binding info --%>
          <div :if={@button_binding} class="mt-2 text-xs text-base-content/60">
            <span class="font-medium">Input:</span>
            {@button_binding.input.device.name} / Pin {@button_binding.input.pin}
          </div>
          <div :if={@has_endpoint} class="mt-1 text-xs text-base-content/60 font-mono truncate">
            {@button_binding.endpoint}
          </div>
        </div>

        <div class="flex flex-col items-end gap-2">
          <%!-- Primary actions --%>
          <div class="flex items-center gap-2">
            <button
              phx-click="configure_button"
              phx-value-id={@element.id}
              class="btn btn-sm btn-outline gap-1"
            >
              <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
              {if @button_binding, do: "Configure", else: "Set Up"}
            </button>
          </div>
          <%!-- Secondary actions --%>
          <div class="flex items-center gap-1">
            <button
              phx-click="delete_element"
              phx-value-id={@element.id}
              class="btn btn-ghost btn-xs text-error"
              title="Delete"
            >
              <.icon name="hero-trash" class="w-4 h-4" />
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

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

        <.form for={@form} phx-change="validate_element" phx-submit="add_element">
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
