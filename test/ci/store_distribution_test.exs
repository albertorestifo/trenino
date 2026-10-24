defmodule Trenino.CI.StoreDistributionTest do
  use ExUnit.Case, async: false

  setup do
    previous = System.get_env("TRENINO_DISTRIBUTION")

    on_exit(fn ->
      if previous do
        System.put_env("TRENINO_DISTRIBUTION", previous)
      else
        System.delete_env("TRENINO_DISTRIBUTION")
      end
    end)

    :ok
  end

  test "Store distribution leaves app updates to Windows" do
    System.put_env("TRENINO_DISTRIBUTION", "microsoft-store")
    config = Config.Reader.read!("config/runtime.exs", env: :test)
    assert config[:trenino][:start_app_version_checker] == false
    refute config[:trenino][:start_update_checker] == false
  end

  test "direct downloads keep their existing app update checker" do
    System.put_env("TRENINO_DISTRIBUTION", "direct")
    config = Config.Reader.read!("config/runtime.exs", env: :test)
    refute config[:trenino][:start_app_version_checker] == false
  end
end
