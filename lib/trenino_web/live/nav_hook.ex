defmodule TreninoWeb.NavHook do
  @moduledoc """
  LiveView hook for persistent navigation with status indicators.

  Subscribes to device, simulator, firmware update, and app version status on mount.
  This is used with `on_mount` in the router to provide shared
  navigation state across all LiveViews.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias Trenino.AppVersion
  alias Trenino.Beta
  alias Trenino.Firmware
  alias Trenino.Hardware
  alias Trenino.Serial.Connection
  alias Trenino.Simulator
  alias Trenino.Simulator.ConnectionState

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Connection.subscribe()
      Simulator.subscribe()
      Firmware.subscribe_update_notifications()
      AppVersion.subscribe_update_notifications()

      # Fetch initial state asynchronously to avoid blocking mount
      # when the Connection GenServer is busy with UART operations.
      # PubSub subscription ensures we receive updates going forward.
      send(self(), :nav_fetch_initial_state)
    end

    {:cont,
     socket
     |> assign(:nav_devices, [])
     |> assign(:nav_device_names, %{})
     |> assign(:nav_simulator_status, ConnectionState.new())
     |> assign(:nav_firmware_update, nil)
     |> assign(:nav_app_version_update, nil)
     |> assign(:nav_firmware_checking, false)
     |> assign(:nav_dropdown_open, false)
     |> assign(:nav_scanning, false)
     |> assign(:nav_current_path, "/")
     |> assign(:beta_gauges, Beta.enabled?(:gauges))
     |> assign(:beta_selectors, Beta.enabled?(:selectors))
     |> attach_hook(:nav_path_tracker, :handle_params, &handle_params/3)
     |> attach_hook(:nav_firmware_events, :handle_event, &handle_event/3)
     |> attach_hook(:nav_firmware_info, :handle_info, &handle_info/2)}
  end

  defp handle_params(_params, uri, socket) do
    path = URI.parse(uri).path
    {:cont, assign(socket, :nav_current_path, path)}
  end

  defp handle_event("dismiss_firmware_update", _params, socket) do
    Firmware.dismiss_update_notification()
    {:halt, socket}
  end

  defp handle_event("check_firmware_updates", _params, socket) do
    Firmware.trigger_update_check()
    {:halt, socket}
  end

  defp handle_event("dismiss_app_version_update", _params, socket) do
    AppVersion.dismiss_update_notification()
    {:halt, socket}
  end

  defp handle_event(_event, _params, socket) do
    {:cont, socket}
  end

  # Async initial state fetch — avoids blocking mount when Connection GenServer is busy
  defp handle_info(:nav_fetch_initial_state, socket) do
    devices = Connection.list_devices()
    simulator_status = Simulator.get_status()
    firmware_update_status = Firmware.check_update_status()
    app_version_update_status = AppVersion.check_update_status()

    {:cont,
     socket
     |> assign_devices(devices)
     |> assign(:nav_simulator_status, simulator_status)
     |> assign(:nav_firmware_update, format_update_status(firmware_update_status))
     |> assign(:nav_app_version_update, format_update_status(app_version_update_status))}
  end

  # Device update events
  defp handle_info({:devices_updated, devices}, socket) do
    {:cont, assign_devices(socket, devices)}
  end

  defp handle_info(:scan_complete, socket) do
    {:cont, assign(socket, :nav_scanning, false)}
  end

  # Firmware update events
  defp handle_info({:firmware_update_available, version}, socket) do
    {:cont, assign(socket, :nav_firmware_update, %{available: true, version: version})}
  end

  defp handle_info(:firmware_update_dismissed, socket) do
    {:cont, assign(socket, :nav_firmware_update, nil)}
  end

  defp handle_info({:firmware_update_checking, checking}, socket) do
    {:cont, assign(socket, :nav_firmware_checking, checking)}
  end

  # App version update events
  defp handle_info({:app_version_update_available, version}, socket) do
    {:cont, assign(socket, :nav_app_version_update, %{available: true, version: version})}
  end

  defp handle_info(:app_version_update_dismissed, socket) do
    {:cont, assign(socket, :nav_app_version_update, nil)}
  end

  defp handle_info({:app_version_update_checking, _checking}, socket) do
    # We don't show a checking indicator for app version updates
    {:cont, socket}
  end

  defp handle_info(_msg, socket) do
    {:cont, socket}
  end

  # Devices are named after the configuration they run, when it is known.
  defp assign_devices(socket, devices) do
    names =
      devices
      |> Enum.map(& &1.device_config_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Hardware.configuration_names()

    socket
    |> assign(:nav_devices, devices)
    |> assign(:nav_device_names, names)
  end

  defp format_update_status({:update_available, version}) do
    %{available: true, version: version}
  end

  defp format_update_status(:no_update), do: nil
end
