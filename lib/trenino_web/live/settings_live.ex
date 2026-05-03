defmodule TreninoWeb.SettingsLive do
  @moduledoc """
  Settings page. Currently exposes the error reporting preference.
  The simulator connection section is added in a later task.
  """

  use TreninoWeb, :live_view

  alias Trenino.Serial.Connection
  alias Trenino.Settings

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :error_reporting_enabled, Settings.error_reporting?())}
  end

  # Nav events (mirror other LiveViews)
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
  def handle_event("toggle_error_reporting", _params, socket) do
    new_value = if socket.assigns.error_reporting_enabled, do: :disabled, else: :enabled
    {:ok, _} = Settings.set_error_reporting(new_value)
    {:noreply, assign(socket, :error_reporting_enabled, new_value == :enabled)}
  end

  # PubSub handlers (mirror other LiveViews)
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <header class="mb-8">
          <h1 class="text-2xl font-semibold">Settings</h1>
          <p class="text-sm text-base-content/70 mt-1">
            Configure your Trenino preferences
          </p>
        </header>

        <section class="card bg-base-100 border border-base-300 mb-4">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wider text-base-content/60 mb-2">
              Error Reporting
            </div>
            <div class="flex items-center justify-between gap-4">
              <div>
                <div class="font-medium">Share anonymous error reports</div>
                <div class="text-sm text-base-content/70">
                  Crash reports are sent to help fix bugs. No personal data is included.
                </div>
              </div>
              <input
                type="checkbox"
                class="toggle toggle-primary"
                data-testid="error-reporting-toggle"
                phx-click="toggle_error_reporting"
                checked={@error_reporting_enabled}
              />
            </div>
          </div>
        </section>
      </div>
    </main>
    """
  end
end
