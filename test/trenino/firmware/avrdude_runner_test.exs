defmodule Trenino.Firmware.AvrdudeRunnerTest do
  use Trenino.DataCase, async: true

  alias Trenino.Firmware.AvrdudeRunner

  # These tests bypass the ForbiddenAvrdudeRunner guard on purpose: they spawn
  # /bin/sh, never avrdude, so no hardware is touched.
  defp run_shell(script, callback \\ nil) do
    Mimic.call_original(AvrdudeRunner, :run, ["/bin/sh", ["-c", script], callback])
  end

  describe "run/3" do
    test "replaces invalid UTF-8 bytes echoed from the device" do
      # A running sketch answering avr109 commands produces raw bytes such as 0x80.
      assert {:error, output} = run_shell(~S"printf 'Programmer id = \200;\n'; exit 1")

      assert String.valid?(output)
      assert output =~ "Programmer id = "
    end

    test "kills the subprocess when the calling process is killed" do
      # The subprocess reports its OS pid, then hangs like a stuck avrdude.
      caller =
        spawn(fn ->
          receive do
            :go -> run_shell("echo $$; exec sleep 30", fn _, _ -> :ok end)
          end
        end)

      # The :receive trace fires when the output reaches the caller's mailbox,
      # which can be before the runner has started its watcher. Wait for the
      # watcher's spawn too, or the kill below can land while nothing is
      # watching.
      :erlang.trace(caller, true, [:receive, :procs])
      send(caller, :go)
      assert_receive {:trace, ^caller, :receive, {_port, {:data, data}}}, 2_000
      assert_receive {:trace, ^caller, :spawn, _watcher, _mfa}, 2_000
      os_pid = data |> String.trim() |> String.to_integer()
      assert os_process_alive?(os_pid)

      ref = Process.monitor(caller)
      Process.exit(caller, :kill)
      assert_receive {:DOWN, ^ref, :process, ^caller, :killed}

      assert eventually(fn -> not os_process_alive?(os_pid) end)
    end
  end

  defp os_process_alive?(os_pid) do
    {_, status} = System.cmd("kill", ["-0", to_string(os_pid)], stderr_to_stdout: true)
    status == 0
  end

  # Polls an OS process, which cannot be awaited with a message.
  defp eventually(fun, attempts \\ 50) do
    cond do
      fun.() ->
        true

      attempts == 0 ->
        false

      true ->
        Process.sleep(20)
        eventually(fun, attempts - 1)
    end
  end
end
