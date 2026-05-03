defmodule TreninoWeb.SettingsLive do
  @moduledoc """
  Settings page. Exposes the error reporting preference and simulator connection settings.
  """

  use TreninoWeb, :live_view

  alias Trenino.Serial.Connection
  alias Trenino.Settings
  alias Trenino.Settings.Simulator, as: SimulatorSettings
  alias Trenino.Simulator.Connection, as: SimulatorConnection

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:error_reporting_enabled, Settings.error_reporting?())
     |> assign(:simulator_url, Settings.simulator_url())
     |> assign(:api_key_status, api_key_status())}
  end

  defp api_key_status do
    if SimulatorSettings.windows?() do
      case SimulatorSettings.read_from_file() do
        {:ok, _key} -> :found_in_file
        {:error, _} -> :missing
      end
    else
      :unsupported_platform
    end
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

  @impl true
  def handle_event("save_simulator", %{"simulator" => params}, socket) do
    %{"url" => url, "api_key" => api_key} = params

    {:ok, _} = Settings.set_simulator_url(url)

    if api_key != "" do
      {:ok, _} = Settings.set_api_key(api_key)
    end

    SimulatorConnection.reconfigure()

    {:noreply,
     socket
     |> assign(:simulator_url, Settings.simulator_url())
     |> assign(:api_key_status, api_key_status())
     |> put_flash(:info, "Simulator configuration saved")}
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
            <div class="mt-3">
              <.link navigate={~p"/consent"} class="text-sm link link-primary">
                Review consent details
              </.link>
            </div>
          </div>
        </section>

        <section class="card bg-base-100 border border-base-300">
          <div class="card-body">
            <div class="text-xs uppercase tracking-wider text-base-content/60 mb-2">
              Simulator Connection
            </div>
            <.form for={%{}} as={:simulator} phx-submit="save_simulator" data-testid="simulator-form">
              <label class="form-control w-full mb-3">
                <span class="label-text text-sm">URL</span>
                <input
                  type="text"
                  name="simulator[url]"
                  value={@simulator_url}
                  class="input input-bordered font-mono"
                />
              </label>

              <div class="mb-3">
                <span class="label-text text-sm">API Key</span>
                <%= case @api_key_status do %>
                  <% :found_in_file -> %>
                    <div class="alert alert-success p-2 mt-1 text-sm">
                      <.icon name="hero-check-circle" class="w-4 h-4" />
                      Found in TSW file — updated automatically
                    </div>
                  <% :missing -> %>
                    <div class="alert alert-warning p-2 mt-1 text-sm">
                      <.icon name="hero-exclamation-triangle" class="w-4 h-4" />
                      Not found in TSW file — enter a key below
                    </div>
                  <% :unsupported_platform -> %>
                    <div class="alert p-2 mt-1 text-sm">
                      <.icon name="hero-information-circle" class="w-4 h-4" />
                      Auto-detection only available on Windows — enter a key below
                    </div>
                <% end %>
              </div>

              <label class="form-control w-full mb-3">
                <span class="label-text text-sm text-base-content/60">Override API key manually</span>
                <input
                  type="password"
                  name="simulator[api_key]"
                  placeholder="Leave blank to keep current value"
                  class="input input-bordered font-mono"
                />
              </label>

              <div class="flex justify-end">
                <button type="submit" class="btn btn-primary">Save</button>
              </div>
            </.form>
          </div>
        </section>
      </div>
    </main>
    """
  end
end
