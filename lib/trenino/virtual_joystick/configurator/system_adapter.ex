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

  def status do
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
    trusted_roots()
    |> Enum.map(&Path.join(&1, "vJoyConfig.exe"))
    |> Enum.find(&trusted_file?/1)
    |> case do
      nil -> {:error, :configurator_not_found}
      path -> {:ok, path}
    end
  end

  def elevate(path, arguments) when is_list(arguments) do
    if trusted_file?(path) do
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

  defp command(arguments) do
    if File.regular?(@powershell) do
      System.cmd(@powershell, arguments, stderr_to_stdout: true)
    else
      {"", 1}
    end
  end

  defp trusted_file?(path) do
    expanded = Path.expand(path)

    regular_file?(expanded) and
      Enum.any?(trusted_roots(), fn root ->
        relative = Path.relative_to(expanded, root)
        relative != expanded and relative != ".." and not String.starts_with?(relative, "../")
      end)
  end

  defp regular_file?(path) do
    match?({:ok, %File.Stat{type: :regular}}, File.lstat(path))
  end

  defp interface_directory do
    trusted_roots()
    |> Enum.map(&Path.join(&1, "vJoyInterface.dll"))
    |> Enum.find(&trusted_file?/1)
    |> case do
      nil -> {:error, :interface_not_found}
      path -> {:ok, Path.dirname(path)}
    end
  end

  defp trusted_roots do
    app_dir = Application.app_dir(:trenino)

    [
      Path.join([app_dir, "priv", "bin"]),
      Path.join([app_dir, "priv", "resources"]),
      Path.join(app_dir, "resources")
    ]
    |> Enum.map(&Path.expand/1)
    |> Enum.uniq()
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
