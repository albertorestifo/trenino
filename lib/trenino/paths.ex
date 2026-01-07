defmodule Trenino.Paths do
  @moduledoc """
  Platform-specific path resolution for application data.

  Returns appropriate directories based on the operating system:
  - macOS: ~/Library/Application Support/Trenino
  - Windows: %APPDATA%/Trenino
  - Linux: ~/.local/share/trenino (or $XDG_DATA_HOME/trenino)
  """

  @app_name "Trenino"
  @app_name_lower "trenino"

  @doc """
  Returns the platform-specific data directory for the application.

  The directory is created if it doesn't exist.
  """
  @spec data_dir() :: String.t()
  def data_dir do
    dir = get_data_dir()
    ensure_dir_exists(dir)
    dir
  end

  @doc """
  Returns the path to the database file.

  The parent directory is created if it doesn't exist.
  """
  @spec database_path() :: String.t()
  def database_path do
    Path.join(data_dir(), "#{@app_name_lower}.db")
  end

  defp get_data_dir do
    case :os.type() do
      {:unix, :darwin} -> get_macos_data_dir()
      {:win32, _} -> get_windows_data_dir()
      {:unix, _} -> get_linux_data_dir()
    end
  end

  # macOS: ~/Library/Application Support/Trenino
  defp get_macos_data_dir do
    home = System.get_env("HOME") || "~"
    Path.join([home, "Library", "Application Support", @app_name])
  end

  # Windows: %APPDATA%/Trenino
  defp get_windows_data_dir do
    appdata = System.get_env("APPDATA") || System.get_env("LOCALAPPDATA") || "."
    Path.join(appdata, @app_name)
  end

  # Linux/BSD: $XDG_DATA_HOME/trenino or ~/.local/share/trenino
  defp get_linux_data_dir do
    base_dir = get_xdg_data_home()
    Path.join(base_dir, @app_name_lower)
  end

  defp get_xdg_data_home do
    case System.get_env("XDG_DATA_HOME") do
      nil -> default_linux_data_home()
      "" -> default_linux_data_home()
      xdg_data -> xdg_data
    end
  end

  defp default_linux_data_home do
    home = System.get_env("HOME") || "~"
    Path.join([home, ".local", "share"])
  end

  defp ensure_dir_exists(dir) do
    File.mkdir_p!(dir)
  end
end
