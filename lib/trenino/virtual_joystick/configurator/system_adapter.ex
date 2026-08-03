defmodule Trenino.VirtualJoystick.Configurator.SystemAdapter do
  @moduledoc false

  @powershell ~S(C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)

  @elevation_script """
  try {
    $process = Start-Process -FilePath $args[0] -ArgumentList $args[1] -Verb RunAs -Wait -PassThru
    exit $process.ExitCode
  } catch {
    $nativeCode = $_.Exception.NativeErrorCode
    if (-not $nativeCode -and $_.Exception.InnerException) {
      $nativeCode = $_.Exception.InnerException.NativeErrorCode
    }
    if ($nativeCode -eq 1223) { exit 1223 }
    exit 1
  }
  """

  @status_script """
  $source = @'
  using System;
  using System.Runtime.InteropServices;
  public static class TreninoVJoyProbe {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
    [DllImport("vJoyInterface.dll")] public static extern bool vJoyEnabled();
    [DllImport("vJoyInterface.dll")] public static extern int GetVJDStatus(uint id);
    [DllImport("vJoyInterface.dll")] public static extern bool GetVJDAxisExist(uint id, uint usage);
    [DllImport("vJoyInterface.dll")] public static extern int GetVJDButtonNumber(uint id);
    [DllImport("vJoyInterface.dll")] public static extern int GetVJDDiscPovNumber(uint id);
    [DllImport("vJoyInterface.dll")] public static extern int GetVJDContPovNumber(uint id);
    [DllImport("vJoyInterface.dll")] public static extern bool IsDeviceFfb(uint id);
  }
  '@
  try {
    Add-Type -TypeDefinition $source -ErrorAction Stop
    if (-not [TreninoVJoyProbe]::SetDllDirectory($args[0])) { 'driver_missing'; exit 0 }
    if (-not [TreninoVJoyProbe]::vJoyEnabled()) { 'driver_missing'; exit 0 }
    $state = [TreninoVJoyProbe]::GetVJDStatus(1)
    if ($state -eq 3 -or $state -eq 4) { 'device_missing'; exit 0 }
    if ($state -eq 2) { 'busy'; exit 0 }
    $axes = 0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37
    $extraAxes = 0x38,0xB0,0xBA,0xBB,0xC4,0xC5,0xC6,0xC8
    $valid = $true
    foreach ($axis in $axes) { $valid = $valid -and [TreninoVJoyProbe]::GetVJDAxisExist(1, $axis) }
    foreach ($axis in $extraAxes) { $valid = $valid -and (-not [TreninoVJoyProbe]::GetVJDAxisExist(1, $axis)) }
    $valid = $valid -and ([TreninoVJoyProbe]::GetVJDButtonNumber(1) -eq 32)
    $valid = $valid -and ([TreninoVJoyProbe]::GetVJDDiscPovNumber(1) -eq 0)
    $valid = $valid -and ([TreninoVJoyProbe]::GetVJDContPovNumber(1) -eq 0)
    $valid = $valid -and (-not [TreninoVJoyProbe]::IsDeviceFfb(1))
    if ($valid) { 'compatible' } else { 'incompatible' }
  } catch { 'driver_missing' }
  """

  @reparse_script """
  try {
    $item = Get-Item -LiteralPath $args[0] -Force -ErrorAction Stop
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { exit 10 }
    exit 0
  } catch { exit 11 }
  """

  def status, do: status(5_000)

  def status(timeout_ms) when is_integer(timeout_ms) and timeout_ms >= 0 do
    status(timeout_ms, &do_status/0)
  end

  @doc false
  def status(timeout_ms, operation)
      when is_integer(timeout_ms) and timeout_ms >= 0 and is_function(operation, 0) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms
    Process.put(:virtual_joystick_status_deadline, deadline)

    try do
      result = operation.()

      case {result, System.monotonic_time(:millisecond) <= deadline} do
        {status, true}
        when status in [:driver_missing, :device_missing, :compatible, :incompatible, :busy] ->
          status

        _ ->
          :driver_missing
      end
    after
      Process.delete(:virtual_joystick_status_deadline)
    end
  end

  defp do_status do
    case interface_directory() do
      {:ok, dll_directory} ->
        case command(["-NoProfile", "-NonInteractive", "-Command", @status_script, dll_directory]) do
          {output, 0} -> parse_status(output)
          _ -> :driver_missing
        end

      {:error, :interface_not_found} ->
        :driver_missing
    end
  end

  def configurator_path do
    trusted_locations()
    |> Enum.map(fn {_anchor, root} -> Path.join(root, "vJoyConfig.exe") end)
    |> Enum.find(&trusted_file?/1)
    |> case do
      nil -> {:error, :configurator_not_found}
      path -> {:ok, path}
    end
  end

  def elevate(path, arguments) when is_list(arguments) do
    if String.downcase(Path.basename(path)) == "vjoyconfig.exe" and trusted_file?(path) do
      quoted_arguments = Enum.map_join(arguments, " ", &quote_argument/1)

      case command([
             "-NoProfile",
             "-NonInteractive",
             "-Command",
             @elevation_script,
             path,
             quoted_arguments
           ]) do
        {_output, 0} -> {:ok, 0}
        {_output, 1223} -> {:error, 1223}
        {_output, exit_code} -> {:ok, exit_code}
      end
    else
      {:error, :untrusted_configurator}
    end
  end

  def sleep(milliseconds), do: Process.sleep(milliseconds)
  def monotonic_time, do: System.monotonic_time(:millisecond)

  @doc false
  def run_executable(path, arguments, timeout)
      when is_binary(path) and is_list(arguments) and
             (timeout == :infinity or (is_integer(timeout) and timeout >= 0)) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :stream,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        args: arguments
      ])

    pid = port |> Port.info(:os_pid) |> elem(1)
    collect_command(port, pid, timeout, System.monotonic_time(:millisecond), "")
  rescue
    _ -> {:error, :launch_failed}
  end

  @doc false
  def run_status_executable(path, arguments) do
    run_executable(path, arguments, remaining_status_budget())
  end

  @doc false
  def trusted_file?(path, locations, reparse_probe \\ &native_reparse_point?/1)

  def trusted_file?(path, locations, reparse_probe)
      when is_binary(path) and is_list(locations) and is_function(reparse_probe, 1) do
    expanded = Path.expand(path)

    regular_file?(expanded) and
      Enum.any?(locations, fn location ->
        {anchor, root} = normalize_location(location)

        contained_or_same?(root, anchor) and contained?(expanded, root) and
          anchor
          |> path_components_to(expanded)
          |> Enum.all?(&(not link_or_reparse?(&1, reparse_probe)))
      end)
  end

  defp command(arguments) do
    if File.regular?(@powershell) do
      case run_executable(@powershell, arguments, remaining_status_budget()) do
        {:ok, output, status} -> {output, status}
        {:error, _reason} -> {"", 1}
      end
    else
      {"", 1}
    end
  end

  defp remaining_status_budget do
    case Process.get(:virtual_joystick_status_deadline) do
      nil -> :infinity
      deadline -> max(deadline - System.monotonic_time(:millisecond), 0)
    end
  end

  defp collect_command(port, pid, timeout, started, output) do
    receive do
      {^port, {:data, data}} ->
        collect_command(port, pid, timeout, started, output <> data)

      {^port, {:exit_status, status}} ->
        {:ok, output, status}
    after
      command_remaining(timeout, started) ->
        terminate_and_reap(port, pid)
        {:error, {:timeout, pid, output}}
    end
  end

  defp command_remaining(:infinity, _started), do: :infinity

  defp command_remaining(timeout, started) do
    max(timeout - (System.monotonic_time(:millisecond) - started), 0)
  end

  defp terminate_and_reap(port, pid) do
    if Port.info(port, :os_pid) == {:os_pid, pid}, do: terminate_process_tree(pid, :term)

    unless await_exit(port, 500) do
      if Port.info(port, :os_pid) == {:os_pid, pid}, do: terminate_process_tree(pid, :kill)
      await_exit(port, 500)
    end

    if Port.info(port), do: Port.close(port)
    :ok
  end

  defp terminate_process_tree(pid, signal) when is_integer(pid) and pid > 0 do
    case :os.type() do
      {:win32, _} -> terminate_windows_tree(pid)
      {:unix, _} -> terminate_unix_tree(pid, signal)
    end
  end

  defp terminate_windows_tree(pid) do
    taskkill = ~S(C:\Windows\System32\taskkill.exe)

    if File.regular?(taskkill) do
      control_process(taskkill, ["/PID", Integer.to_string(pid), "/T", "/F"])
    end
  end

  defp terminate_unix_tree(pid, signal) do
    signal_arg = if signal == :kill, do: "-KILL", else: "-TERM"

    if File.regular?("/usr/bin/pkill") do
      control_process("/usr/bin/pkill", [signal_arg, "-P", Integer.to_string(pid)])
    end

    control_process("/bin/kill", [signal_arg, Integer.to_string(pid)])
  end

  defp control_process(path, arguments) do
    port =
      Port.open({:spawn_executable, path}, [
        :binary,
        :stream,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        args: arguments
      ])

    await_exit(port, 2_000)
    if Port.info(port), do: Port.close(port)
    :ok
  rescue
    _ -> :ok
  end

  defp await_exit(port, timeout) do
    receive do
      {^port, {:exit_status, _status}} -> true
      {^port, {:data, _data}} -> await_exit(port, timeout)
    after
      timeout -> false
    end
  end

  defp trusted_file?(path) do
    trusted_file?(path, trusted_locations())
  end

  defp regular_file?(path) do
    match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))
  end

  defp contained?(path, root) do
    relative = Path.relative_to(path, root)
    relative != path and relative != ".." and not String.starts_with?(relative, "../")
  end

  defp contained_or_same?(path, root), do: path == root or contained?(path, root)

  defp normalize_location({anchor, root}), do: {Path.expand(anchor), Path.expand(root)}

  defp normalize_location(root) when is_binary(root) do
    expanded = Path.expand(root)
    {expanded, expanded}
  end

  defp path_components_to(root, path) do
    relative = Path.relative_to(path, root)

    relative
    |> Path.split()
    |> Enum.scan(root, &Path.join(&2, &1))
    |> then(&[root | &1])
  end

  defp link_or_reparse?(path, reparse_probe) do
    match?({:ok, %File.Stat{type: :symlink}}, File.lstat(path)) or
      match?({:ok, _target}, :file.read_link_all(String.to_charlist(path))) or
      reparse_probe.(path)
  end

  defp native_reparse_point?(path) do
    if match?({:win32, _}, :os.type()) do
      case command(["-NoProfile", "-NonInteractive", "-Command", @reparse_script, path]) do
        {_output, 0} -> false
        {_output, 10} -> true
        _ -> true
      end
    else
      false
    end
  end

  defp interface_directory do
    trusted_locations()
    |> Enum.map(fn {_anchor, root} -> Path.join(root, "vJoyInterface.dll") end)
    |> Enum.find(&trusted_file?/1)
    |> case do
      nil -> {:error, :interface_not_found}
      path -> {:ok, Path.dirname(path)}
    end
  end

  defp trusted_locations do
    app_dir = Application.app_dir(:trenino)

    [
      Path.join([app_dir, "priv", "bin"]),
      Path.join([app_dir, "priv", "resources"]),
      Path.join(app_dir, "resources")
    ]
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
    |> Enum.map(&{Path.expand(app_dir), &1})
  end

  defp quote_argument(argument), do: ~s("#{String.replace(argument, "\"", "\\\"")}")

  defp parse_status(output) do
    output
    |> String.trim()
    |> String.split(~r/\s+/, trim: true)
    |> List.last()
    |> case do
      "device_missing" -> :device_missing
      "compatible" -> :compatible
      "incompatible" -> :incompatible
      "busy" -> :busy
      _ -> :driver_missing
    end
  end
end
