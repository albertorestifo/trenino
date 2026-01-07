defmodule Trenino.PathsTest do
  use ExUnit.Case, async: true

  alias Trenino.Paths

  describe "data_dir/0" do
    test "returns a string path" do
      dir = Paths.data_dir()
      assert is_binary(dir)
    end

    test "creates the directory if it doesn't exist" do
      dir = Paths.data_dir()
      assert File.exists?(dir)
      assert File.dir?(dir)
    end

    test "returns consistent path on multiple calls" do
      dir1 = Paths.data_dir()
      dir2 = Paths.data_dir()
      assert dir1 == dir2
    end

    test "path contains app name" do
      dir = Paths.data_dir()
      # Should contain either "Trenino" or "trenino" depending on platform
      assert String.contains?(dir, "Trenino") or String.contains?(dir, "trenino")
    end
  end

  describe "database_path/0" do
    test "returns a path ending with .db" do
      path = Paths.database_path()
      assert String.ends_with?(path, ".db")
    end

    test "returns path within data_dir" do
      data_dir = Paths.data_dir()
      db_path = Paths.database_path()
      assert String.starts_with?(db_path, data_dir)
    end

    test "returns trenino.db filename" do
      path = Paths.database_path()
      assert String.ends_with?(path, "trenino.db")
    end
  end
end
