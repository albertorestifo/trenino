defmodule TswIoWeb.TrainEditLive do
  @moduledoc """
  LiveView for editing a train configuration.

  Supports both creating new trains and editing existing ones.
  Allows managing train elements (levers, etc.) and their configurations.
  """

  use TswIoWeb, :live_view

  import TswIoWeb.NavComponents
  import TswIoWeb.SharedComponents

  alias TswIo.Train, as: TrainContext
  alias TswIo.Train.{Train, Element, LeverConfig}
  alias TswIo.Serial.Connection

  @impl true
  def mount(%{"train_id" => "new"}, _session, socket) do
    mount_new(socket)
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

  defp mount_new(socket) do
    if connected?(socket) do
      TrainContext.subscribe()
    end

    # Check for pre-filled identifier from query params
    identifier = get_connect_params(socket)["identifier"] || ""

    train = %Train{name: "", description: nil, identifier: identifier}
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
     |> assign(:configuring_element, nil)
     |> assign(:lever_config_form, nil)}
  end

  defp mount_existing(socket, train_id) do
    case TrainContext.get_train(train_id, preload: [elements: :lever_config]) do
      {:ok, train} ->
        if connected?(socket) do
          TrainContext.subscribe()
        end

        changeset = Train.changeset(train, %{})

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
         |> assign(:configuring_element, nil)
         |> assign(:lever_config_form, nil)}

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
      {:ok, _element} ->
        {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)

        {:noreply,
         socket
         |> assign(:elements, elements)
         |> assign(:modal_open, false)
         |> assign(:element_form, to_form(Element.changeset(%Element{}, %{type: :lever})))}

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

  # Lever configuration
  @impl true
  def handle_event("configure_lever", %{"id" => id}, socket) do
    element_id = String.to_integer(id)

    case TrainContext.get_element(element_id, preload: [lever_config: :notches]) do
      {:ok, element} ->
        lever_config = element.lever_config || %LeverConfig{element_id: element_id}
        changeset = LeverConfig.changeset(lever_config, %{})

        {:noreply,
         socket
         |> assign(:configuring_element, element)
         |> assign(:lever_config_form, to_form(changeset))}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Element not found")}
    end
  end

  @impl true
  def handle_event("close_lever_config_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:configuring_element, nil)
     |> assign(:lever_config_form, nil)}
  end

  @impl true
  def handle_event("validate_lever_config", %{"lever_config" => params}, socket) do
    lever_config = socket.assigns.configuring_element.lever_config || %LeverConfig{}

    changeset =
      lever_config
      |> LeverConfig.changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :lever_config_form, to_form(changeset))}
  end

  @impl true
  def handle_event("save_lever_config", %{"lever_config" => params}, socket) do
    element = socket.assigns.configuring_element

    result =
      if element.lever_config do
        TrainContext.update_lever_config(element.lever_config, params)
      else
        TrainContext.create_lever_config(element.id, params)
      end

    case result do
      {:ok, _config} ->
        {:ok, elements} = TrainContext.list_elements(socket.assigns.train.id)

        {:noreply,
         socket
         |> assign(:elements, elements)
         |> assign(:configuring_element, nil)
         |> assign(:lever_config_form, nil)
         |> put_flash(:info, "Lever configuration saved")}

      {:error, changeset} ->
        {:noreply, assign(socket, :lever_config_form, to_form(changeset))}
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
  def handle_info({:detection_error, _reason}, socket) do
    {:noreply, socket}
  end

  # Private functions

  defp save_train(%{assigns: %{new_mode: true}} = socket, params) do
    case TrainContext.create_train(params) do
      {:ok, train} ->
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
    <div class="min-h-screen flex flex-col">
      <.nav_header
        devices={@nav_devices}
        simulator_status={@nav_simulator_status}
        dropdown_open={@nav_dropdown_open}
        scanning={@nav_scanning}
        current_path={@nav_current_path}
      />

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

          <div :if={not @new_mode} class="bg-base-200/50 rounded-xl p-6 mt-6">
            <.elements_section elements={@elements} is_active={@is_active} />
          </div>

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

      <.lever_config_modal
        :if={@configuring_element}
        element={@configuring_element}
        form={@lever_config_form}
      />
    </div>
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
        <.input
          field={@train_form[:name]}
          type="text"
          class="text-2xl font-semibold bg-transparent border border-base-300/0 hover:border-base-300/50 hover:bg-base-200/20 p-2 -ml-2 focus:ring-2 focus:ring-primary focus:border-primary w-full transition-all rounded-md"
          placeholder="Train Name"
        />
        <.input
          field={@train_form[:description]}
          type="textarea"
          class="text-sm text-base-content/70 bg-transparent border border-base-300/0 hover:border-base-300/50 hover:bg-base-200/20 p-2 -ml-2 focus:ring-2 focus:ring-primary focus:border-primary w-full resize-none mt-1 transition-all rounded-md"
          placeholder="Add a description..."
          rows="2"
        />
        <div class="mt-3">
          <label class="label">
            <span class="label-text text-sm text-base-content/70">Train Identifier</span>
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
      <h3 class="text-base font-semibold mb-4">Elements</h3>

      <.empty_elements_state :if={Enum.empty?(@elements)} />

      <div :if={not Enum.empty?(@elements)} class="space-y-3">
        <.element_card :for={element <- @elements} element={element} is_active={@is_active} />
      </div>

      <button phx-click="open_add_element_modal" class="btn btn-outline btn-sm mt-4">
        <.icon name="hero-plus" class="w-4 h-4" /> Add Element
      </button>
    </div>
    """
  end

  defp empty_elements_state(assigns) do
    ~H"""
    <.empty_collection_state
      icon="hero-adjustments-horizontal"
      message="No elements configured"
      submessage="Add elements to control train functions"
    />
    """
  end

  attr :element, :map, required: true
  attr :is_active, :boolean, required: true

  defp element_card(assigns) do
    lever_config = get_lever_config(assigns.element)
    is_calibrated = lever_config != nil and lever_config.calibrated_at != nil
    notch_count = if lever_config, do: length(lever_config.notches || []), else: 0

    assigns =
      assigns
      |> assign(:lever_config, lever_config)
      |> assign(:is_calibrated, is_calibrated)
      |> assign(:notch_count, notch_count)

    ~H"""
    <div class="bg-base-100 rounded-lg border border-base-300 p-4">
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1">
          <div class="flex items-center gap-2">
            <.icon name="hero-adjustments-vertical" class="w-5 h-5 text-base-content/50" />
            <h4 class="font-medium">{@element.name}</h4>
            <span class="badge badge-ghost badge-sm capitalize">{@element.type}</span>
          </div>

          <div class="mt-2 flex items-center gap-4 text-xs text-base-content/60">
            <span :if={@lever_config}>
              {notch_text(@notch_count)}
            </span>
            <span :if={@is_calibrated} class="text-success flex items-center gap-1">
              <.icon name="hero-check-circle" class="w-3 h-3" /> Calibrated
            </span>
            <span :if={not @is_calibrated} class="text-warning flex items-center gap-1">
              <.icon name="hero-exclamation-triangle" class="w-3 h-3" /> Not calibrated
            </span>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <button
            phx-click="configure_lever"
            phx-value-id={@element.id}
            class="btn btn-ghost btn-xs text-primary"
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
      </div>
    </div>
    """
  end

  defp get_lever_config(%Element{lever_config: %Ecto.Association.NotLoaded{}}), do: nil
  defp get_lever_config(%Element{lever_config: config}), do: config

  defp notch_text(0), do: "No notches"
  defp notch_text(1), do: "1 notch"
  defp notch_text(n), do: "#{n} notches"

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
                options={[{"Lever", :lever}]}
                class="select select-bordered w-full"
              />
              <p class="text-xs text-base-content/50 mt-1">
                More element types coming soon
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

  attr :element, :map, required: true
  attr :form, :map, required: true

  defp lever_config_modal(assigns) do
    has_existing_config = assigns.element.lever_config != nil
    assigns = assign(assigns, :has_existing_config, has_existing_config)

    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center">
      <div class="absolute inset-0 bg-black/50" phx-click="close_lever_config_modal" />
      <div class="relative bg-base-100 rounded-xl shadow-xl w-full max-w-lg mx-4 p-6">
        <h2 class="text-xl font-semibold mb-1">Configure {@element.name}</h2>
        <p class="text-sm text-base-content/60 mb-4">
          Set the simulator API endpoints for this lever control.
        </p>

        <.form for={@form} phx-change="validate_lever_config" phx-submit="save_lever_config">
          <div class="space-y-4">
            <div class="bg-base-200/50 rounded-lg p-4">
              <h3 class="text-sm font-semibold mb-3">Required Endpoints</h3>
              <div class="space-y-3">
                <div>
                  <label class="label py-1">
                    <span class="label-text text-xs">Minimum Value Endpoint</span>
                  </label>
                  <.input
                    field={@form[:min_endpoint]}
                    type="text"
                    placeholder="e.g., CurrentDrivableActor/Throttle(Lever).MinInput"
                    class="input input-bordered input-sm w-full font-mono text-xs"
                  />
                </div>
                <div>
                  <label class="label py-1">
                    <span class="label-text text-xs">Maximum Value Endpoint</span>
                  </label>
                  <.input
                    field={@form[:max_endpoint]}
                    type="text"
                    placeholder="e.g., CurrentDrivableActor/Throttle(Lever).MaxInput"
                    class="input input-bordered input-sm w-full font-mono text-xs"
                  />
                </div>
                <div>
                  <label class="label py-1">
                    <span class="label-text text-xs">Current Value Endpoint</span>
                  </label>
                  <.input
                    field={@form[:value_endpoint]}
                    type="text"
                    placeholder="e.g., CurrentDrivableActor/Throttle(Lever).InputValue"
                    class="input input-bordered input-sm w-full font-mono text-xs"
                  />
                </div>
              </div>
            </div>

            <div class="bg-base-200/50 rounded-lg p-4">
              <h3 class="text-sm font-semibold mb-1">Optional: Notch Endpoints</h3>
              <p class="text-xs text-base-content/60 mb-3">
                If the lever has discrete notch positions, provide these endpoints.
              </p>
              <div class="space-y-3">
                <div>
                  <label class="label py-1">
                    <span class="label-text text-xs">Notch Count Endpoint</span>
                  </label>
                  <.input
                    field={@form[:notch_count_endpoint]}
                    type="text"
                    placeholder="e.g., CurrentDrivableActor/Throttle(Lever).NotchCount"
                    class="input input-bordered input-sm w-full font-mono text-xs"
                  />
                </div>
                <div>
                  <label class="label py-1">
                    <span class="label-text text-xs">Current Notch Index Endpoint</span>
                  </label>
                  <.input
                    field={@form[:notch_index_endpoint]}
                    type="text"
                    placeholder="e.g., CurrentDrivableActor/Throttle(Lever).CurrentNotch"
                    class="input input-bordered input-sm w-full font-mono text-xs"
                  />
                </div>
              </div>
            </div>
          </div>

          <div class="flex justify-end gap-2 mt-6">
            <button type="button" phx-click="close_lever_config_modal" class="btn btn-ghost">
              Cancel
            </button>
            <button type="submit" class="btn btn-primary">
              {if @has_existing_config, do: "Update Configuration", else: "Save Configuration"}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
