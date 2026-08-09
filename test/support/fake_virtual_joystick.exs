defmodule Trenino.Test.FakeVirtualJoystick do
  @moduledoc false

  def open(owner, path, opts) do
    handle = make_ref()

    send(
      Application.fetch_env!(:trenino, :virtual_joystick_fake_test),
      {:opened, owner, handle, path, opts}
    )

    {:ok, handle}
  end

  def send_line(handle, line) do
    send(Application.fetch_env!(:trenino, :virtual_joystick_fake_test), {:sent, handle, line})
    :ok
  end

  def close(handle) do
    send(Application.fetch_env!(:trenino, :virtual_joystick_fake_test), {:closed, handle})
    :ok
  end

  def stdout(owner, handle, data),
    do: send(owner, {:virtual_joystick_adapter, handle, {:stdout, data}})

  def stderr(owner, handle, data),
    do: send(owner, {:virtual_joystick_adapter, handle, {:stderr, data}})

  def exit(owner, handle, status),
    do: send(owner, {:virtual_joystick_adapter, handle, {:exit, status}})
end
