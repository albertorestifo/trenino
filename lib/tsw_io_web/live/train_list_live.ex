defmodule TswIoWeb.TrainListLive do
  @moduledoc """
  LiveView for listing and managing train configurations.

  Displays all saved train configurations and highlights the currently
  active train based on the simulator connection.
  """

  use TswIoWeb, :live_view

  import TswIoWeb.NavComponents

  alias TswIo.Train, as: TrainContext
  alias TswIo.Serial.Connection

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
     |> assign(:active_train, active_train)}
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
     |> assign(:active_train, train)}
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
    <div class="min-h-screen flex flex-col">
      <.nav_header
        devices={@nav_devices}
        simulator_status={@nav_simulator_status}
        dropdown_open={@nav_dropdown_open}
        scanning={@nav_scanning}
        current_path={@nav_current_path}
      />

      <main class="flex-1 p-4 sm:p-8">
        <div class="max-w-2xl mx-auto">
          <header class="mb-8 flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-semibold">Trains</h1>
              <p class="text-sm text-base-content/70 mt-1">
                Manage train configurations
              </p>
            </div>
            <.link navigate={~p"/trains/new"} class="btn btn-primary">
              <.icon name="hero-plus" class="w-4 h-4" /> New Train
            </.link>
          </header>

          <.unconfigured_banner
            :if={@current_identifier && @active_train == nil}
            identifier={@current_identifier}
          />

          <.empty_state :if={Enum.empty?(@trains) && @active_train != nil} />
          <.empty_state :if={Enum.empty?(@trains) && @current_identifier == nil} />

          <div :if={not Enum.empty?(@trains)} class="space-y-4">
            <.train_card
              :for={train <- @trains}
              train={train}
              active={train.id == @active_train_id}
            />
          </div>
        </div>
      </main>
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

  defp empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <.icon name="hero-truck" class="w-16 h-16 text-base-content/20" />
      <h2 class="mt-6 text-xl font-semibold">No Train Configurations</h2>
      <p class="mt-2 text-base-content/70 max-w-sm">
        Create a train configuration to set up controls for your simulator trains.
      </p>
      <.link navigate={~p"/trains/new"} class="btn btn-primary mt-6">
        <.icon name="hero-plus" class="w-4 h-4" /> Create Train Configuration
      </.link>
    </div>
    """
  end

  attr :train, :map, required: true
  attr :active, :boolean, required: true

  defp train_card(assigns) do
    element_count = length(assigns.train.elements)
    assigns = assign(assigns, :element_count, element_count)

    ~H"""
    <div class={[
      "rounded-xl transition-colors group",
      if(@active,
        do: "border-2 border-success bg-success/5",
        else: "border border-base-300 bg-base-200/50 hover:bg-base-200"
      )
    ]}>
      <div class="flex items-start justify-between gap-4 p-5">
        <.link navigate={~p"/trains/#{@train.id}"} class="flex-1 cursor-pointer">
          <div class="flex items-center gap-2">
            <h3 class="font-medium truncate group-hover:text-primary transition-colors">
              {@train.name}
            </h3>
            <span
              :if={@active}
              class="badge badge-success badge-sm flex items-center gap-1"
            >
              <span class="w-1.5 h-1.5 rounded-full bg-success-content animate-pulse" /> Active
            </span>
          </div>
          <p :if={@train.description} class="text-sm text-base-content/70 mt-1 line-clamp-2">
            {@train.description}
          </p>
          <div class="mt-2 flex items-center gap-4 text-xs text-base-content/60">
            <span class="font-mono">{@train.identifier}</span>
            <span>{element_count_text(@element_count)}</span>
          </div>
        </.link>

        <.icon
          name="hero-chevron-right"
          class="w-5 h-5 text-base-content/30 group-hover:text-base-content/50 transition-colors flex-shrink-0"
        />
      </div>
    </div>
    """
  end

  defp element_count_text(0), do: "No elements"
  defp element_count_text(1), do: "1 element"
  defp element_count_text(n), do: "#{n} elements"
end
