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
     |> assign(:api_key_status, api_key_status())
     |> assign(:url_error, nil)}
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

  defp url_error(""), do: "URL is required"

  defp url_error(url) do
    if String.starts_with?(url, ["http://", "https://"]) do
      nil
    else
      "URL must start with http:// or https://"
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
  def handle_event("validate_simulator", %{"simulator" => %{"url" => url}}, socket) do
    {:noreply, assign(socket, :url_error, url_error(url))}
  end

  @impl true
  def handle_event("save_simulator", %{"simulator" => params}, socket) do
    %{"url" => url, "api_key" => api_key} = params

    case url_error(url) do
      nil ->
        {:ok, _} = Settings.set_simulator_url(url)

        if api_key != "" do
          {:ok, _} = Settings.set_api_key(api_key)
        end

        SimulatorConnection.reconfigure()

        {:noreply,
         socket
         |> assign(:simulator_url, Settings.simulator_url())
         |> assign(:api_key_status, api_key_status())
         |> assign(:url_error, nil)
         |> put_flash(:info, "Simulator configuration saved")}

      error ->
        {:noreply, assign(socket, :url_error, error)}
    end
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
        <header class="mb-10">
          <h1 class="text-2xl font-semibold">Settings</h1>
        </header>

        <section>
          <h2 class="text-base font-semibold mb-5">Error Reporting</h2>
          <label class="flex items-start justify-between gap-6 cursor-pointer">
            <div>
              <div class="font-medium">Share anonymous error reports</div>
              <div class="text-sm text-base-content/70 mt-1">
                Crash reports are sent to help fix bugs. No personal data is included.
              </div>
              <.link
                navigate={~p"/consent"}
                class="text-sm text-base-content/60 underline underline-offset-2 hover:text-base-content transition-colors mt-3 inline-block"
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
          <h2 class="text-base font-semibold mb-5">Simulator Connection</h2>
          <.form
            for={%{}}
            as={:simulator}
            phx-submit="save_simulator"
            phx-change="validate_simulator"
            data-testid="simulator-form"
          >
            <div class="mb-5">
              <label class="label pb-1.5" for="simulator_url">
                <span class="label-text">URL</span>
              </label>
              <input
                id="simulator_url"
                type="text"
                name="simulator[url]"
                value={@simulator_url}
                placeholder="http://192.168.1.x:31270"
                class={[
                  "input input-bordered w-full font-mono",
                  @url_error && "input-error"
                ]}
              />
              <div :if={@url_error} class="flex items-center gap-1.5 mt-1.5 text-xs text-error">
                <.icon name="hero-exclamation-circle" class="w-3.5 h-3.5 shrink-0" />
                {@url_error}
              </div>
            </div>

            <div class="mb-6">
              <label class="label pb-1.5" for="simulator_api_key">
                <span class="label-text">API Key</span>
              </label>
              <%= case @api_key_status do %>
                <% :found_in_file -> %>
                  <div class="flex items-center gap-2 px-3 py-2 mb-3 text-sm bg-base-200 rounded border border-base-300">
                    <.icon name="hero-check-circle" class="w-4 h-4 text-base-content/70 shrink-0" />
                    <span class="text-base-content/70">
                      Found in your Train Simulator folder, updated automatically.
                    </span>
                  </div>
                <% :missing -> %>
                  <div class="alert alert-warning px-3 py-2 mb-3 text-sm">
                    <.icon name="hero-exclamation-triangle" class="w-4 h-4 shrink-0" />
                    <span>
                      Not found in your Train Simulator folder. Enter a key below.
                    </span>
                  </div>
                <% :unsupported_platform -> %>
                  <div class="alert px-3 py-2 mb-3 text-sm">
                    <.icon name="hero-information-circle" class="w-4 h-4 shrink-0" />
                    <span>Auto-detection is only available on Windows. Enter a key below.</span>
                  </div>
              <% end %>
              <input
                id="simulator_api_key"
                type="password"
                name="simulator[api_key]"
                placeholder="Leave blank to keep current value"
                class="input input-bordered w-full font-mono"
              />
              <div class="mt-1.5 text-xs text-base-content/50">
                <%= if @api_key_status == :found_in_file do %>
                  Enter a new key to override the one read from your Train Simulator folder.
                <% else %>
                  Found at
                  <span class="font-mono break-all">Documents\My Games\TrainSimWorld6\Saved\Config\CommAPIKey.txt</span>
                  on the PC running Train Simulator.
                <% end %>
              </div>
            </div>

            <div class="flex justify-end">
              <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
                Save
              </button>
            </div>
          </.form>
        </section>
      </div>
    </main>
    """
  end
end
