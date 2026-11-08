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
  import TreninoWeb.TrainEditLive.Sections

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection
  alias Trenino.Simulator
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.ControlDetectionSession
  alias Trenino.Train, as: TrainContext

  alias Trenino.Train.{
    ButtonController,
    DisplayController,
    Element,
    GaugeBinding,
    Identifier,
    OutputController,
    SelectorController,
    Train,
    TrainIdentifier
  }

  alias Trenino.Train.LeverController
  alias Trenino.Train.LeverSetup
  alias Trenino.Train.ScriptRunner
  alias TreninoWeb.SelectorWizard
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
         |> put_flash(:error, "That train link is not valid. Pick a train from Trains.")
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
     |> assign(:page_title, "New train")
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
     |> assign(:lever_setup_initial_step, nil)
     |> assign(:show_selector_wizard, false)
     |> assign(:selector_wizard_element, nil)
     |> assign(:selector_inputs, [])
     |> assign(:selector_lever_input_ids, MapSet.new())
     |> assign(:selector_watch, nil)
     |> assign(:selector_watch_input_id, nil)
     |> assign(:watched_ports, MapSet.new())
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
     |> assign(:scripts, [])
     |> assign(:gauge_binding_count, 0)
     |> assign(:selector_positions, %{})}
  end

  defp mount_existing(socket, train_id) do
    case TrainContext.get_train(train_id,
           preload: [
             :identifiers,
             elements: [
               lever_config: [:notches, input_binding: [input: :device]],
               button_binding: [input: :device],
               selector_binding: [:positions, input: :device]
             ]
           ]
         ) do
      {:ok, train} ->
        if connected?(socket) do
          TrainContext.subscribe()
          SelectorController.subscribe()
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
         |> assign(:page_title, train.name)
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
         |> assign(:lever_setup_initial_step, nil)
         |> assign(:show_selector_wizard, false)
         |> assign(:selector_wizard_element, nil)
         |> assign(:selector_inputs, [])
         |> assign(:selector_lever_input_ids, MapSet.new())
         |> assign(:selector_watch, nil)
         |> assign(:selector_watch_input_id, nil)
         |> assign(:watched_ports, MapSet.new())
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
         |> assign(:scripts, scripts)
         |> assign(:gauge_binding_count, length(TrainContext.list_gauge_bindings(train.id)))
         |> assign(:selector_positions, selector_positions(train.elements))}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "That train no longer exists. Pick another one from Trains.")
         |> redirect(to: ~p"/trains")}
    end
  end

  # Nav component events
  # Deep link from the MCP server or the AI: /trains/:id?lever=ELEMENT_ID&step=STEP
  @impl true
  def handle_params(%{"lever" => lever_id} = params, _uri, socket) do
    with true <- connected?(socket),
         %Train{id: train_id} when is_integer(train_id) <- socket.assigns.train,
         {element_id, ""} <- Integer.parse(lever_id),
         {:ok, %Element{type: :lever, train_id: ^train_id}} <-
           TrainContext.get_element(element_id) do
      open_lever_from_link(socket, element_id, parse_wizard_step(params["step"]))
    else
      false -> {:noreply, socket}
      _ -> {:noreply, put_flash(socket, :error, "That lever link is not valid for this train.")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # NavHook loads the simulator status after mount, so ask the simulator directly
  defp open_lever_from_link(socket, element_id, step) do
    simulator_status = Simulator.get_status()

    if simulator_status.status != :connected or simulator_status.client == nil do
      {:noreply,
       put_flash(
         socket,
         :error,
         "Connect to the simulator, then click Configure on the lever to continue its setup."
       )}
    else
      {:noreply, socket} = open_lever_config_wizard(socket, element_id)
      {:noreply, assign(socket, :lever_setup_initial_step, step)}
    end
  end

  defp parse_wizard_step(step) when is_binary(step) do
    Enum.find(LeverSetup.wizard_steps(), &(Atom.to_string(&1) == step))
  end

  defp parse_wizard_step(_), do: nil

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

        # Open the configuration wizard if the simulator is connected. Selectors
        # are configured offline, so their wizard always opens.
        simulator_status = socket.assigns.nav_simulator_status

        if element.type == :selector or
             (simulator_status.status == :connected and simulator_status.client != nil) do
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
            {:noreply,
             put_flash(
               socket,
               :error,
               "The element could not be deleted. Try again; if it keeps failing, reload the page."
             )}
        end

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That element no longer exists. Reload the page to see the current list."
         )}
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

  # Selector configuration - works without the simulator
  @impl true
  def handle_event("configure_selector", %{"id" => id}, socket) do
    open_selector_wizard(socket, String.to_integer(id))
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
        Logger.error("Failed to delete train #{train.id}: #{inspect(reason)}")

        {:noreply,
         socket
         |> put_flash(
           :error,
           "The train could not be deleted. Try again; if it keeps failing, reload the page."
         )
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
      {:noreply,
       put_flash(
         socket,
         :error,
         "Train Sim World is not connected. Start the game, then try again."
       )}
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
          {:noreply,
           put_flash(
             socket,
             :error,
             "That output binding no longer exists. Reload the page to see the current list."
           )}
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
            {:noreply,
             put_flash(
               socket,
               :error,
               "The output binding could not be deleted. Try again; if it keeps failing, reload the page."
             )}
        end

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That output binding no longer exists. Reload the page to see the current list."
         )}
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "That display binding no longer exists. Reload the page to see the current list."
         )}
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
            {:noreply,
             put_flash(
               socket,
               :error,
               "The display binding could not be deleted. Try again; if it keeps failing, reload the page."
             )}
        end

      {:error, :not_found} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "That display binding no longer exists. Reload the page to see the current list."
         )}
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "That script no longer exists. Reload the page to see the current list."
         )}
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
        {:noreply,
         put_flash(
           socket,
           :error,
           "That script no longer exists. Reload the page to see the current list."
         )}
    end
  end

  # PubSub events
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    socket = assign(socket, :nav_devices, devices)

    # A device appearing or disappearing changes what the selector wizard can read
    case socket.assigns.selector_watch_input_id do
      nil -> {:noreply, socket}
      input_id -> {:noreply, watch_selector_input(socket, input_id)}
    end
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

  def handle_info({:api_explorer_select, "selector:" <> _ = field, path}, socket) do
    send_update(SelectorWizard, id: "selector-wizard", explorer_event: {field, path})
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
      socket.assigns.show_selector_wizard ->
        send_update(SelectorWizard, id: "selector-wizard", explorer_event: :close)
        {:noreply, socket}

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
     |> assign(:lever_setup_initial_step, nil)
     |> assign(:lever_setup_element, nil)
     |> assign(:lever_setup_event, nil)
     |> put_flash(
       :info,
       "Lever '#{get_element_name(elements, element_id)}' configured"
     )}
  end

  @impl true
  def handle_info({:lever_setup_cancelled, _element_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_lever_setup_wizard, false)
     |> assign(:lever_setup_initial_step, nil)
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

    socket = Enum.reduce(ports, socket, &subscribe_port(&2, &1))

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
  def handle_info(
        {:input_value_updated, port, pin, value},
        %{assigns: %{selector_watch: {port, pin}}} = socket
      ) do
    send_update(SelectorWizard, id: "selector-wizard", reading: value)
    {:noreply, socket}
  end

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

  # Selector wizard events
  @impl true
  def handle_info({:selector_wizard_watch, input_id}, socket) do
    {:noreply, watch_selector_input(socket, input_id)}
  end

  def handle_info({:selector_wizard_saved, _element_id}, socket) do
    {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)

    {:noreply,
     socket
     |> close_selector_wizard()
     |> assign(:elements, elements)
     |> assign(:selector_positions, selector_positions(elements))
     |> put_flash(:info, "Selector saved")}
  end

  def handle_info({:selector_wizard_cancelled, _element_id}, socket) do
    {:noreply, close_selector_wizard(socket)}
  end

  def handle_info({:selector_position_changed, element_id, nil}, socket) do
    {:noreply, update(socket, :selector_positions, &Map.delete(&1, element_id))}
  end

  def handle_info({:selector_position_changed, element_id, info}, socket) do
    {:noreply, update(socket, :selector_positions, &Map.put(&1, element_id, info))}
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

  # The gauge binding wizard owns its list; the page only keeps the count for the nav.
  def handle_info({event, %GaugeBinding{train_id: train_id}}, socket)
      when event in [:gauge_binding_saved, :gauge_binding_deleted] do
    {:noreply,
     assign(socket, :gauge_binding_count, length(TrainContext.list_gauge_bindings(train_id)))}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # Private functions

  # Anchor nav entries, one per section, each counting what its section's badge counts.
  defp nav_items(assigns) do
    [
      %{id: "elements", label: "Elements", count: length(assigns.elements)}
    ] ++
      if(assigns.beta_gauges,
        do: [%{id: "gauge-bindings", label: "Gauge bindings", count: assigns.gauge_binding_count}],
        else: []
      ) ++
      [
        %{
          id: "display-bindings",
          label: "Display bindings",
          count: length(assigns.display_bindings)
        },
        %{
          id: "output-bindings",
          label: "Output bindings",
          count: length(assigns.output_bindings)
        },
        %{id: "sequences", label: "Sequences", count: length(assigns.sequences)},
        %{id: "scripts", label: "Scripts", count: length(assigns.scripts)}
      ]
  end

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
    LeverSetup.calibrate(client, element.id, control_path, endpoints: config_params)
  end

  defp open_config_wizard_for_element(socket, %Element{type: :lever} = element) do
    open_lever_config_wizard(socket, element.id)
  end

  defp open_config_wizard_for_element(socket, %Element{type: :button} = element) do
    open_button_config_wizard(socket, element.id)
  end

  defp open_config_wizard_for_element(socket, %Element{type: :selector} = element) do
    open_selector_wizard(socket, element.id)
  end

  defp open_selector_wizard(socket, element_id) do
    case TrainContext.get_element(element_id) do
      {:ok, %Element{type: :selector} = element} ->
        inputs =
          [include_uncalibrated: true]
          |> Hardware.list_all_inputs()
          |> Enum.filter(&(&1.input_type == :analog))

        {:noreply,
         socket
         |> assign(:show_selector_wizard, true)
         |> assign(:selector_wizard_element, element)
         |> assign(:selector_inputs, inputs)
         |> assign(:selector_lever_input_ids, lever_input_ids(socket.assigns.train.id))
         |> assign(:sequences, TrainContext.list_sequences(socket.assigns.train.id))}

      _ ->
        {:noreply, socket}
    end
  end

  # Inputs that already drive an enabled lever on this train
  defp lever_input_ids(train_id) do
    for binding <- TrainContext.list_bindings_for_train(train_id),
        binding.enabled,
        into: MapSet.new(),
        do: binding.input_id
  end

  # Streams the input's readings to the selector wizard: the cached value
  # now, live values through the PubSub subscription. Tells the wizard when
  # the input's device is not connected.
  defp watch_selector_input(socket, input_id) do
    socket = assign(socket, :selector_watch_input_id, input_id)

    with %{} = input <- Enum.find(socket.assigns.selector_inputs, &(&1.id == input_id)),
         port when is_binary(port) <-
           ConfigurationManager.config_id_to_port(input.device.config_id) do
      case Map.fetch(ConfigurationManager.get_input_values(port), input.pin) do
        {:ok, raw} -> send_update(SelectorWizard, id: "selector-wizard", reading: raw)
        :error -> :ok
      end

      socket
      |> subscribe_port(port)
      |> assign(:selector_watch, {port, input.pin})
    else
      _ ->
        send_update(SelectorWizard, id: "selector-wizard", reading: :offline)
        assign(socket, :selector_watch, nil)
    end
  end

  # PubSub subscriptions last as long as the page, so each port is
  # subscribed to once.
  defp subscribe_port(socket, port) do
    if MapSet.member?(socket.assigns.watched_ports, port) do
      socket
    else
      Hardware.subscribe_input_values(port)
      update(socket, :watched_ports, &MapSet.put(&1, port))
    end
  end

  defp close_selector_wizard(socket) do
    socket
    |> assign(:show_selector_wizard, false)
    |> assign(:selector_wizard_element, nil)
    |> assign(:selector_watch, nil)
    |> assign(:selector_watch_input_id, nil)
  end

  defp selector_positions(elements) do
    for %Element{type: :selector, id: id} <- elements,
        {:ok, info} <- [SelectorController.get_position(id)],
        into: %{},
        do: {id, info}
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
         |> assign(:lever_setup_initial_step, nil)
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

        # Detection caches its lookup per identifier, so a changed list needs a fresh match
        if Train.identifier_values(train) != Train.identifier_values(socket.assigns.train) do
          TrainContext.sync()
        end

        {:noreply,
         socket
         |> assign(:page_title, train.name)
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

    assigns =
      assigns
      |> assign(:is_active, is_active)
      |> assign(:nav_items, nav_items(assigns))

    ~H"""
    <.breadcrumb items={[
      %{label: "Trains", path: ~p"/trains"},
      %{label: if(@new_mode, do: "New train", else: @train.name)}
    ]} />

    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <.train_header
          train_form={@train_form}
          is_active={@is_active}
          new_mode={@new_mode}
          current_identifier={@current_identifier}
          simulator_connected={@nav_simulator_status.status == :connected}
        />

        <.simulator_notice
          :if={not @new_mode}
          simulator_status={@nav_simulator_status}
          message="Element setup and sequence tests are paused."
          class="mt-6"
        />

        <.section_nav
          :if={not @new_mode}
          label="Train configuration sections"
          items={@nav_items}
          class="mt-6"
        />

        <.section_group :if={not @new_mode} id="controls" title="Controls">
          <.elements_section elements={@elements} selector_positions={@selector_positions} />
        </.section_group>

        <.section_group :if={not @new_mode} id="displays-lights" title="Displays & lights">
          <.live_component
            :if={@beta_gauges}
            module={TreninoWeb.GaugeBindingWizard}
            id="gauge-setup"
            train_id={@train.id}
            client={@nav_simulator_status.client}
          />
          <.display_bindings_section
            display_bindings={@display_bindings}
            simulator_connected={@nav_simulator_status.status == :connected}
            hardware_available={@display_hardware_available}
          />
          <.output_bindings_section
            output_bindings={@output_bindings}
            simulator_connected={@nav_simulator_status.status == :connected}
            outputs_available={@available_outputs != []}
          />
        </.section_group>

        <.section_group :if={not @new_mode} id="automation" title="Automation">
          <.live_component
            module={SequenceManagerComponent}
            id="sequence-manager"
            train_id={@train.id}
            sequences={@sequences}
            client={@nav_simulator_status.client}
            explorer_event={@sequence_manager_event}
          />
          <.scripts_section scripts={@scripts} train_id={@train.id} />
        </.section_group>

        <.danger_zone
          :if={not @new_mode}
          action_label="Delete train"
          action_description="Permanently remove this train and all associated elements and calibration data"
          on_action="show_delete_modal"
          disabled={@is_active}
          disabled_reason="Cannot delete while train is currently active"
        />
      </div>
    </main>

    <.add_element_modal :if={@modal_open} form={@element_form} beta_selectors={@beta_selectors} />

    <.confirmation_modal
      :if={@show_delete_modal}
      on_close="close_delete_modal"
      on_confirm="confirm_delete"
      title="Delete train"
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
      initial_step={@lever_setup_initial_step}
      client={@nav_simulator_status.client}
      explorer_event={@lever_setup_event}
    />

    <.live_component
      :if={@show_selector_wizard}
      module={SelectorWizard}
      id="selector-wizard"
      element={@selector_wizard_element}
      train_id={@train.id}
      client={if @nav_simulator_status.status == :connected, do: @nav_simulator_status.client}
      sequences={@sequences}
      inputs={@selector_inputs}
      lever_input_ids={@selector_lever_input_ids}
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
end
