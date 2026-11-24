defmodule TreninoWeb.SettingsLive do
  @moduledoc """
  Settings page: error reporting, beta features and the list of simulators,
  each with its own connection page (`TreninoWeb.SimulatorSettingsLive`).
  """

  use TreninoWeb, :live_view

  alias Trenino.Beta
  alias Trenino.Serial.Connection
  alias Trenino.Settings
  alias Trenino.Simulator.Connection, as: SimulatorConnection

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Settings")
     |> assign(:error_reporting_enabled, Settings.error_reporting?())
     |> assign(:beta_configurable, Beta.configurable?())
     |> assign(:beta_features_enabled, Settings.beta_features?())
     |> assign(:simrail_onboarding_enabled, Settings.beta_feature?(:simrail_onboarding))
     |> assign(:simulator, Settings.simulator())}
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
  def handle_event("nav_retry_simulator", _, socket) do
    SimulatorConnection.retry_connection()
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_error_reporting", _params, socket) do
    new_value = if socket.assigns.error_reporting_enabled, do: :disabled, else: :enabled
    {:ok, _} = Settings.set_error_reporting(new_value)
    {:noreply, assign(socket, :error_reporting_enabled, new_value == :enabled)}
  end

  # Beta assigns come from NavHook on mount; refresh them so the page reflects
  # the toggles right away.
  @impl true
  def handle_event("toggle_beta_features", _params, socket) do
    new_value = if socket.assigns.beta_features_enabled, do: :disabled, else: :enabled
    {:ok, _} = Settings.set_beta_features(new_value)

    {:noreply,
     socket
     |> assign(:beta_features_enabled, new_value == :enabled)
     |> refresh_beta_assigns()}
  end

  @impl true
  def handle_event("toggle_simrail_onboarding", _params, socket) do
    new_value = if socket.assigns.simrail_onboarding_enabled, do: :disabled, else: :enabled
    {:ok, _} = Settings.set_beta_feature(:simrail_onboarding, new_value)

    {:noreply,
     socket
     |> assign(:simrail_onboarding_enabled, new_value == :enabled)
     |> refresh_beta_assigns()}
  end

  defp refresh_beta_assigns(socket) do
    socket
    |> assign(:beta_gauges, Beta.enabled?(:gauges))
    |> assign(:beta_selectors, Beta.enabled?(:selectors))
    |> assign(:beta_simrail, Beta.enabled?(:simrail))
    |> assign(:beta_simrail_onboarding, Beta.enabled?(:simrail_onboarding))
  end

  # PubSub handlers (mirror other LiveViews)
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply,
     socket
     |> assign(:nav_simulator_status, status)
     |> assign(:simulator, Settings.simulator())}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # With the SimRail beta off Trenino offers only Train Sim World.
  defp simulators(true = _beta_simrail) do
    simulators(false) ++ [%{id: :simrail, name: "SimRail", beta: true}]
  end

  defp simulators(false = _beta_simrail), do: [%{id: :tsw, name: "Train Sim World", beta: false}]

  defp active_simulator(simulator, beta_simrail), do: if(beta_simrail, do: simulator, else: :tsw)

  defp status_label(%{status: :connected}), do: {:ok, "Connected"}
  defp status_label(%{status: :connecting}), do: {:busy, "Connecting"}
  defp status_label(%{status: :error}), do: {:error, "Failed"}
  defp status_label(_status), do: {:warn, "Not connected"}

  @impl true
  def render(assigns) do
    ~H"""
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <header class="mb-10">
          <h1 class="text-2xl font-semibold">Settings</h1>
        </header>

        <section>
          <h2 class="text-xl font-semibold mb-5">Error Reporting</h2>
          <label class="flex items-start justify-between gap-6 cursor-pointer">
            <div>
              <div class="font-medium">Share anonymous error reports</div>
              <div class="text-sm text-muted mt-1">
                Crash reports are sent to help fix bugs. No personal data is included.
              </div>
              <.link
                navigate={~p"/consent"}
                class="text-sm text-muted underline underline-offset-2 hover:text-base-content transition-colors mt-3 inline-block"
              >
                Review consent details
              </.link>
            </div>
            <input
              type="checkbox"
              class="toggle toggle-primary mt-0.5 shrink-0"
              data-testid="error-reporting-toggle"
              phx-click="toggle_error_reporting"
              checked={@error_reporting_enabled}
            />
          </label>
        </section>

        <div class="border-t border-base-300 my-10"></div>

        <section>
          <h2 class="text-xl font-semibold mb-5">Beta Features</h2>
          <label
            :if={@beta_configurable}
            class="flex items-start justify-between gap-6 cursor-pointer"
          >
            <div>
              <div class="font-medium">Enable beta features</div>
              <div class="text-sm text-muted mt-1">
                Try features that are still being tested: X27 gauges such as speedometers
                (controller firmware 3.3.0 or newer), selectors that use a potentiometer as a rotary switch,
                and SimRail through the TreninoBridge mod. They may change or have rough edges.
              </div>
            </div>
            <input
              type="checkbox"
              class="toggle toggle-primary mt-0.5 shrink-0"
              data-testid="beta-features-toggle"
              phx-click="toggle_beta_features"
              checked={@beta_features_enabled}
            />
          </label>
          <label
            :if={@beta_configurable and @beta_features_enabled}
            id="simrail-onboarding-option"
            class="flex items-start justify-between gap-6 cursor-pointer mt-6 pl-4 border-l-2 border-base-300"
          >
            <div>
              <div class="font-medium">SimRail setup assistant</div>
              <div class="text-sm text-muted mt-1">
                A guided setup that installs the TreninoBridge mod into SimRail and connects
                to it. Earlier in testing than the other beta features.
              </div>
            </div>
            <input
              type="checkbox"
              class="toggle toggle-primary mt-0.5 shrink-0"
              data-testid="simrail-onboarding-toggle"
              phx-click="toggle_simrail_onboarding"
              checked={@simrail_onboarding_enabled}
            />
          </label>
          <p :if={!@beta_configurable} class="text-sm text-muted">
            Beta features are always on in this build.
          </p>
        </section>

        <div class="border-t border-base-300 my-10"></div>

        <section id="simulators">
          <h2 class="text-xl font-semibold mb-2">Simulator Connection</h2>
          <p class="text-sm text-muted mb-5">
            Trenino connects to one simulator at a time. Open a simulator to change how
            Trenino reaches it.
          </p>
          <ul class="divide-y divide-base-300 border border-base-300 rounded">
            <li :for={sim <- simulators(@beta_simrail)} id={"simulator-#{sim.id}"}>
              <.link
                navigate={~p"/settings/simulators/#{sim.id}"}
                class="flex items-center justify-between gap-4 px-4 py-3 hover:bg-base-200 transition-colors"
              >
                <div>
                  <div class="font-medium flex items-center gap-2">
                    {sim.name}
                    <span :if={sim.beta} class="badge badge-sm">Beta</span>
                  </div>
                  <div class="text-xs text-muted mt-1">
                    <%= if active_simulator(@simulator, @beta_simrail) == sim.id do %>
                      <.status_indicator
                        kind={elem(status_label(@nav_simulator_status), 0)}
                        label={"In use · " <> elem(status_label(@nav_simulator_status), 1)}
                      />
                    <% else %>
                      Not in use
                    <% end %>
                  </div>
                </div>
                <.icon name="hero-chevron-right" class="w-4 h-4 text-muted shrink-0" />
              </.link>
            </li>
          </ul>
        </section>
      </div>
    </main>
    """
  end
end
