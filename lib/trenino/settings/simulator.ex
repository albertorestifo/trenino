defmodule Trenino.Settings.Simulator do
  @moduledoc """
  Reads the Train Sim World API key from disk on Windows.

  Replaces `Trenino.Simulator.AutoConfig`. Pure read — never writes.
  """

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
        path = api_key_path(userprofile)

        case File.read(path) do
          {:ok, content} -> {:ok, String.trim(content)}
          {:error, :enoent} -> {:error, :file_not_found}
          {:error, _} -> {:error, :read_error}
        end
    end
  end

  defp api_key_path(userprofile) do
    Path.join([
      userprofile,
      "Documents",
      "My Games",
      "TrainSimWorld6",
      "Saved",
      "Config",
      "CommAPIKey.txt"
    ])
  end
end
