defmodule Trenino.VirtualJoystick.WindowsCommandTest do
  use ExUnit.Case, async: true

  alias Trenino.VirtualJoystick.Configurator.SystemAdapter

  @tag skip: not match?({:win32, _}, :os.type())
  test "captures Windows PowerShell output from a background port" do
    powershell = ~S(C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)

    assert {:ok, output, 0} =
             SystemAdapter.run_executable(
               powershell,
               ["-NoProfile", "-NonInteractive", "-Command", "Write-Output 'probe-ok'"],
               5_000
             )

    assert String.trim(output) == "probe-ok"
  end

  @tag skip: not match?({:win32, _}, :os.type())
  test "passes literal arguments to PowerShell scripts" do
    powershell = ~S(C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)
    value = ~S(C:\Program Files\owner's device\$literal)
    arguments = SystemAdapter.powershell_arguments("Write-Output $args[0]", [value])

    assert {:ok, output, 0} = SystemAdapter.run_executable(powershell, arguments, 5_000)
    assert String.trim(output) == value
  end
end
