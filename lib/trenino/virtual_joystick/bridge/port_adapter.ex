defmodule Trenino.VirtualJoystick.Bridge.PortAdapter do
  @moduledoc false

  def open(_owner, path, _opts) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :stream,
        :exit_status,
        :use_stdio,
        args: []
      ])

    {:ok, port}
  rescue
    error -> {:error, error}
  end

  def send_line(port, line), do: Port.command(port, line <> "\n")

  def close(port) do
    if Port.info(port), do: Port.close(port), else: :ok
  end
end
