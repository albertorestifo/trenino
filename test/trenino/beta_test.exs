defmodule Trenino.BetaTest do
  # Switches the global :beta_features mode, so it cannot run async
  use Trenino.DataCase, async: false

  alias Trenino.Beta
  alias Trenino.MCP.ToolRegistry
  alias Trenino.Settings

  setup do
    previous = Application.get_env(:trenino, :beta_features)
    on_exit(fn -> Application.put_env(:trenino, :beta_features, previous) end)
    :ok
  end

  describe "enabled?/1" do
    test "is always true in :all mode" do
      Application.put_env(:trenino, :beta_features, :all)
      {:ok, _} = Settings.set_beta_features(:disabled)

      assert Enum.all?(Beta.features(), &Beta.enabled?/1)
      refute Beta.configurable?()
    end

    test "follows the setting in :setting mode, off by default" do
      Application.put_env(:trenino, :beta_features, :setting)
      assert Beta.configurable?()
      refute Enum.any?(Beta.features(), &Beta.enabled?/1)

      {:ok, _} = Settings.set_beta_features(:enabled)
      assert Enum.all?(Beta.features(), &Beta.enabled?/1)
    end
  end

  describe "MCP tools" do
    test "beta tools are hidden and not callable while beta features are off" do
      Application.put_env(:trenino, :beta_features, :setting)

      names = Enum.map(ToolRegistry.list_tools(), & &1.name)
      assert length(names) == 47
      refute "get_selector" in names
      refute "list_stepper_axes" in names

      assert {:error, "Unknown tool: get_selector"} =
               ToolRegistry.call_tool("get_selector", %{})
    end

    test "beta tools are listed once beta features are on" do
      Application.put_env(:trenino, :beta_features, :setting)
      {:ok, _} = Settings.set_beta_features(:enabled)

      assert length(ToolRegistry.list_tools()) == 66
    end
  end
end
