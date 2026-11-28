defmodule TreninoWeb.SimRailSetupLive do
  @moduledoc """
  Guided SimRail setup (beta, `:simrail_onboarding`): finds the SimRail
  folder, checks MelonLoader and its settings, installs the bundled
  TreninoBridge mod and connects to it.

  Every step is worked out from the files on disk (`Trenino.Simulator.SimRailSetup`),
  so the page can be left and reopened at any point.
  """

  use TreninoWeb, :live_view

  import TreninoWeb.NavComponents

  alias Trenino.Serial.Connection
  alias Trenino.Settings
  alias Trenino.Simulator.Backend.SimRail, as: SimRailBackend
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.SimRailSetup

  @melonloader_url "https://github.com/LavaGang/MelonLoader.Installer/releases/latest"

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns.beta_simrail_onboarding do
      game_dir = Settings.simrail_game_dir() || SimRailSetup.detect_game_dir()

      {:ok,
       socket
       |> assign(:page_title, "Set up SimRail")
       |> assign(:melonloader_url, @melonloader_url)
       |> assign(:bundle, bundle())
       |> assign(:game_dir, game_dir)
       |> assign(:dir_error, nil)
       |> assign(:action_error, nil)
       |> assign(:connect_requested, false)
       |> refresh()}
    else
      {:ok, push_navigate(socket, to: ~p"/settings/simulators/simrail")}
    end
  end

  defp bundle do
    case SimRailSetup.bundle() do
      {:ok, bundle} -> bundle
      {:error, :not_bundled} -> nil
    end
  end

  defp refresh(socket) do
    status =
      case socket.assigns.game_dir do
        nil -> nil
        dir -> SimRailSetup.status(dir, socket.assigns.bundle)
      end

    assign(socket, :status, status)
  end

  # The first unfinished step is the one the page asks the player to do.
  defp current_step(nil, _bundle), do: :folder
  defp current_step(%{game: false}, _bundle), do: :folder
  defp current_step(%{melonloader: false}, _bundle), do: :melonloader
  defp current_step(%{loader: loader}, _bundle) when loader != :configured, do: :loader

  defp current_step(%{bridge: bridge, guard: guard}, _bundle)
       when bridge != :installed or guard != :installed,
       do: :install

  defp current_step(_status, _bundle), do: :connect

  @steps [:folder, :melonloader, :loader, :install, :connect]

  defp step_state(step, current) do
    step_index = Enum.find_index(@steps, &(&1 == step))
    current_index = Enum.find_index(@steps, &(&1 == current))

    cond do
      step_index < current_index -> :done
      step_index == current_index -> :current
      true -> :todo
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
  def handle_event("save_folder", %{"folder" => %{"path" => path}}, socket) do
    dir = path |> String.trim() |> String.trim("\"")

    if SimRailSetup.game_dir?(dir) do
      {:ok, _} = Settings.set_simrail_game_dir(dir)

      {:noreply,
       socket
       |> assign(:game_dir, dir)
       |> assign(:dir_error, nil)
       |> assign(:action_error, nil)
       |> refresh()}
    else
      {:noreply, assign(socket, :dir_error, "SimRail.exe is not in this folder.")}
    end
  end

  @impl true
  def handle_event("detect_folder", _params, socket) do
    case SimRailSetup.detect_game_dir() do
      nil ->
        {:noreply,
         assign(
           socket,
           :dir_error,
           "SimRail was not found in your Steam libraries. Enter its folder."
         )}

      dir ->
        {:ok, _} = Settings.set_simrail_game_dir(dir)
        {:noreply, socket |> assign(:game_dir, dir) |> assign(:dir_error, nil) |> refresh()}
    end
  end

  @impl true
  def handle_event("check_again", _params, socket) do
    {:noreply, socket |> assign(:action_error, nil) |> refresh()}
  end

  @impl true
  def handle_event("configure_loader", _params, socket) do
    case SimRailSetup.configure_loader(socket.assigns.game_dir) do
      :ok ->
        {:noreply, socket |> assign(:action_error, nil) |> refresh()}

      {:error, reason} ->
        {:noreply, socket |> assign(:action_error, loader_error(reason)) |> refresh()}
    end
  end

  @impl true
  def handle_event("install_mods", _params, %{assigns: %{bundle: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("install_mods", _params, socket) do
    case SimRailSetup.install(socket.assigns.game_dir, socket.assigns.bundle) do
      :ok ->
        {:noreply, socket |> assign(:action_error, nil) |> refresh()}

      {:error, reason} ->
        {:noreply, socket |> assign(:action_error, install_error(reason)) |> refresh()}
    end
  end

  @impl true
  def handle_event("connect", _params, socket) do
    {:ok, _} = Settings.set_simulator(:simrail)
    SimulatorConnection.reconfigure()
    {:noreply, assign(socket, :connect_requested, true)}
  end

  @impl true
  def handle_event("change_folder", _params, socket) do
    {:noreply, socket |> assign(:game_dir, nil) |> assign(:action_error, nil) |> refresh()}
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

  defp loader_error(:missing_file),
    do:
      "MelonLoader has not created its settings yet. Start SimRail once, quit it, then check again."

  defp loader_error(:missing_keys),
    do:
      "This MelonLoader version's Loader.cfg has no version_override or force_il2cpp_dumper_version setting. Add them by hand (see below), then check again."

  defp loader_error(reason), do: "Could not update Loader.cfg: #{inspect(reason)}"

  defp install_error({:copy_failed, file, reason}) when reason in [:eacces, :ebusy, :eperm],
    do:
      "Could not write #{file}. Quit SimRail (Windows locks the mod while the game runs), then try again."

  defp install_error({:copy_failed, file, reason}),
    do: "Could not write #{file}: #{inspect(reason)}"

  defp install_error(:not_game_dir), do: "The SimRail folder is no longer there. Choose it again."

  # The connection result, once the player asked to connect to SimRail.
  defp connection(%{backend: SimRailBackend, status: :connected, info: info}),
    do: {:connected, info || %{}}

  defp connection(%{backend: SimRailBackend, status: :connecting}), do: :connecting

  defp connection(%{backend: SimRailBackend, status: :error, last_error: :invalid_key}),
    do: :rejected

  defp connection(%{backend: SimRailBackend}), do: :waiting
  defp connection(_status), do: :waiting

  attr :number, :integer, required: true
  attr :title, :string, required: true
  attr :state, :atom, values: [:done, :current, :todo], required: true
  attr :id, :string, required: true
  slot :inner_block
  slot :done

  defp setup_step(assigns) do
    ~H"""
    <li id={@id} data-state={@state} class="flex gap-4">
      <div class={[
        "flex items-center justify-center w-7 h-7 rounded-full text-sm font-medium shrink-0",
        @state == :done && "bg-success text-success-content",
        @state == :current && "bg-primary text-primary-content",
        @state == :todo && "bg-base-300 text-muted"
      ]}>
        <.icon :if={@state == :done} name="hero-check-mini" class="w-4 h-4" />
        <span :if={@state != :done}>{@number}</span>
      </div>
      <div class="flex-1 min-w-0 pb-8">
        <h2 class={["font-medium", @state == :todo && "text-muted"]}>{@title}</h2>
        <div :if={@state == :done} class="text-sm text-muted mt-1">{render_slot(@done)}</div>
        <div :if={@state == :current} class="text-sm mt-2 space-y-3">{render_slot(@inner_block)}</div>
      </div>
    </li>
    """
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :current, current_step(assigns.status, assigns.bundle))

    ~H"""
    <.breadcrumb items={[
      %{label: "Settings", path: ~p"/settings"},
      %{label: "SimRail", path: ~p"/settings/simulators/simrail"},
      %{label: "Setup"}
    ]} />
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-2xl mx-auto">
        <header class="mb-8">
          <h1 class="text-2xl font-semibold flex items-center gap-2">
            Set up SimRail <span class="badge">Beta</span>
          </h1>
          <p class="text-sm text-muted mt-2">
            Trenino talks to SimRail through TreninoBridge, a mod that runs inside the game
            with MelonLoader. Run this setup on the computer where SimRail is installed.
          </p>
        </header>

        <div
          :if={@action_error}
          id="setup-error"
          role="alert"
          class="alert alert-soft alert-error mb-6 text-sm"
        >
          <.icon name="hero-exclamation-circle" class="w-5 h-5 shrink-0" />
          <span>{@action_error}</span>
        </div>

        <ol id="simrail-setup-steps">
          <.setup_step
            id="step-folder"
            number={1}
            title="Find SimRail"
            state={step_state(:folder, @current)}
          >
            <p>Choose the folder that has <span class="font-mono">SimRail.exe</span>.</p>
            <.form for={%{}} as={:folder} id="folder-form" phx-submit="save_folder" class="flex gap-2">
              <input
                id="folder_path"
                type="text"
                name="folder[path]"
                value={@game_dir}
                placeholder="C:\Program Files (x86)\Steam\steamapps\common\SimRail"
                class={["input input-bordered w-full font-mono text-sm", @dir_error && "input-error"]}
              />
              <button type="submit" class="btn btn-primary">Use folder</button>
            </.form>
            <div
              :if={@dir_error}
              id="folder-error"
              class="flex items-center gap-1.5 text-xs text-error"
            >
              <.icon name="hero-exclamation-circle" class="w-3.5 h-3.5 shrink-0" />
              {@dir_error}
            </div>
            <button
              id="detect-folder"
              type="button"
              class="btn btn-ghost btn-sm"
              phx-click="detect_folder"
            >
              Find it in my Steam libraries
            </button>
            <:done>
              <span class="font-mono break-all">{@game_dir}</span>
              <button type="button" class="link ml-2" phx-click="change_folder">Change</button>
            </:done>
          </.setup_step>

          <.setup_step
            id="step-melonloader"
            number={2}
            title="Install MelonLoader"
            state={step_state(:melonloader, @current)}
          >
            <p>
              TreninoBridge runs on MelonLoader 0.7.3 or newer. Download the official installer,
              choose <span class="font-mono">SimRail.exe</span> in the folder above and install.
            </p>
            <div class="flex gap-2">
              <a href={@melonloader_url} target="_blank" rel="noopener" class="btn btn-sm btn-primary">
                Get the MelonLoader installer
              </a>
              <button type="button" class="btn btn-sm btn-ghost" phx-click="check_again">Check again</button>
            </div>
            <:done>MelonLoader is installed.</:done>
          </.setup_step>

          <.setup_step
            id="step-loader"
            number={3}
            title="Configure MelonLoader for SimRail"
            state={step_state(:loader, @current)}
          >
            <%= if @status && @status.loader == :missing_file do %>
              <p>
                Start SimRail once so MelonLoader creates its settings file. The game may close
                or fail on this first start; that is expected. Then quit it and check again.
              </p>
              <button type="button" class="btn btn-sm btn-primary" phx-click="check_again">Check again</button>
            <% else %>
              <p>
                MelonLoader cannot detect SimRail's Unity version on its own. Trenino sets these
                in <span class="font-mono break-all">UserData\Loader.cfg</span>:
              </p>
              <ul class="font-mono text-xs bg-base-200 rounded px-3 py-2 space-y-1">
                <li :for={{key, value} <- SimRailSetup.loader_settings()}>{key} = "{value}"</li>
              </ul>
              <button
                id="configure-loader"
                type="button"
                class="btn btn-sm btn-primary"
                phx-click="configure_loader"
              >
                Apply settings
              </button>
            <% end %>
            <:done>Loader.cfg is set for SimRail.</:done>
          </.setup_step>

          <.setup_step
            id="step-install"
            number={4}
            title="Install TreninoBridge"
            state={step_state(:install, @current)}
          >
            <%= if @bundle do %>
              <p>
                Trenino copies TreninoBridge<span :if={@bundle.bridge_version}>{@bundle.bridge_version}</span>
                into <span class="font-mono">Mods</span>
                and TreninoInteropGuard into <span class="font-mono">Plugins</span>. Quit SimRail first.
              </p>
              <button
                id="install-mods"
                type="button"
                class="btn btn-sm btn-primary"
                phx-click="install_mods"
              >
                <%= if @status && (@status.bridge == :outdated or @status.guard == :outdated) do %>
                  Update TreninoBridge
                <% else %>
                  Install TreninoBridge
                <% end %>
              </button>
            <% else %>
              <p id="mods-not-bundled">
                This build of Trenino does not include TreninoBridge. Install a release build of
                Trenino, or build the mod yourself (see <span class="font-mono">integrations/simrail/README.md</span>), then check again.
              </p>
              <button type="button" class="btn btn-sm btn-ghost" phx-click="check_again">Check again</button>
            <% end %>
            <:done>TreninoBridge and TreninoInteropGuard are installed.</:done>
          </.setup_step>

          <.setup_step
            id="step-connect"
            number={5}
            title="Connect"
            state={step_state(:connect, @current)}
          >
            <%= case @connect_requested && connection(@nav_simulator_status) do %>
              <% {:connected, info} -> %>
                <p id="simrail-connected" class="flex items-center gap-2">
                  <.icon name="hero-check-circle" class="w-5 h-5 text-success" />
                  Connected to SimRail<span :if={info["bridge"]}> (TreninoBridge {info["bridge"]})</span>.
                </p>
                <p :if={info["interopGuard"] == false} id="interop-guard-warning" class="text-warning">
                  TreninoInteropGuard is not running, so SimRail may crash. Install TreninoBridge again
                  with SimRail closed.
                </p>
                <.link navigate={~p"/trains"} class="btn btn-sm btn-primary">Set up a train</.link>
              <% :rejected -> %>
                <p>
                  The bridge rejected the connection. Check the bridge URL and token on the <.link
                    navigate={~p"/settings/simulators/simrail"}
                    class="link"
                  >SimRail connection page</.link>.
                </p>
              <% :connecting -> %>
                <p>Connecting to SimRail…</p>
              <% _waiting -> %>
                <p>
                  Start SimRail. The first start with MelonLoader takes several minutes while it
                  prepares the game; later starts are quick. Once you are in the main menu, connect.
                </p>
                <button
                  id="connect-simrail"
                  type="button"
                  class="btn btn-sm btn-primary"
                  phx-click="connect"
                >
                  Connect to SimRail
                </button>
                <p :if={@connect_requested} class="text-muted">
                  Not connected yet. Trenino keeps trying while SimRail starts.
                </p>
            <% end %>
          </.setup_step>
        </ol>
      </div>
    </main>
    """
  end
end
