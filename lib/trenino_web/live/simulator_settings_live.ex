defmodule TreninoWeb.SimulatorSettingsLive do
  @moduledoc """
  Connection settings for one simulator: `/settings/simulators/tsw` for Train
  Sim World and `/settings/simulators/simrail` for SimRail (beta).

  Trenino connects to one simulator at a time. Saving a page makes its
  simulator the one Trenino connects to, then tests the connection.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents

  alias Trenino.Serial.Connection
  alias Trenino.Settings
  alias Trenino.Settings.Simulator, as: SimulatorSettings
  alias Trenino.Simulator.Connection, as: SimulatorConnection

  @simulators %{"tsw" => :tsw, "simrail" => :simrail}

  @impl true
  def mount(%{"simulator" => param}, _session, socket) do
    case {Map.fetch(@simulators, param), socket.assigns.beta_simrail} do
      {{:ok, :simrail}, false} ->
        {:ok, push_navigate(socket, to: ~p"/settings/simulators/tsw")}

      {{:ok, simulator}, _beta_simrail} ->
        {:ok, mount_simulator(socket, simulator)}

      {:error, _beta_simrail} ->
        {:ok, push_navigate(socket, to: ~p"/settings")}
    end
  end

  defp mount_simulator(socket, simulator) do
    socket
    |> assign(:page_title, "#{simulator_name(simulator)} connection")
    |> assign(:simulator, simulator)
    |> assign(:active_simulator, active_simulator(socket))
    |> assign(:simulator_url, Settings.simulator_url())
    |> assign(:simrail_url, Settings.simrail_url())
    |> assign(:simrail_token_saved, simrail_token_saved?())
    |> assign(:api_key_status, api_key_status())
    |> assign(:connection_result, nil)
    |> assign(:connection_test_ref, nil)
    |> assign(:url_error, nil)
  end

  # With the SimRail beta off Trenino offers only Train Sim World.
  defp active_simulator(socket) do
    if socket.assigns.beta_simrail, do: Settings.simulator(), else: :tsw
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

  defp url_param(:tsw, params), do: params["url"]
  defp url_param(:simrail, params), do: params["simrail_url"]

  defp save_simulator_settings(:tsw, params) do
    {:ok, _} = Settings.set_simulator_url(params["url"])

    if present?(params["api_key"]) do
      {:ok, _} = Settings.set_api_key(params["api_key"])
    end

    {:ok, _} = Settings.set_simulator(:tsw)
  end

  defp save_simulator_settings(:simrail, params) do
    {:ok, _} = Settings.set_simrail_url(params["simrail_url"])

    if present?(params["simrail_token"]) do
      {:ok, _} = Settings.set_simrail_token(params["simrail_token"])
    end

    {:ok, _} = Settings.set_simulator(:simrail)
  end

  defp present?(value), do: is_binary(value) and value != ""

  defp url_error(nil), do: nil
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
  def handle_event("nav_retry_simulator", _, socket) do
    SimulatorConnection.retry_connection()
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_simulator", %{"simulator" => params}, socket) do
    {:noreply, assign(socket, :url_error, url_error(url_param(socket.assigns.simulator, params)))}
  end

  @impl true
  def handle_event("save_simulator", %{"simulator" => params}, socket) do
    simulator = socket.assigns.simulator

    case url_error(url_param(simulator, params) || "") do
      nil ->
        save_simulator_settings(simulator, params)

        {:noreply,
         socket
         |> assign(:active_simulator, simulator)
         |> assign(:simulator_url, Settings.simulator_url())
         |> assign(:simrail_url, Settings.simrail_url())
         |> assign(:simrail_token_saved, simrail_token_saved?())
         |> assign(:api_key_status, api_key_status())
         |> assign(:url_error, nil)
         |> test_connection("Settings saved. Testing connection…")}

      error ->
        {:noreply, assign(socket, :url_error, error)}
    end
  end

  @impl true
  def handle_event("remove_simrail_token", _params, socket) do
    :ok = Settings.clear_simrail_token()
    socket = assign(socket, :simrail_token_saved, false)

    # Only reconnect when SimRail is the simulator Trenino connects to.
    if socket.assigns.active_simulator == :simrail do
      {:noreply, test_connection(socket, "Token removed. Testing connection…")}
    else
      {:noreply, assign(socket, :connection_result, "Token removed.")}
    end
  end

  defp test_connection(socket, message) do
    SimulatorConnection.reconfigure()
    test_ref = make_ref()
    Process.send_after(self(), {:connection_test_timeout, test_ref}, 15_000)

    socket
    |> assign(:connection_result, message)
    |> assign(:connection_test_ref, test_ref)
  end

  defp simrail_token_saved?, do: Settings.simrail_token() not in [nil, ""]

  # PubSub handlers (mirror other LiveViews)
  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    socket = assign(socket, :nav_simulator_status, status)

    if socket.assigns.connection_result do
      {:noreply,
       socket
       |> assign(:connection_result, connection_feedback(status, socket.assigns.simulator))
       |> assign(
         :connection_test_ref,
         if(status.status == :connecting, do: socket.assigns.connection_test_ref)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_info(
        {:connection_test_timeout, ref},
        %{assigns: %{connection_test_ref: ref}} = socket
      ) do
    {:noreply,
     socket
     |> assign(:connection_test_ref, nil)
     |> assign(:connection_result, no_result_feedback(socket.assigns.simulator))}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp simulator_name(:tsw), do: "Train Sim World"
  defp simulator_name(:simrail), do: "SimRail"

  defp no_result_feedback(:tsw),
    do:
      "Settings saved. No connection result received. Check that Train Sim World is running with its API enabled, then try again."

  defp no_result_feedback(:simrail),
    do:
      "Settings saved. No connection result received. Check that SimRail is running with the TreninoBridge mod, then try again."

  defp connection_feedback(%{status: :connecting}, _simulator),
    do: "Settings saved. Testing connection…"

  defp connection_feedback(%{status: :connected}, :tsw), do: "Connected to Train Sim World."

  defp connection_feedback(%{status: :error, last_error: :invalid_key}, :tsw),
    do:
      "Settings saved. The API key was rejected. Copy the key from Train Sim World and try again."

  defp connection_feedback(%{status: :needs_config}, :tsw),
    do: "Settings saved. Add an API key from Train Sim World, then test the connection again."

  defp connection_feedback(_status, :tsw),
    do:
      "Settings saved. Could not connect to Train Sim World. Check the URL, start the game with its API enabled, and try again."

  defp connection_feedback(%{status: :connected}, :simrail), do: "Connected to SimRail."

  defp connection_feedback(%{status: :error, last_error: :invalid_key}, :simrail),
    do:
      "Settings saved. The bridge rejected the token. Copy the token from SimRail's MelonPreferences.cfg and try again."

  defp connection_feedback(%{status: :needs_config}, :simrail),
    do: "Settings saved. Add the bridge URL, then test the connection again."

  defp connection_feedback(_status, :simrail),
    do:
      "Settings saved. Could not connect to SimRail. Check the URL, start SimRail with the TreninoBridge mod installed, and try again."

  @impl true
  def render(assigns) do
    ~H"""
    <.breadcrumb items={[
      %{label: "Settings", path: ~p"/settings"},
      %{label: simulator_name(@simulator)}
    ]} />
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <header class="mb-8">
          <h1 class="text-2xl font-semibold">{simulator_name(@simulator)}</h1>
          <p id="active-simulator-note" class="text-sm text-muted mt-2">
            <%= if @active_simulator == @simulator do %>
              Trenino connects to {simulator_name(@simulator)}.
            <% else %>
              Trenino connects to {simulator_name(@active_simulator)}. Saving here switches
              to {simulator_name(@simulator)}.
            <% end %>
          </p>
        </header>

        <div
          :if={@simulator == :simrail and @beta_simrail_onboarding}
          id="simrail-setup-callout"
          class="flex items-center justify-between gap-4 px-4 py-3 mb-8 rounded border border-base-300 bg-base-200"
        >
          <div class="text-sm">
            <div class="font-medium">Set up SimRail <span class="badge badge-sm">Beta</span></div>
            <div class="text-muted mt-1">
              Install the TreninoBridge mod into SimRail and connect, step by step.
            </div>
          </div>
          <.link
            id="open-simrail-setup"
            navigate={~p"/settings/simulators/simrail/setup"}
            class="btn btn-sm btn-primary shrink-0"
          >
            Start setup
          </.link>
        </div>

        <.form
          id="simulator-form"
          for={%{}}
          as={:simulator}
          phx-submit="save_simulator"
          phx-change="validate_simulator"
          data-testid="simulator-form"
        >
          <div :if={@simulator == :simrail} id="simrail-settings">
            <div class="mb-5">
              <label class="label pb-1.5" for="simrail_url">
                <span class="label-text">Bridge URL</span>
              </label>
              <input
                id="simrail_url"
                type="text"
                name="simulator[simrail_url]"
                value={@simrail_url}
                placeholder="http://127.0.0.1:31275"
                class={[
                  "input input-bordered w-full font-mono",
                  @url_error && "input-error"
                ]}
              />
              <div :if={@url_error} class="flex items-center gap-1.5 mt-1.5 text-xs text-error">
                <.icon name="hero-exclamation-circle" class="w-3.5 h-3.5 shrink-0" />
                {@url_error}
              </div>
              <div class="mt-1.5 text-xs text-muted">
                Trenino reaches SimRail through the TreninoBridge mod running inside the game.
              </div>
            </div>

            <div class="mb-6">
              <label class="label pb-1.5" for="simrail_token">
                <span class="label-text">Token</span>
              </label>
              <div
                id="simrail-token-status"
                class="flex items-center justify-between gap-2 px-3 py-2 mb-3 text-sm bg-base-200 rounded border border-base-300"
              >
                <%= if @simrail_token_saved do %>
                  <span class="flex items-center gap-2">
                    <.icon name="hero-key" class="w-4 h-4 shrink-0" /> A token is saved.
                  </span>
                  <button
                    id="remove-simrail-token"
                    type="button"
                    class="btn btn-ghost btn-xs text-xs"
                    phx-click="remove_simrail_token"
                    data-confirm="Remove the saved token? Trenino will connect without one."
                  >
                    Remove token
                  </button>
                <% else %>
                  <span class="text-muted">No token saved.</span>
                <% end %>
              </div>
              <input
                id="simrail_token"
                type="password"
                name="simulator[simrail_token]"
                placeholder={
                  if @simrail_token_saved,
                    do: "Leave blank to keep the saved token",
                    else: "Leave blank when SimRail runs on this computer"
                }
                class="input input-bordered w-full font-mono"
              />
              <div id="simrail-token-help" class="mt-1.5 text-xs text-muted">
                Only needed when SimRail runs on another computer. Copy
                <span class="font-mono">Token</span>
                from <span class="font-mono break-all">SimRail\UserData\MelonPreferences.cfg</span>.
              </div>
            </div>
          </div>

          <div :if={@simulator == :tsw} id="tsw-settings">
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
                    <.icon name="hero-check-circle" class="w-4 h-4 text-success shrink-0" />
                    <span>
                      Found in your Train Sim World folder, updated automatically.
                    </span>
                  </div>
                <% :missing -> %>
                  <div class="alert alert-soft alert-warning px-3 py-2 mb-3 text-sm">
                    <.icon name="hero-exclamation-triangle" class="w-4 h-4 shrink-0" />
                    <span>
                      Not found in your Train Sim World folder. Enter a key below.
                    </span>
                  </div>
                <% :unsupported_platform -> %>
                  <div class="alert alert-soft alert-info px-3 py-2 mb-3 text-sm">
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
              <div id="api-key-help" class="mt-1.5 text-xs text-muted">
                <%= if @api_key_status == :unsupported_platform do %>
                  On the Windows PC running Train Sim World, copy the key from
                  <span class="font-mono break-all">Documents\My Games\TrainSimWorld7\Saved\Config\CommAPIKey.txt</span>
                  (or <span class="font-mono">TrainSimWorld6</span>) and paste it here.
                <% else %>
                  Trenino checks <span class="font-mono">TrainSimWorld7</span>
                  first, then <span class="font-mono">TrainSimWorld6</span>, under
                  <span class="font-mono break-all">Documents\My Games</span>
                  for <span class="font-mono break-all">Saved\Config\CommAPIKey.txt</span>.
                  A key entered here overrides the detected key.
                <% end %>
              </div>
            </div>
          </div>

          <p
            :if={@connection_result}
            id="simulator-connection-result"
            role="status"
            aria-live="polite"
            class="mb-4 text-sm"
          >
            {@connection_result}
          </p>
          <div class="flex justify-end">
            <button type="submit" class="btn btn-primary" phx-disable-with="Saving and testing...">
              Save and test connection
            </button>
          </div>
        </.form>
      </div>
    </main>
    """
  end
end
