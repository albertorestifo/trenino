defmodule Trenino.VirtualJoystick.Bridge.PortAdapter do
  @moduledoc false

  def open(_owner, path, opts) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :stream,
        :exit_status,
        :use_stdio,
        args: Keyword.get(opts, :args, ["serve"])
      ])

    {:ok, port}
  rescue
    error -> {:error, error}
  end

  def send_line(port, line) do
    true = Port.command(port, line <> "\n")
    :ok
  end

  def close(port) do
    if Port.info(port), do: Port.close(port), else: :ok
  end
end
