defmodule Trenino.Test.ForbiddenUART do
  @moduledoc """
  Default Mimic stub for Circuits.UART. Every function raises with a clear
  message so tests that forget to stub real serial access fail loudly instead
  of touching real hardware.
  """

  def open(_pid, _port), do: forbid("Circuits.UART.open/2")
  def open(_pid, _port, _opts), do: forbid("Circuits.UART.open/3")
  def close(_pid), do: forbid("Circuits.UART.close/1")
  def write(_pid, _data), do: forbid("Circuits.UART.write/2")
  def write(_pid, _data, _opts), do: forbid("Circuits.UART.write/3")
  def read(_pid), do: forbid("Circuits.UART.read/1")
  def read(_pid, _timeout), do: forbid("Circuits.UART.read/2")
  def enumerate, do: forbid("Circuits.UART.enumerate/0")
  def start_link, do: forbid("Circuits.UART.start_link/0")
  def start_link(_opts), do: forbid("Circuits.UART.start_link/1")
  def stop(_pid), do: forbid("Circuits.UART.stop/1")
  def controlling_process(_pid, _new_owner), do: forbid("Circuits.UART.controlling_process/2")
  def configure(_pid, _opts), do: forbid("Circuits.UART.configure/2")
  def configuration(_pid), do: forbid("Circuits.UART.configuration/1")
  def flush(_pid), do: forbid("Circuits.UART.flush/1")
  def flush(_pid, _direction), do: forbid("Circuits.UART.flush/2")
  def drain(_pid), do: forbid("Circuits.UART.drain/1")
  def send_break(_pid), do: forbid("Circuits.UART.send_break/1")
  def send_break(_pid, _duration), do: forbid("Circuits.UART.send_break/2")
  def set_break(_pid, _level), do: forbid("Circuits.UART.set_break/2")
  def set_dtr(_pid, _level), do: forbid("Circuits.UART.set_dtr/2")
  def set_rts(_pid, _level), do: forbid("Circuits.UART.set_rts/2")
  def signals(_pid), do: forbid("Circuits.UART.signals/1")
  def find_pids, do: forbid("Circuits.UART.find_pids/0")

  # OTP callbacks exported by Circuits.UART (it is itself a GenServer).
  # Required here because Mimic.stub_with verifies the stub module declares
  # every export of the real module — they are never invoked directly by tests.
  def child_spec(_arg), do: forbid("Circuits.UART.child_spec/1")
  def init(_arg), do: forbid("Circuits.UART.init/1")
  def handle_call(_request, _from, _state), do: forbid("Circuits.UART.handle_call/3")
  def handle_cast(_request, _state), do: forbid("Circuits.UART.handle_cast/2")
  def handle_info(_message, _state), do: forbid("Circuits.UART.handle_info/2")
  def code_change(_old_vsn, _state, _extra), do: forbid("Circuits.UART.code_change/3")
  def terminate(_reason, _state), do: forbid("Circuits.UART.terminate/2")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not touch real serial hardware. Stub explicitly with Mimic:

        expect(Circuits.UART, :open, fn _pid, _port, _opts -> :ok end)

    Or use a higher-level helper from Trenino.SerialTestHelpers.
    """
  end
end

defmodule Trenino.Test.ForbiddenAvrdude do
  @moduledoc """
  Default Mimic stub for Trenino.Firmware.Avrdude.
  Raises on any call so tests that forget to stub avrdude fail loudly
  instead of spawning real subprocesses.
  """

  def executable_path, do: forbid("Avrdude.executable_path/0")
  def executable_path!, do: forbid("Avrdude.executable_path!/0")
  def available?, do: forbid("Avrdude.available?/0")
  def version, do: forbid("Avrdude.version/0")
  def conf_path, do: forbid("Avrdude.conf_path/0")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not spawn real avrdude subprocesses. Stub explicitly:

        expect(Trenino.Firmware.Avrdude, :available?, fn -> true end)
    """
  end
end

defmodule Trenino.Test.ForbiddenAvrdudeRunner do
  @moduledoc """
  Default Mimic stub for Trenino.Firmware.AvrdudeRunner.
  Raises on any call so tests that forget to stub avrdude fail loudly
  instead of spawning real subprocesses.
  """

  def run(_avrdude_path, _args, _progress_callback),
    do: forbid("AvrdudeRunner.run/3")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not spawn real avrdude subprocesses. Stub explicitly:

        expect(Trenino.Firmware.AvrdudeRunner, :run, fn _, _, _ -> {:ok, "ok output"} end)
    """
  end
end

defmodule Trenino.Test.ForbiddenSerialDiscovery do
  @moduledoc """
  Default Mimic stub for Trenino.Serial.Discovery. Raises on any call.
  """

  def discover(_uart_pid), do: forbid("Trenino.Serial.Discovery.discover/1")

  defp forbid(call) do
    raise """
    Real #{call} was called from a test.

    Tests must not perform real device discovery. Stub explicitly:

        expect(Trenino.Serial.Discovery, :discover, fn _pid ->
          {:ok, %Trenino.Serial.Protocol.IdentityResponse{...}}
        end)
    """
  end
end
