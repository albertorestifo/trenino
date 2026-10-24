defmodule Trenino.CI.DesktopDistributionTest do
  use ExUnit.Case, async: false

  setup do
    previous = System.get_env("TRENINO_DISTRIBUTION")

    on_exit(fn ->
      if previous,
        do: System.put_env("TRENINO_DISTRIBUTION", previous),
        else: System.delete_env("TRENINO_DISTRIBUTION")
    end)
  end

  test "Tauri updater builds suppress duplicate app notices but retain firmware updates" do
    System.put_env("TRENINO_DISTRIBUTION", "tauri-updater")
    config = Config.Reader.read!("config/runtime.exs", env: :test)
    assert config[:trenino][:start_app_version_checker] == false
    refute config[:trenino][:start_update_checker] == false
  end

  test "direct and server distributions keep existing update behavior" do
    for distribution <- ["direct", ""] do
      System.put_env("TRENINO_DISTRIBUTION", distribution)
      config = Config.Reader.read!("config/runtime.exs", env: :test)
      refute config[:trenino][:start_app_version_checker] == false
    end
  end
end
