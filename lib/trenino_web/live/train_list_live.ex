defmodule TreninoWeb.TrainListLive do
  @moduledoc """
  LiveView for listing and managing train configurations.

  Displays all saved train configurations and highlights the currently
  active train based on the simulator connection.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.SharedComponents

  alias Trenino.Train, as: TrainContext
  alias Trenino.Serial.Connection

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      TrainContext.subscribe()
    end

    trains = TrainContext.list_trains(preload: [:elements])
    current_identifier = TrainContext.get_current_identifier()
    active_train = TrainContext.get_active_train()

    {:ok,
     socket
     |> assign(:trains, trains)
     |> assign(:current_identifier, current_identifier)
     |> assign(:active_train, active_train)
     |> assign(:multiple_matches, nil)}
  end

  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  @impl true
  def handle_info({:train_detected, %{identifier: identifier, train: train}}, socket) do
    {:noreply,
     socket
     |> assign(:current_identifier, identifier)
     |> assign(:active_train, train)
     |> assign(:multiple_matches, nil)}
  end

  @impl true
  def handle_info({:multiple_trains_match, %{identifier: identifier, trains: trains}}, socket) do
    {:noreply,
     socket
     |> assign(:current_identifier, identifier)
     |> assign(:active_train, nil)
     |> assign(:multiple_matches, trains)}
  end

  @impl true
  def handle_info({:train_changed, train}, socket) do
    {:noreply, assign(socket, :active_train, train)}
  end

  @impl true
  def handle_info({:detection_error, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

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
  def render(assigns) do
    active_train_id =
      if assigns.active_train, do: assigns.active_train.id, else: nil

    assigns = assign(assigns, :active_train_id, active_train_id)

    ~H"""
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <.page_header
          title="Trains"
          subtitle="Manage train configurations"
          action_path={~p"/trains/new"}
          action_text="New Train"
        />

        <.multiple_matches_banner
          :if={@multiple_matches != nil}
          identifier={@current_identifier}
          trains={@multiple_matches}
        />

        <.unconfigured_banner
          :if={@current_identifier && @active_train == nil && @multiple_matches == nil}
          identifier={@current_identifier}
        />

        <.empty_state
          :if={Enum.empty?(@trains)}
          icon="hero-truck"
          heading="No Train Configurations"
          description="Create a train configuration to set up controls for your simulator trains."
          action_path={~p"/trains/new"}
          action_text="Create Train Configuration"
        />

        <div :if={not Enum.empty?(@trains)} class="space-y-4">
          <.list_card
            :for={train <- @trains}
            active={train.id == @active_train_id}
            navigate_to={~p"/trains/#{train.id}"}
            title={train.name}
            description={train.description}
            metadata={[train.identifier, element_count_text(length(train.elements))]}
          />
        </div>
      </div>
    </main>
    """
  end

  attr :identifier, :string, required: true
  attr :trains, :list, required: true

  defp multiple_matches_banner(assigns) do
    ~H"""
    <div class="alert alert-error mb-6">
      <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
      <div class="flex-1">
        <h3 class="font-semibold">Multiple Trains Match</h3>
        <p class="text-sm">
          The detected identifier "<span class="font-mono">{@identifier}</span>" matches multiple train configurations.
          Each train identifier must be a unique prefix.
        </p>
        <ul class="text-sm mt-2 list-disc list-inside">
          <li :for={train <- @trains}>
            <span class="font-semibold">{train.name}</span>
            <span class="text-base-content/60">({train.identifier})</span>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :identifier, :string, required: true

  defp unconfigured_banner(assigns) do
    ~H"""
    <div class="alert alert-info mb-6">
      <.icon name="hero-information-circle" class="w-5 h-5" />
      <div class="flex-1">
        <h3 class="font-semibold">Train Detected</h3>
        <p class="text-sm">
          A train with identifier "<span class="font-mono">{@identifier}</span>" is connected but not configured.
        </p>
      </div>
      <.link navigate={~p"/trains/new?identifier=#{@identifier}"} class="btn btn-sm btn-primary">
        Configure
      </.link>
    </div>
    """
  end

  defp element_count_text(0), do: "No elements"
  defp element_count_text(1), do: "1 element"
  defp element_count_text(n), do: "#{n} elements"
end
