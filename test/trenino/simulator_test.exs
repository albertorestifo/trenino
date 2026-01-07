defmodule Trenino.SimulatorTest do
  # Non-async because the Simulator.Connection GenServer needs database access
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Simulator
  alias Trenino.Simulator.Config

  # Allow the Connection GenServer to access the database sandbox
  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  describe "get_config/0" do
    test "returns {:error, :not_found} when no config exists" do
      assert {:error, :not_found} = Simulator.get_config()
    end

    test "returns {:ok, config} when config exists" do
      {:ok, created} = create_config()

      assert {:ok, config} = Simulator.get_config()
      assert config.id == created.id
      assert config.url == "http://localhost:31270"
    end
  end

  describe "create_config/1" do
    test "creates a new config with valid attributes" do
      attrs = %{
        url: "http://localhost:31270",
        api_key: "test-api-key"
      }

      assert {:ok, config} = Simulator.create_config(attrs)
      assert config.url == "http://localhost:31270"
      assert config.api_key == "test-api-key"
      assert config.auto_detected == false
    end

    test "returns error with invalid attributes" do
      attrs = %{url: "invalid-url", api_key: "test-key"}

      assert {:error, changeset} = Simulator.create_config(attrs)
      refute changeset.valid?
    end
  end

  describe "save_config/1" do
    test "creates config when none exists" do
      attrs = %{url: "http://localhost:31270", api_key: "test-key"}

      assert {:ok, config} = Simulator.save_config(attrs)
      assert config.url == "http://localhost:31270"
    end

    test "updates existing config" do
      {:ok, _} = create_config()

      attrs = %{url: "http://192.168.1.100:31270", api_key: "new-key"}

      assert {:ok, config} = Simulator.save_config(attrs)
      assert config.url == "http://192.168.1.100:31270"
      assert config.api_key == "new-key"

      # Verify only one config exists
      assert {:ok, _} = Simulator.get_config()
    end
  end

  describe "update_config/2" do
    test "updates an existing config" do
      {:ok, existing} = create_config()

      attrs = %{url: "http://new-host:31270"}

      assert {:ok, updated} = Simulator.update_config(existing, attrs)
      assert updated.id == existing.id
      assert updated.url == "http://new-host:31270"
      # api_key should remain unchanged
      assert updated.api_key == existing.api_key
    end
  end

  describe "delete_config/1" do
    test "deletes an existing config" do
      {:ok, config} = create_config()

      assert {:ok, _} = Simulator.delete_config(config)
      assert {:error, :not_found} = Simulator.get_config()
    end
  end

  describe "default_url/0" do
    test "returns the default TSW API URL" do
      assert Simulator.default_url() == "http://localhost:31270"
    end
  end

  describe "windows?/0" do
    test "returns a boolean" do
      result = Simulator.windows?()
      assert is_boolean(result)
    end
  end

  describe "auto_detect_api_key/0" do
    test "returns {:error, :not_windows} on non-Windows platforms" do
      # This test will only pass on non-Windows platforms
      case :os.type() do
        {:win32, _} ->
          # On Windows, this would try to actually detect
          :ok

        _ ->
          assert {:error, :not_windows} = Simulator.auto_detect_api_key()
      end
    end
  end

  # Helper to create a config for tests
  defp create_config(attrs \\ %{}) do
    default_attrs = %{
      url: "http://localhost:31270",
      api_key: "test-api-key"
    }

    %Config{}
    |> Config.changeset(Map.merge(default_attrs, attrs))
    |> Trenino.Repo.insert()
  end
end
