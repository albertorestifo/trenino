defmodule Trenino.VirtualJoystick.Configurator do
  @moduledoc false

  alias Trenino.VirtualJoystick.{Configurator.SystemAdapter, Platform}

  @create_arguments [
    "1",
    "-a",
    "x",
    "y",
    "z",
    "rx",
    "ry",
    "rz",
    "sl0",
    "sl1",
    "-b",
    "32",
    "-p",
    "0"
  ]
  @delete_arguments ["-d", "1"]
  @poll_interval 100
  @default_timeout 10_000

  @statuses [:driver_missing, :device_missing, :compatible, :incompatible, :busy]

  def status do
    if windows?(), do: checked_status(), else: :driver_missing
  end

  def create do
    with :ok <- supported() do
      case checked_status() do
        :compatible -> :ok
        :device_missing -> configure(@create_arguments, :compatible)
        status -> {:error, status}
      end
    end
  end

  def delete do
    with :ok <- supported() do
      case checked_status() do
        :device_missing -> :ok
        :compatible -> configure(@delete_arguments, :device_missing)
        status -> {:error, status}
      end
    end
  end

  def wait_for(expected, timeout_ms)
      when expected in @statuses and is_integer(timeout_ms) and timeout_ms >= 0 do
    poll(expected, timeout_ms)
  end

  defp poll(expected, remaining) do
    if checked_status() == expected do
      :ok
    else
      if remaining <= 0 do
        {:error, :timeout}
      else
        interval = min(@poll_interval, remaining)
        :ok = adapter().sleep(interval)
        poll(expected, remaining - interval)
      end
    end
  end

  defp configure(arguments, expected) do
    with {:ok, path} <- adapter().configurator_path(),
         :ok <- elevate(path, arguments),
         :ok <- wait_for(expected, @default_timeout) do
      :ok
    end
  end

  defp elevate(path, arguments) do
    case adapter().elevate(path, arguments) do
      {:ok, 0} -> :ok
      {:ok, exit_code} -> {:error, {:process_exit, exit_code}}
      {:error, 1223} -> {:error, :uac_cancelled}
      {:error, {:process_exit, 1223}} -> {:error, :uac_cancelled}
      {:error, reason} -> {:error, reason}
    end
  end

  defp checked_status do
    case adapter().status() do
      status when status in @statuses -> status
      _ -> :driver_missing
    end
  end

  defp supported, do: if(windows?(), do: :ok, else: {:error, :unsupported})
  defp windows?, do: platform().windows?()

  defp platform,
    do: Application.get_env(:trenino, :virtual_joystick_platform, Platform)

  defp adapter,
    do: Application.get_env(:trenino, :virtual_joystick_system_adapter, SystemAdapter)
end
