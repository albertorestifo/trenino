defmodule TswIoWeb.NavHook do
  @moduledoc """
  LiveView hook for persistent navigation with status indicators.

  Subscribes to device and simulator status updates on mount.
  This is used with `on_mount` in the router to provide shared
  navigation state across all LiveViews.
  """

  import Phoenix.LiveView
  import Phoenix.Component

  alias TswIo.Serial.Connection
  alias TswIo.Simulator

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      Connection.subscribe()
      Simulator.subscribe()
    end

    devices = Connection.list_devices()
    simulator_status = Simulator.get_status()

    {:cont,
     socket
     |> assign(:nav_devices, devices)
     |> assign(:nav_simulator_status, simulator_status)
     |> assign(:nav_dropdown_open, false)
     |> assign(:nav_scanning, false)}
  end
end
