defmodule TreninoWeb.FirmwareLive do
  @moduledoc """
  LiveView for firmware management.

  Allows users to:
  - Check for firmware updates from GitHub
  - Download firmware for specific board types
  - Upload firmware to connected devices
  - View upload history
  """

  use TreninoWeb, :live_view

  alias Trenino.Firmware
  alias Trenino.Firmware.{DeviceRegistry, FirmwareFile}
  alias Trenino.Serial.Connection

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Firmware.subscribe_uploads()
    end

    releases = Firmware.list_releases(preload: [:firmware_files])
    upload_history = Firmware.list_upload_history(limit: 10, preload: [:firmware_file])
    current_upload = Firmware.current_upload()

    {:ok,
     socket
     |> assign(:releases, releases)
     |> assign(:upload_history, upload_history)
     |> assign(:current_upload, current_upload)
     |> assign(:checking_updates, false)
     |> assign(:selected_release, nil)
     |> assign(:selected_port, nil)
     |> assign(:selected_environment, nil)
     |> assign(:show_upload_modal, false)
     |> assign(:upload_progress, nil)
     |> assign(:upload_error, nil)
     |> assign(:show_older_releases, false)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    port = params["port"]

    # Auto-open upload modal if a port is specified and we have releases
    if port && !socket.assigns.show_upload_modal && !Enum.empty?(socket.assigns.releases) do
      latest_release = hd(socket.assigns.releases)

      {:noreply,
       socket
       |> assign(:selected_release, latest_release)
       |> assign(:selected_port, port)
       |> assign(:show_upload_modal, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:devices_updated, devices}, socket) do
    {:noreply, assign(socket, :nav_devices, devices)}
  end

  @impl true
  def handle_info({:simulator_status_changed, status}, socket) do
    {:noreply, assign(socket, :nav_simulator_status, status)}
  end

  # Upload events
  @impl true
  def handle_info({:upload_started, _upload_id, _port, _board_type}, socket) do
    {:noreply,
     socket
     |> assign(:upload_progress, %{percent: 0, message: "Starting upload..."})
     |> assign(:current_upload, Firmware.current_upload())}
  end

  @impl true
  def handle_info({:upload_progress, _upload_id, percent, message}, socket) do
    {:noreply, assign(socket, :upload_progress, %{percent: percent, message: message})}
  end

  @impl true
  def handle_info({:upload_completed, _upload_id, duration_ms}, socket) do
    {:noreply,
     socket
     |> assign(:current_upload, nil)
     |> assign(:upload_progress, nil)
     |> assign(:show_upload_modal, false)
     |> assign(
       :upload_history,
       Firmware.list_upload_history(limit: 10, preload: [:firmware_file])
     )
     |> put_flash(:info, "Firmware uploaded successfully in #{duration_ms}ms")}
  end

  @impl true
  def handle_info({:upload_failed, _upload_id, _reason, message}, socket) do
    {:noreply,
     socket
     |> assign(:current_upload, nil)
     |> assign(:upload_progress, nil)
     |> assign(:upload_error, message)
     |> assign(
       :upload_history,
       Firmware.list_upload_history(limit: 10, preload: [:firmware_file])
     )}
  end

  @impl true
  def handle_info(:firmware_update_dismissed, socket) do
    # Update notification was dismissed, no action needed
    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Nav events
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

  # Firmware events
  @impl true
  def handle_event("check_updates", _, socket) do
    socket = assign(socket, :checking_updates, true)

    case Firmware.check_for_updates() do
      {:ok, _new_releases} ->
        releases = Firmware.list_releases(preload: [:firmware_files])

        {:noreply,
         socket
         |> assign(:releases, releases)
         |> assign(:checking_updates, false)
         |> put_flash(:info, "Firmware releases updated")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:checking_updates, false)
         |> put_flash(:error, "Failed to check for updates: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("show_upload_modal", %{"release-id" => release_id_str}, socket) do
    release_id = String.to_integer(release_id_str)
    release = Enum.find(socket.assigns.releases, &(&1.id == release_id))

    {:noreply,
     socket
     |> assign(:selected_release, release)
     |> assign(:selected_port, nil)
     |> assign(:selected_environment, nil)
     |> assign(:show_upload_modal, true)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("close_upload_modal", _, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_modal, false)
     |> assign(:upload_error, nil)}
  end

  @impl true
  def handle_event("select_port", %{"port" => port}, socket) do
    if port != "" do
      {:noreply, assign(socket, :selected_port, port)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_environment", %{"environment" => environment}, socket) do
    if environment != "" do
      {:noreply, assign(socket, :selected_environment, environment)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("start_upload", _, socket) do
    port = socket.assigns.selected_port
    environment = socket.assigns.selected_environment
    release = socket.assigns.selected_release

    with {:ok, file} <- find_or_download_file(release, environment),
         {:ok, _upload_id} <- Firmware.start_upload(port, environment, file.id) do
      {:noreply, assign(socket, :upload_error, nil)}
    else
      {:error, :no_firmware_for_environment} ->
        {:noreply, assign(socket, :upload_error, "No firmware available for this device.")}

      {:error, reason} ->
        {:noreply, assign(socket, :upload_error, "Failed to start upload: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("cancel_upload", _, socket) do
    case socket.assigns.current_upload do
      %{upload_id: upload_id} ->
        Firmware.cancel_upload(upload_id)
        {:noreply, socket}

      nil ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_older_releases", _, socket) do
    {:noreply, assign(socket, :show_older_releases, !socket.assigns.show_older_releases)}
  end

  defp find_or_download_file(release, environment) do
    file =
      Enum.find(release.firmware_files, fn file ->
        # Prefer matching by environment if available, otherwise fall back to board_type
        if file.environment do
          file.environment == environment
        else
          # Legacy: convert board_type atom to environment string for comparison
          board_type_to_environment(file.board_type) == environment
        end
      end)

    case file do
      nil -> {:error, :no_firmware_for_environment}
      file -> ensure_file_downloaded(%{file | firmware_release: release})
    end
  end

  defp board_type_to_environment(board_type) when is_atom(board_type) do
    case board_type do
      :uno -> "uno"
      :nano -> "nanoatmega328"
      :leonardo -> "leonardo"
      :micro -> "micro"
      :mega2560 -> "megaatmega2560"
      :sparkfun_pro_micro -> "sparkfun_promicro16"
      _ -> to_string(board_type)
    end
  end

  defp board_type_to_environment(board_type) when is_binary(board_type), do: board_type

  defp ensure_file_downloaded(file) do
    require Logger

    if FirmwareFile.downloaded?(file) do
      Logger.debug("Firmware already downloaded")
      {:ok, file}
    else
      download_firmware_file(file)
    end
  end

  defp download_firmware_file(file) do
    require Logger
    Logger.info("Downloading firmware file #{file.id}...")

    case Firmware.download_firmware(file.id) do
      {:ok, downloaded_file} ->
        Logger.info("Firmware downloaded successfully")
        {:ok, downloaded_file}

      {:error, reason} = error ->
        Logger.error("Failed to download firmware: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def render(assigns) do
    # Get all available serial ports and merge with tracked device info
    all_ports = Connection.enumerate_ports()

    available_ports =
      Enum.map(all_ports, fn port ->
        device = Enum.find(assigns.nav_devices, &(&1.port == port))
        {port, device}
      end)

    # Split releases into latest and older
    {latest_release, older_releases} =
      case assigns.releases do
        [latest | older] -> {latest, older}
        [] -> {nil, []}
      end

    assigns =
      assigns
      |> assign(:available_ports, available_ports)
      |> assign(:latest_release, latest_release)
      |> assign(:older_releases, older_releases)

    ~H"""
    <main class="flex-1 p-4 sm:p-8">
      <div class="max-w-4xl mx-auto">
        <header class="mb-8 flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-semibold">Firmware</h1>
            <p class="text-sm text-base-content/70 mt-1">
              Download and upload firmware to your devices
            </p>
          </div>
          <button
            phx-click="check_updates"
            disabled={@checking_updates}
            class="btn btn-primary"
          >
            <.icon
              name="hero-arrow-path"
              class={if @checking_updates, do: "w-4 h-4 animate-spin", else: "w-4 h-4"}
            />
            {if @checking_updates, do: "Checking...", else: "Check for Updates"}
          </button>
        </header>

        <.empty_releases :if={Enum.empty?(@releases)} checking={@checking_updates} />

        <div :if={not Enum.empty?(@releases)} class="space-y-8">
          <section>
            <h2 class="text-lg font-medium mb-4">Available Releases</h2>
            <div class="space-y-4">
              <%!-- Latest release with emphasis --%>
              <.release_card :if={@latest_release} release={@latest_release} is_latest={true} />

              <%!-- Older releases in collapsible section --%>
              <div :if={not Enum.empty?(@older_releases)}>
                <button
                  phx-click="toggle_older_releases"
                  class="btn btn-ghost btn-sm w-full justify-start text-base-content/70 hover:text-base-content"
                >
                  <.icon
                    name="hero-chevron-down"
                    class={
                        "w-4 h-4 transition-transform duration-150 #{if @show_older_releases, do: "rotate-180", else: ""}"
                      }
                  />
                  {if @show_older_releases,
                    do: "Hide older releases",
                    else:
                      "Show #{length(@older_releases)} older release#{if length(@older_releases) > 1, do: "s", else: ""}"}
                </button>

                <div class={[
                  "overflow-hidden transition-all duration-150 ease-in-out",
                  if(@show_older_releases,
                    do: "max-h-[2000px] opacity-100 mt-4",
                    else: "max-h-0 opacity-0"
                  )
                ]}>
                  <div class="space-y-4">
                    <.release_card
                      :for={release <- @older_releases}
                      release={release}
                      is_latest={false}
                    />
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section :if={not Enum.empty?(@upload_history)}>
            <h2 class="text-lg font-medium mb-4">Upload History</h2>
            <.history_table history={@upload_history} />
          </section>
        </div>
      </div>
    </main>

    <.upload_modal
      :if={@show_upload_modal}
      release={@selected_release}
      available_ports={@available_ports}
      selected_port={@selected_port}
      environment={@selected_environment}
      progress={@upload_progress}
      error={@upload_error}
      current_upload={@current_upload}
    />
    """
  end

  defp empty_releases(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-20 text-center">
      <.icon name="hero-cpu-chip" class="w-16 h-16 text-base-content/20" />
      <h2 class="mt-6 text-xl font-semibold">No Firmware Releases</h2>
      <p class="mt-2 text-base-content/70 max-w-sm">
        {if @checking,
          do: "Checking for updates...",
          else: "Click 'Check for Updates' to fetch available firmware versions from GitHub."}
      </p>
    </div>
    """
  end

  attr :release, :map, required: true
  attr :is_latest, :boolean, default: false

  defp release_card(assigns) do
    # Get device names for display
    device_names =
      assigns.release.firmware_files
      |> Enum.map(fn file ->
        # Prefer environment over board_type for display names
        environment = file.environment || board_type_to_environment(file.board_type)

        case DeviceRegistry.get_device_config(environment) do
          {:ok, config} -> config.display_name
          {:error, :unknown_device} -> environment
        end
      end)
      |> Enum.sort()

    assigns = assign(assigns, :board_names, device_names)

    ~H"""
    <div class={[
      "border rounded-xl overflow-hidden",
      if(@is_latest,
        do: "border-2 border-primary/30 bg-base-200/80 shadow-lg shadow-primary/5 p-6",
        else: "border-base-300 bg-base-200/50 p-5"
      )
    ]}>
      <div class="flex items-start justify-between gap-4">
        <div>
          <div class="flex items-center gap-2">
            <h3 class="font-medium">v{@release.version}</h3>
            <span class="badge badge-ghost badge-sm">{@release.tag_name}</span>
            <span :if={@is_latest} class="badge badge-success badge-sm">Latest</span>
          </div>
          <p :if={@release.published_at} class="text-xs text-base-content/60 mt-1">
            Released {Calendar.strftime(@release.published_at, "%B %d, %Y")}
          </p>
          <p class="text-xs text-base-content/50 mt-2">
            Supported boards: {Enum.join(@board_names, ", ")}
          </p>
        </div>
        <div class="flex gap-2 items-center shrink-0">
          <button
            phx-click="show_upload_modal"
            phx-value-release-id={@release.id}
            class={["btn btn-sm", if(@is_latest, do: "btn-primary", else: "btn-outline")]}
          >
            <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload to Device
          </button>
          <a
            :if={@release.release_url}
            href={@release.release_url}
            target="_blank"
            class="btn btn-ghost btn-sm"
          >
            <.icon name="hero-arrow-top-right-on-square" class="w-3 h-3" />
          </a>
        </div>
      </div>
    </div>
    """
  end

  attr :history, :list, required: true

  defp history_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="table table-sm">
        <thead>
          <tr>
            <th>Port</th>
            <th>Board</th>
            <th>Status</th>
            <th>Duration</th>
            <th>Time</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={entry <- @history}>
            <td class="font-mono text-xs">{entry.port}</td>
            <td>{entry.board_type}</td>
            <td>
              <.status_badge status={entry.status} />
            </td>
            <td>
              {if entry.duration_ms, do: "#{entry.duration_ms}ms", else: "-"}
            </td>
            <td class="text-xs text-base-content/60">
              {if entry.started_at, do: Calendar.strftime(entry.started_at, "%H:%M:%S"), else: "-"}
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    {class, text} =
      case assigns.status do
        :completed -> {"badge-success", "Success"}
        :failed -> {"badge-error", "Failed"}
        :cancelled -> {"badge-warning", "Cancelled"}
        :started -> {"badge-info", "In Progress"}
      end

    assigns = assign(assigns, class: class, text: text)

    ~H"""
    <span class={"badge badge-sm #{@class}"}>{@text}</span>
    """
  end

  attr :release, :map, required: true
  attr :available_ports, :list, required: true
  attr :selected_port, :string, required: true
  attr :environment, :string, required: true
  attr :progress, :map, required: true
  attr :error, :string, required: true
  attr :current_upload, :any, required: true

  defp upload_modal(assigns) do
    device_options = DeviceRegistry.select_options()
    uploading = assigns.current_upload != nil
    no_ports = Enum.empty?(assigns.available_ports)

    assigns =
      assigns
      |> assign(:device_options, device_options)
      |> assign(:uploading, uploading)
      |> assign(:no_ports, no_ports)

    ~H"""
    <div class="modal modal-open">
      <div class="modal-box">
        <button
          :if={!@uploading}
          phx-click="close_upload_modal"
          class="btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
        >
          <.icon name="hero-x-mark" class="w-4 h-4" />
        </button>

        <h3 class="font-bold text-lg">Upload Firmware</h3>
        <p class="text-sm text-base-content/70 mt-1">
          Version: <span class="font-semibold">v{@release.version}</span>
        </p>

        <%!-- No devices available state --%>
        <div :if={@no_ports && !@uploading} class="mt-6 text-center py-8">
          <.icon name="hero-exclamation-circle" class="w-12 h-12 text-warning mx-auto" />
          <h4 class="font-medium mt-4">No Devices Available</h4>
          <p class="text-sm text-base-content/70 mt-2">
            Connect a device via USB and scan for ports.
          </p>
          <button phx-click="nav_scan_devices" class="btn btn-sm btn-primary mt-4">
            <.icon name="hero-arrow-path" class="w-4 h-4" /> Scan for Devices
          </button>
        </div>

        <div :if={!@no_ports && !@uploading} class="mt-4 space-y-4">
          <%!-- Port selection --%>
          <form phx-change="select_port" class="form-control">
            <label class="label">
              <span class="label-text font-medium">Serial Port</span>
            </label>
            <select name="port" class="select select-bordered w-full">
              <option value="" disabled selected={@selected_port == nil}>
                Select your device
              </option>
              <option
                :for={{port, device} <- @available_ports}
                value={port}
                selected={@selected_port == port}
              >
                {port}
                {if device && device.device_version, do: " - v#{device.device_version}", else: ""}
              </option>
            </select>
            <label class="label">
              <span class="label-text-alt text-base-content/60">
                Select the port your device is connected to
              </span>
            </label>
          </form>

          <%!-- Device selection --%>
          <form phx-change="select_environment" class="form-control">
            <label class="label">
              <span class="label-text font-medium">Device Type</span>
            </label>
            <select name="environment" class="select select-bordered w-full">
              <option value="" disabled selected={@environment == nil}>
                Select your device type
              </option>
              <option
                :for={{name, value} <- @device_options}
                value={value}
                selected={@environment == value}
              >
                {name}
              </option>
            </select>
            <label class="label">
              <span class="label-text-alt text-base-content/60">
                Make sure this matches your physical board
              </span>
            </label>
          </form>

          <div :if={@error} class="alert alert-error">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
            <span class="text-sm whitespace-pre-wrap">{@error}</span>
          </div>

          <div class="alert alert-warning">
            <.icon name="hero-exclamation-triangle" class="w-5 h-5" />
            <div class="text-sm">
              <p class="font-medium">Do not disconnect the device during upload</p>
              <p class="text-base-content/70">
                Interrupting the upload may corrupt the firmware.
              </p>
            </div>
          </div>
        </div>

        <div :if={@uploading} class="mt-4 space-y-4">
          <div class="text-center py-4">
            <.icon name="hero-cpu-chip" class="w-12 h-12 text-primary mx-auto animate-pulse" />
            <p class="mt-2 text-sm text-base-content/70">
              {(@progress && @progress.message) || "Uploading..."}
            </p>
          </div>

          <progress
            :if={@progress}
            class="progress progress-primary w-full"
            value={@progress.percent}
            max="100"
          >
          </progress>

          <p class="text-center text-xs text-base-content/60">
            Uploading to <span class="font-mono">{@selected_port}</span> - Do not disconnect
          </p>
        </div>

        <div class="modal-action">
          <button
            :if={!@uploading}
            phx-click="close_upload_modal"
            class="btn btn-ghost"
          >
            Cancel
          </button>
          <button
            :if={!@uploading && !@no_ports}
            phx-click="start_upload"
            disabled={@selected_port == nil or @environment == nil}
            class="btn btn-primary"
          >
            <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Start Upload
          </button>
          <button
            :if={@uploading}
            phx-click="cancel_upload"
            class="btn btn-error"
          >
            Cancel Upload
          </button>
        </div>
      </div>
      <div class="modal-backdrop bg-base-300/80" phx-click="close_upload_modal"></div>
    </div>
    """
  end
end
