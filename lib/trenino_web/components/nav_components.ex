defmodule TreninoWeb.NavComponents do
  @moduledoc """
  Shared navigation components for persistent header and breadcrumbs.
  """

  use Phoenix.Component
  use TreninoWeb, :verified_routes

  import TreninoWeb.CoreComponents

  @doc """
  App version update notification banner.

  Displays when a new app version is available on GitHub.
  """
  attr :update, :map, default: nil

  def app_version_update_banner(assigns) do
    ~H"""
    <div
      :if={@update && @update.available}
      class="bg-base-200 border-b border-base-300 text-base-content px-4 sm:px-8"
      role="alert"
    >
      <div class="max-w-2xl mx-auto py-2 flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
        <div class="flex min-w-0 items-center gap-3">
          <.icon name="hero-arrow-up-circle" class="w-5 h-5 flex-shrink-0 text-info" />
          <div class="min-w-0 break-words text-sm">
            <span class="font-medium">New version available:</span>
            <span class="ml-1 font-mono">v{@update.version}</span>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <a
            href={Trenino.AppVersion.releases_url()}
            target="_blank"
            rel="noopener noreferrer"
            class="btn btn-sm btn-ghost"
          >
            <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" /> View Release
          </a>

          <button
            phx-click="dismiss_app_version_update"
            class="btn btn-sm btn-ghost btn-circle"
            aria-label="Dismiss"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Firmware update notification banner.

  Displays when a new firmware version is available.
  """
  attr :update, :map, default: nil
  attr :checking, :boolean, default: false

  def firmware_update_banner(assigns) do
    ~H"""
    <div
      :if={@update && @update.available}
      class="bg-base-200 border-b border-base-300 text-base-content px-4 sm:px-8"
      role="alert"
    >
      <div class="max-w-2xl mx-auto py-2 flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
        <div class="flex min-w-0 items-center gap-3">
          <.icon name="hero-arrow-down-tray" class="w-5 h-5 flex-shrink-0 text-info" />
          <div class="min-w-0 break-words text-sm">
            <span class="font-medium">Firmware update available:</span>
            <span class="ml-1 font-mono">v{@update.version}</span>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <.link
            navigate="/firmware"
            class="btn btn-sm btn-ghost"
          >
            View Update
          </.link>

          <button
            phx-click="dismiss_firmware_update"
            class="btn btn-sm btn-ghost btn-circle"
            aria-label="Dismiss"
          >
            <.icon name="hero-x-mark" class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  @discord_url "https://discord.gg/d75tmjwUav"

  @doc """
  Invite URL of the Trenino Discord community.
  """
  @spec discord_url() :: String.t()
  def discord_url, do: @discord_url

  @doc """
  Quiet one-line footer pointing to the Discord community.

  Sits at the bottom of the page flow (not sticky, never over content), stays muted and
  is always present, so there is nothing to dismiss. The link opens in the system browser
  like the other external links.
  """
  def community_footer(assigns) do
    assigns = assign(assigns, :url, @discord_url)

    ~H"""
    <footer id="community-footer" class="mt-auto px-4 sm:px-8 pb-6 pt-2">
      <p class="max-w-2xl mx-auto text-xs text-muted">
        Questions or ideas?
        <a
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="underline underline-offset-2 hover:text-base-content transition-colors"
        >
          Join the Trenino Discord<.icon
            name="hero-arrow-top-right-on-square-mini"
            class="w-3 h-3 ml-1 align-text-bottom"
          />
          <span class="sr-only">(opens in your browser)</span>
        </a>
      </p>
    </footer>
    """
  end

  @doc """
  Persistent navigation header with status indicators.

  The header content is constrained to max-w-4xl, wider than the max-w-2xl page content,
  so the lockup, the tabs and the connections button fit on one row. The connections
  button rolls up device and simulator state; its dropdown holds the details.
  """
  attr :devices, :list, required: true
  attr :device_names, :map, default: %{}, doc: "config_id => configuration name"
  attr :simulator_status, :map, required: true
  attr :firmware_update, :map, default: nil
  attr :app_version_update, :map, default: nil
  attr :firmware_checking, :boolean, default: false
  attr :dropdown_open, :boolean, default: false
  attr :scanning, :boolean, default: false
  attr :current_path, :string, default: "/"

  def nav_header(assigns) do
    ~H"""
    <.app_version_update_banner update={@app_version_update} />
    <.firmware_update_banner update={@firmware_update} checking={@firmware_checking} />
    <header class="bg-base-200 border-b border-base-300 sticky top-0 z-50">
      <div class="px-4 sm:px-8">
        <div class="max-w-4xl mx-auto py-3 flex flex-wrap items-center gap-y-3">
          <div class="contents">
            <.link
              navigate={~p"/"}
              aria-label="Trenino, home"
              class="flex-1 sm:flex-none sm:mr-6 py-1 rounded-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
            >
              <.brand_lockup />
            </.link>
            <nav
              aria-label="Primary navigation"
              class="order-last w-full sm:order-none sm:w-auto flex items-center gap-1"
            >
              <.nav_tab path={~p"/"} label="Devices" current_path={@current_path} />
              <.nav_tab path={~p"/trains"} label="Trains" current_path={@current_path} />
              <.nav_tab path={~p"/virtual-joystick"} label="Joystick" current_path={@current_path} />
              <.nav_tab path={~p"/settings"} label="Settings" current_path={@current_path} />
            </nav>
          </div>

          <div class="sm:ml-auto flex-none flex items-center gap-2">
            <div class="relative">
              <button
                phx-click="nav_toggle_dropdown"
                class="flex items-center gap-2 px-3 py-2 rounded-lg bg-base-100 hover:bg-base-300 transition-colors duration-150"
                aria-label={"Connections: #{elem(connections_summary(@devices, @simulator_status), 1)}"}
                aria-expanded={@dropdown_open}
                aria-haspopup="menu"
              >
                <.status_indicator
                  kind={elem(connections_summary(@devices, @simulator_status), 0)}
                  label={elem(connections_summary(@devices, @simulator_status), 1)}
                  class="text-sm font-medium"
                  label_class="hidden sm:inline"
                />
                <span
                  :if={elem(connections_summary(@devices, @simulator_status), 0) == :ok}
                  class="text-sm font-medium tabular-nums sm:hidden"
                  aria-hidden="true"
                >
                  {connected_count(@devices)}
                </span>
                <.icon
                  name="hero-chevron-down-solid"
                  class={"w-4 h-4 transition-transform duration-200 #{if @dropdown_open, do: "rotate-180", else: ""}"}
                />
              </button>

              <.connections_dropdown
                :if={@dropdown_open}
                devices={@devices}
                device_names={@device_names}
                simulator_status={@simulator_status}
                scanning={@scanning}
                firmware_checking={@firmware_checking}
              />
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  The Trenino lockup, for use inside a link or heading that carries the accessible name.

  The primary lockup shows on light themes and the dark lockup on dark themes (the `dark:`
  variant follows both a forced `data-theme` and the OS preference). The lockup is 40px
  high (150px wide), above the 140px minimum; below 360px viewport width it falls back to
  the symbol at 32px so it is never shrunk under the minimum. Never recolor these files.
  """
  attr :class, :string, default: nil

  def brand_lockup(assigns) do
    ~H"""
    <span class={["inline-flex items-center", @class]}>
      <span class="max-[359px]:hidden">
        <img
          src={~p"/images/trenino-lockup-primary.svg"}
          alt=""
          width="150"
          height="40"
          class="h-10 w-auto block dark:hidden"
        />
        <img
          src={~p"/images/trenino-lockup-dark.svg"}
          alt=""
          width="150"
          height="40"
          class="h-10 w-auto hidden dark:block"
        />
      </span>
      <img
        src={~p"/images/trenino-symbol-red.svg"}
        alt=""
        width="32"
        height="32"
        class="h-8 w-auto hidden max-[359px]:block"
      />
    </span>
    """
  end

  attr :path, :string, required: true
  attr :label, :string, required: true
  attr :current_path, :string, required: true

  defp nav_tab(assigns) do
    is_active =
      case assigns.path do
        "/" ->
          assigns.current_path == "/" or
            String.starts_with?(assigns.current_path, "/configurations")

        path ->
          String.starts_with?(assigns.current_path, path)
      end

    assigns = assign(assigns, :is_active, is_active)

    ~H"""
    <.link
      navigate={@path}
      aria-current={@is_active && "page"}
      class={[
        "px-3 py-2.5 sm:py-1.5 rounded-lg text-sm font-medium transition-colors",
        if(@is_active,
          do: "bg-primary text-primary-content",
          else: "text-muted hover:text-base-content hover:bg-base-300"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  @doc """
  Inline notice for pages that need Train Sim World, shown while it is not connected
  (hidden while a connection attempt is still running).

  The nav connections dropdown carries the simulator status everywhere; only pages whose
  work depends on the simulator add this notice, with the same next step and action.
  """
  attr :simulator_status, :map, required: true
  attr :message, :string, required: true, doc: "what the page cannot do without the simulator"
  attr :class, :string, default: nil

  def simulator_notice(assigns) do
    assigns = assign(assigns, :sim, simulator_state(assigns.simulator_status))

    ~H"""
    <div
      :if={@simulator_status.status not in [:connected, :connecting]}
      id="simulator-notice"
      role="status"
      class={["alert alert-soft alert-warning", @class]}
    >
      <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
      <span>{@message} {@sim.hint}</span>
      <.simulator_action action={@sim.action} />
    </div>
    """
  end

  attr :action, :atom, required: true

  defp simulator_action(assigns) do
    ~H"""
    <button
      :if={@action == :retry}
      phx-click="nav_retry_simulator"
      class="btn btn-ghost btn-xs"
    >
      <.icon name="hero-arrow-path" class="w-4 h-4" /> Retry
    </button>
    <.link :if={@action == :settings} navigate={~p"/settings"} class="btn btn-ghost btn-xs">
      Open Settings
    </.link>
    """
  end

  @doc """
  Breadcrumb navigation component.

  Items should be a list of maps with :label and optional :path keys.
  The last item typically has no path and represents the current page.

  ## Examples

      <.breadcrumb items={[
        %{label: "Home", path: ~p"/"},
        %{label: "Configuration"}
      ]} />
  """
  attr :items, :list, required: true, doc: "List of %{label: string, path: string | nil}"

  def breadcrumb(assigns) do
    ~H"""
    <nav :if={length(@items) > 1} class="bg-base-200/50 border-b border-base-300 px-4 sm:px-8">
      <div class="max-w-2xl mx-auto py-2">
        <ol class="flex items-center gap-2 text-sm">
          <li :for={{item, index} <- Enum.with_index(@items)} class="flex items-center gap-2">
            <.icon
              :if={index > 0}
              name="hero-chevron-right-mini"
              class="w-4 h-4 text-muted"
            />

            <.link
              :if={item[:path]}
              navigate={item.path}
              class="text-muted hover:text-base-content transition-colors"
            >
              {item.label}
            </.link>

            <span :if={!item[:path]} class="text-base-content font-medium">
              {item.label}
            </span>
          </li>
        </ol>
      </div>
    </nav>
    """
  end

  # Connections dropdown: the simulator first (it blocks more than a missing device),
  # then the devices with their scan and firmware actions.
  attr :devices, :list, required: true
  attr :device_names, :map, required: true
  attr :simulator_status, :map, required: true
  attr :scanning, :boolean, default: false
  attr :firmware_checking, :boolean, default: false

  defp connections_dropdown(assigns) do
    assigns = assign(assigns, :sim, simulator_state(assigns.simulator_status))

    ~H"""
    <div
      class="absolute top-full right-0 mt-1 w-80 max-w-[calc(100vw-2rem)] bg-base-200 border border-base-300 rounded-xl shadow-xl z-50"
      phx-click-away="nav_close_dropdown"
    >
      <section id="simulator-status-row" class="px-4 py-3 border-b border-base-300">
        <div class="flex items-center justify-between gap-2">
          <span class="text-sm font-medium">Train Sim World</span>
          <.simulator_action action={@sim.action} />
        </div>
        <.status_indicator kind={@sim.kind} label={@sim.label} class="mt-1 text-xs" />
        <p :if={@sim.hint} class="mt-1 text-xs text-muted">{@sim.hint}</p>
      </section>

      <div class="px-4 pt-3 pb-1 flex items-center justify-between gap-2">
        <p class="text-xs font-medium text-muted">Devices</p>
        <div class="flex items-center gap-1">
          <button
            phx-click="check_firmware_updates"
            disabled={@firmware_checking}
            class="btn btn-ghost btn-xs"
          >
            <.icon
              name="hero-arrow-path"
              class={if @firmware_checking, do: "w-4 h-4 motion-safe:animate-spin", else: "w-4 h-4"}
            />
            {if @firmware_checking, do: "Checking...", else: "Check firmware"}
          </button>
          <button phx-click="nav_scan_devices" disabled={@scanning} class="btn btn-ghost btn-xs">
            <.icon
              name={if @scanning, do: "hero-arrow-path", else: "hero-magnifying-glass"}
              class={if @scanning, do: "w-4 h-4 motion-safe:animate-spin", else: "w-4 h-4"}
            />
            {if @scanning, do: "Scanning...", else: "Scan"}
          </button>
        </div>
      </div>

      <div class="max-h-80 overflow-y-auto">
        <.empty_device_list :if={Enum.empty?(@devices)} />
        <.device_list_item
          :for={device <- @devices}
          device={device}
          name={Map.get(@device_names, device.device_config_id)}
        />
      </div>
    </div>
    """
  end

  defp empty_device_list(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <.icon name="hero-signal-slash" class="w-8 h-8 mx-auto text-muted" />
      <p class="mt-2 text-sm">No devices found</p>
      <p class="text-xs text-muted">Connect a controller over USB, then scan for devices.</p>
    </div>
    """
  end

  attr :device, :map, required: true
  attr :name, :string, default: nil, doc: "name of the configuration the device runs, if known"

  # Named after its configuration when known, with the port as secondary detail.
  defp device_list_item(assigns) do
    ~H"""
    <div class="px-4 py-3 border-t border-base-300 hover:bg-base-300/40">
      <div class="flex items-center justify-between gap-2">
        <span :if={@name} class="text-sm font-medium truncate">{@name}</span>
        <span :if={!@name} class="text-sm font-medium font-mono truncate">{@device.port}</span>
        <button
          :if={@device.status == :connected}
          phx-click="nav_disconnect_device"
          phx-value-port={@device.port}
          class="btn btn-ghost btn-xs"
          aria-label={"Disconnect from #{@name || @device.port}"}
          title="Disconnect"
        >
          <.icon name="hero-x-mark" class="w-4 h-4" />
        </button>
        <.link
          :if={@device.status == :failed and flashable_error?(@device.error_type)}
          navigate={~p"/firmware?port=#{@device.port}"}
          class="btn btn-ghost btn-xs text-primary"
        >
          Install firmware
        </.link>
      </div>
      <div class="mt-1 flex items-center gap-2 text-xs text-muted min-w-0">
        <.status_indicator
          kind={elem(device_status(@device.status), 0)}
          label={elem(device_status(@device.status), 1)}
          class="text-base-content"
        />
        <span :if={@name} aria-hidden="true">·</span>
        <span :if={@name} class="font-mono truncate">{@device.port}</span>
        <span :if={@device.device_version} aria-hidden="true">·</span>
        <span :if={@device.device_version} class="font-mono">v{@device.device_version}</span>
      </div>
      <p :if={@device.status == :failed and @device.error_reason} class="mt-1 text-xs text-muted">
        {@device.error_reason}
      </p>
    </div>
    """
  end

  # Helper functions

  defp flashable_error?(error_type) do
    error_type in [:no_valid_response, :timeout]
  end

  # Header summary of devices and the simulator, in the shared status vocabulary.
  # A problem anywhere rolls up to "Needs attention"; the row itself says "Failed".
  defp connections_summary(devices, simulator_status) do
    connected = connected_count(devices)
    sim = simulator_status.status

    cond do
      sim == :connecting or Enum.any?(devices, &(&1.status in [:connecting, :discovering])) ->
        {:busy, "Connecting"}

      sim in [:error, :disconnected, :needs_config] or
          Enum.any?(devices, &(&1.status == :failed)) ->
        {:warn, "Needs attention"}

      connected > 0 ->
        {:ok, "#{connected} connected"}

      true ->
        {:muted, "No devices"}
    end
  end

  defp connected_count(devices) do
    Enum.count(devices, &(&1.status == :connected))
  end

  # Status, next step and recovery action for the simulator row and notice.
  @spec simulator_state(map()) :: %{
          kind: atom(),
          label: String.t(),
          hint: String.t() | nil,
          action: :retry | :settings | nil
        }
  defp simulator_state(simulator_status) do
    case {simulator_status.status, Map.get(simulator_status, :last_error)} do
      {:connected, _} ->
        %{kind: :ok, label: "Connected", hint: nil, action: nil}

      {:connecting, _} ->
        %{kind: :busy, label: "Connecting", hint: nil, action: nil}

      {:needs_config, _} ->
        %{
          kind: :warn,
          label: "Needs attention",
          hint: "Add your Train Sim World API key in Settings.",
          action: :settings
        }

      {:error, :invalid_key} ->
        %{
          kind: :error,
          label: "Failed",
          hint: "The API key was rejected. Check it in Settings.",
          action: :settings
        }

      {:error, _} ->
        %{
          kind: :error,
          label: "Failed",
          hint: "Train Sim World did not respond. Start the game, then retry.",
          action: :retry
        }

      {_disconnected, _} ->
        %{
          kind: :warn,
          label: "Needs attention",
          hint: "Start Train Sim World, then retry.",
          action: :retry
        }
    end
  end
end
