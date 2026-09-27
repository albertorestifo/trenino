defmodule Trenino.Settings.Simulator do
  @moduledoc """
  Reads the Train Sim World API key from disk on Windows.

  Replaces `Trenino.Simulator.AutoConfig`. Pure read — never writes.
  """

  @game_directories ["TrainSimWorld7", "TrainSimWorld6"]

  @doc """
  Reads `CommAPIKey.txt` from the TSW Saved/Config directory.

  Returns `{:ok, key}` on success.
  Returns `{:error, :not_windows | :userprofile_not_set | :file_not_found | :read_error}`.
  """
  @spec read_from_file() ::
          {:ok, String.t()}
          | {:error, :not_windows | :userprofile_not_set | :file_not_found | :read_error}
  def read_from_file do
    if windows?(), do: do_read(), else: {:error, :not_windows}
  end

  @doc """
  Reads the API key from supported Train Sim World directories under a Windows user profile.

  Newer game versions take precedence when more than one key exists.
  """
  @spec read_from_file(Path.t()) :: {:ok, String.t()} | {:error, :file_not_found | :read_error}
  def read_from_file(userprofile) do
    Enum.reduce_while(api_key_paths(userprofile), {:error, :file_not_found}, fn path, _result ->
      case File.read(path) do
        {:ok, content} -> {:halt, {:ok, String.trim(content)}}
        {:error, :enoent} -> {:cont, {:error, :file_not_found}}
        {:error, _} -> {:halt, {:error, :read_error}}
      end
    end)
  end

  @doc "Whether the current OS is Windows."
  @spec windows?() :: boolean()
  def windows? do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  defp do_read do
    case System.get_env("USERPROFILE") do
      nil ->
        {:error, :userprofile_not_set}

      userprofile ->
        read_from_file(userprofile)
    end
  end

  defp api_key_paths(userprofile) do
    Enum.map(@game_directories, fn game_directory ->
      Path.join([
        userprofile,
        "Documents",
        "My Games",
        game_directory,
        "Saved",
        "Config",
        "CommAPIKey.txt"
      ])
    end)
  end
end
