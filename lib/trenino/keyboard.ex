defmodule Trenino.Keyboard do
  @moduledoc """
  Sends keystrokes via external keystroke executable.

  Uses a bundled Rust executable that wraps the Windows SendInput API
  to simulate keyboard input with proper key down/up events for hold behavior.
  """

  require Logger

  @doc """
  Press a key down (hold).

  The key will remain pressed until `key_up/1` is called.

  ## Parameters

    * `keystroke` - Key combination string (e.g., "W", "CTRL+S", "SHIFT+F1")

  ## Examples

      iex> Keyboard.key_down("W")
      :ok

      iex> Keyboard.key_down("CTRL+SHIFT+S")
      :ok
  """
  @spec key_down(String.t()) :: :ok | {:error, term()}
  def key_down(keystroke) when is_binary(keystroke) do
    execute("down", keystroke)
  end

  @doc """
  Release a key.

  ## Parameters

    * `keystroke` - Key combination string (e.g., "W", "CTRL+S", "SHIFT+F1")

  ## Examples

      iex> Keyboard.key_up("W")
      :ok
  """
  @spec key_up(String.t()) :: :ok | {:error, term()}
  def key_up(keystroke) when is_binary(keystroke) do
    execute("up", keystroke)
  end

  @doc """
  Tap a key (press and release).

  ## Parameters

    * `keystroke` - Key combination string (e.g., "W", "CTRL+S", "SHIFT+F1")

  ## Examples

      iex> Keyboard.tap("F1")
      :ok
  """
  @spec tap(String.t()) :: :ok | {:error, term()}
  def tap(keystroke) when is_binary(keystroke) do
    execute("tap", keystroke)
  end

  @doc """
  Check if the keystroke executable is available.
  """
  @spec available?() :: boolean()
  def available? do
    match?({:ok, _}, executable_path())
  end

  @doc """
  Returns the path to the keystroke executable.

  Checks in order:
  1. Tauri sidecar location (next to main executable)
  2. Bundled binary in priv/bin (for releases)
  3. Development build location

  Returns `{:ok, path}` or `{:error, :keystroke_not_found}`.
  """
  @spec executable_path() :: {:ok, String.t()} | {:error, :keystroke_not_found}
  def executable_path do
    cond do
      tauri_path = tauri_sidecar_executable() ->
        {:ok, tauri_path}

      bundled_path = bundled_executable() ->
        {:ok, bundled_path}

      dev_path = dev_executable() ->
        {:ok, dev_path}

      true ->
        {:error, :keystroke_not_found}
    end
  end

  # Execute keystroke command
  defp execute(action, keystroke) do
    case executable_path() do
      {:ok, path} ->
        case System.cmd(path, [action, keystroke], stderr_to_stdout: true) do
          {_output, 0} ->
            :ok

          {output, exit_code} ->
            Logger.warning(
              "[Keyboard] Command failed: action=#{action} keystroke=#{keystroke} " <>
                "exit_code=#{exit_code} output=#{output}"
            )

            {:error, {:command_failed, exit_code, output}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Check for keystroke in Tauri sidecar location
  defp tauri_sidecar_executable do
    binary_name = binary_name()

    case System.get_env("APP_PATH") do
      nil ->
        nil

      app_path ->
        path = Path.join(app_path, binary_name)
        if File.exists?(path), do: path, else: nil
    end
  end

  # Check for bundled keystroke in priv/bin
  defp bundled_executable do
    binary_name = binary_name()

    paths = [
      # Release build location
      Application.app_dir(:trenino, Path.join(["priv", "bin", binary_name])),
      # Dev build location
      Path.join([:code.priv_dir(:trenino), "bin", binary_name])
    ]

    Enum.find(paths, &File.exists?/1)
  end

  # Check for keystroke in development tauri/keystroke/target/release
  defp dev_executable do
    binary_name = binary_name()

    # In development, check the tauri/keystroke build output
    paths = [
      Path.join([File.cwd!(), "tauri", "keystroke", "target", "release", binary_name]),
      Path.join([File.cwd!(), "tauri", "keystroke", "target", "debug", binary_name])
    ]

    Enum.find(paths, &File.exists?/1)
  end

  # Platform-specific binary name
  defp binary_name do
    case :os.type() do
      {:win32, _} -> "keystroke.exe"
      _ -> "keystroke"
    end
  end
end
