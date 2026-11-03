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

  @doc """
  Persistent navigation header with status indicators.

  The header content is constrained to max-w-2xl to align with
  the main content area, while the background extends full-width.
  """
  attr :devices, :list, required: true
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
        <div class="max-w-2xl mx-auto py-3 flex flex-wrap items-center gap-y-3">
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
            </nav>
          </div>

          <div class="sm:ml-auto flex-none flex items-center gap-2">
            <.link
              navigate={~p"/settings"}
              class="flex items-center gap-1.5 px-3 py-2 rounded-lg bg-base-100 hover:bg-base-300 transition-colors duration-150"
              title="Settings"
              aria-label="Settings"
            >
              <.icon name="hero-cog-6-tooth" class="w-4 h-4" />
              <span class="text-sm font-medium hidden sm:inline">Settings</span>
            </.link>

            <div class="relative">
              <button
                phx-click="nav_toggle_dropdown"
                class="flex items-center gap-2 px-3 py-2 rounded-lg bg-base-100 hover:bg-base-300 transition-colors duration-150"
                aria-label={"Devices: #{elem(devices_summary(@devices), 1)}"}
                aria-expanded={@dropdown_open}
                aria-haspopup="menu"
              >
                <.status_indicator
                  kind={elem(devices_summary(@devices), 0)}
                  label={elem(devices_summary(@devices), 1)}
                  class="text-sm font-medium"
                  label_class="hidden sm:inline"
                />
                <span
                  :if={connected_count(@devices) > 0}
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

              <.device_dropdown
                :if={@dropdown_open}
                devices={@devices}
                scanning={@scanning}
                firmware_checking={@firmware_checking}
              />
            </div>
          </div>
        </div>
      </div>
      <.sim_status_banner
        :if={not String.starts_with?(@current_path, "/virtual-joystick")}
        status={@simulator_status.status}
      />
    </header>
    """
  end

  @doc """
  The Trenino lockup, for use inside a link or heading that carries the accessible name.

  The primary lockup shows on light themes and the dark lockup on dark themes (the `dark:`
  variant follows both a forced `data-theme` and the OS preference). The lockup is 40px
  high (145px wide), above the 140px minimum; below 360px viewport width it falls back to
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
          width="145"
          height="40"
          class="h-10 w-auto block dark:hidden"
        />
        <img
          src={~p"/images/trenino-lockup-dark.svg"}
          alt=""
          width="145"
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

  attr :status, :atom, required: true

  defp sim_status_banner(assigns) do
    ~H"""
    <div
      :if={@status in [:error, :disconnected, :needs_config]}
      id="simulator-status-banner"
      role="status"
      aria-live="polite"
    >
      <div class={["px-4 sm:px-8", sim_banner_bg(@status)]}>
        <div class="max-w-2xl mx-auto py-2 flex flex-wrap items-center justify-between gap-x-4 gap-y-1">
          <div class="flex items-center gap-2">
            <.icon
              name={sim_banner_icon(@status)}
              class={"w-4 h-4 flex-shrink-0 #{sim_banner_icon_class(@status)}"}
            />
            <span class="text-sm">{sim_banner_message(@status)}</span>
          </div>

          <div class="flex items-center">
            <button
              :if={@status in [:error, :disconnected]}
              phx-click="nav_retry_simulator"
              class={["btn btn-sm btn-ghost", sim_banner_btn_class(@status)]}
            >
              <.icon name="hero-arrow-path" class="w-4 h-4" /> Retry
            </button>

            <.link
              :if={@status == :needs_config}
              navigate={~p"/settings"}
              class={["btn btn-sm btn-ghost", sim_banner_btn_class(@status)]}
            >
              Open Settings
            </.link>
          </div>
        </div>
      </div>
    </div>
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

  # Device dropdown component
  attr :devices, :list, required: true
  attr :scanning, :boolean, default: false
  attr :firmware_checking, :boolean, default: false

  defp device_dropdown(assigns) do
    ~H"""
    <div
      class="absolute top-full right-0 mt-1 w-80 max-w-[calc(100vw-2rem)] bg-base-200 border border-base-300 rounded-xl shadow-xl z-50"
      phx-click-away="nav_close_dropdown"
    >
      <div class="p-4 border-b border-base-300 space-y-2">
        <button
          phx-click="nav_scan_devices"
          disabled={@scanning}
          class="btn btn-primary btn-sm w-full"
        >
          <.icon
            :if={@scanning}
            name="hero-arrow-path"
            class="w-4 h-4 motion-safe:animate-spin"
          />
          <.icon
            :if={!@scanning}
            name="hero-magnifying-glass"
            class="w-4 h-4"
          />
          {if @scanning, do: "Scanning...", else: "Scan for Devices"}
        </button>

        <button
          phx-click="check_firmware_updates"
          disabled={@firmware_checking}
          class="btn btn-ghost btn-sm w-full"
        >
          <.icon
            name="hero-arrow-path"
            class={if @firmware_checking, do: "w-4 h-4 motion-safe:animate-spin", else: "w-4 h-4"}
          />
          {if @firmware_checking, do: "Checking...", else: "Check for Firmware Updates"}
        </button>
      </div>

      <div class="max-h-80 overflow-y-auto">
        <.empty_device_list :if={Enum.empty?(@devices)} />
        <.device_list_item :for={device <- @devices} device={device} />
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

  defp device_list_item(assigns) do
    ~H"""
    <div class="px-4 py-3 border-b border-base-300 last:border-b-0 hover:bg-base-300/40">
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2 min-w-0">
          <span class="text-sm font-medium font-mono truncate">{@device.port}</span>
        </div>
        <button
          :if={@device.status == :connected}
          phx-click="nav_disconnect_device"
          phx-value-port={@device.port}
          class="btn btn-ghost btn-xs text-error hover:bg-error/10"
          aria-label={"Disconnect from #{@device.port}"}
        >
          <.icon name="hero-x-mark" class="w-4 h-4" />
        </button>
      </div>
      <div class="mt-1 flex items-center gap-2 text-xs text-muted">
        <.status_indicator
          kind={elem(device_status(@device.status), 0)}
          label={elem(device_status(@device.status), 1)}
          class="text-base-content"
        />
        <span :if={@device.device_version} aria-hidden="true">·</span>
        <span :if={@device.device_version} class="font-mono">v{@device.device_version}</span>
      </div>
      <div
        :if={@device.status == :failed and @device.error_reason}
        class="mt-1 text-xs text-error flex items-start gap-1"
      >
        <.icon name="hero-exclamation-circle-mini" class="w-3.5 h-3.5 flex-shrink-0 mt-0.5" />
        <span>{@device.error_reason}</span>
      </div>
      <div :if={@device.status == :failed and flashable_error?(@device.error_type)} class="mt-2">
        <.link
          navigate={~p"/firmware?port=#{@device.port}"}
          class="btn btn-xs btn-outline btn-primary"
        >
          <.icon name="hero-arrow-up-tray" class="w-3 h-3" /> Install Firmware
        </.link>
      </div>
    </div>
    """
  end

  # Helper functions

  defp flashable_error?(error_type) do
    error_type in [:no_valid_response, :timeout]
  end

  # Header summary of all tracked devices, in the shared status vocabulary.
  # A failure anywhere rolls up to "Needs attention"; the row itself says "Failed".
  defp devices_summary(devices) do
    connected = connected_count(devices)

    cond do
      Enum.any?(devices, &(&1.status in [:connecting, :discovering])) -> {:busy, "Connecting"}
      Enum.any?(devices, &(&1.status == :failed)) -> {:warn, "Needs attention"}
      connected > 0 -> {:ok, "#{connected} connected"}
      true -> {:muted, "No devices"}
    end
  end

  defp connected_count(devices) do
    Enum.count(devices, &(&1.status == :connected))
  end

  # The error banner stays a solid fill so a failed connection stands out; the other
  # notices use a neutral strip with a status-colored icon.
  defp sim_banner_bg(:error), do: "bg-error text-error-content"
  defp sim_banner_bg(_status), do: "bg-base-200 border-t border-base-300 text-base-content"

  defp sim_banner_icon_class(:error), do: ""
  defp sim_banner_icon_class(_status), do: "text-warning"

  defp sim_banner_icon(status) do
    case status do
      :error -> "hero-exclamation-circle"
      :disconnected -> "hero-signal-slash"
      :needs_config -> "hero-wrench-screwdriver"
      _ -> "hero-check-circle"
    end
  end

  defp sim_banner_message(status) do
    case status do
      :error -> "Simulator connection failed"
      :disconnected -> "Simulator is offline"
      :needs_config -> "Simulator not configured"
      _ -> ""
    end
  end

  defp sim_banner_btn_class(:error), do: "text-error-content hover:bg-error-content/10"
  defp sim_banner_btn_class(_status), do: ""
end
