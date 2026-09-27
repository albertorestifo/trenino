defmodule Trenino.Settings.SimulatorTest do
  use ExUnit.Case, async: true

  alias Trenino.Settings.Simulator

  @moduletag :tmp_dir

  describe "windows?/0" do
    test "returns a boolean" do
      assert is_boolean(Simulator.windows?())
    end
  end

  describe "read_from_file/0 (non-Windows)" do
    test "returns :not_windows on non-Windows platforms" do
      unless Simulator.windows?() do
        assert {:error, :not_windows} = Simulator.read_from_file()
      end
    end
  end

  describe "read_from_file/1" do
    test "reads the TSW7 API key", %{tmp_dir: profile} do
      write_api_key(profile, "TrainSimWorld7", "tsw7-key\n")

      assert {:ok, "tsw7-key"} = Simulator.read_from_file(profile)
    end

    test "falls back to the TSW6 API key", %{tmp_dir: profile} do
      write_api_key(profile, "TrainSimWorld6", "tsw6-key")

      assert {:ok, "tsw6-key"} = Simulator.read_from_file(profile)
    end

    test "prefers the TSW7 API key when both versions are installed", %{tmp_dir: profile} do
      write_api_key(profile, "TrainSimWorld6", "tsw6-key")
      write_api_key(profile, "TrainSimWorld7", "tsw7-key")

      assert {:ok, "tsw7-key"} = Simulator.read_from_file(profile)
    end

    test "returns :file_not_found when neither version has an API key", %{tmp_dir: profile} do
      assert {:error, :file_not_found} = Simulator.read_from_file(profile)
    end
  end

  defp write_api_key(profile, version_directory, contents) do
    directory =
      Path.join([profile, "Documents", "My Games", version_directory, "Saved", "Config"])

    File.mkdir_p!(directory)
    File.write!(Path.join(directory, "CommAPIKey.txt"), contents)
  end
end
