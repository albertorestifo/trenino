defmodule TswIo.Simulator.AutoConfigTest do
  # Non-async because the Simulator.Connection GenServer needs database access
  use TswIo.DataCase, async: false

  alias TswIo.Simulator.AutoConfig
  alias TswIo.Simulator.Config

  # Allow the Connection GenServer to access the database sandbox
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(TswIo.Repo, {:shared, self()})
    :ok
  end

  describe "default_url/0" do
    test "returns the default TSW API URL" do
      assert AutoConfig.default_url() == "http://localhost:31270"
    end
  end

  describe "windows?/0" do
    test "returns a boolean" do
      result = AutoConfig.windows?()
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
          assert {:error, :not_windows} = AutoConfig.auto_detect_api_key()
      end
    end
  end

  describe "auto_configure/0" do
    test "returns {:error, :not_windows} on non-Windows platforms" do
      case :os.type() do
        {:win32, _} ->
          :ok

        _ ->
          assert {:error, :not_windows} = AutoConfig.auto_configure()
      end
    end
  end

  describe "ensure_config/0" do
    test "returns existing config when present" do
      {:ok, _} = create_config()

      assert {:ok, config} = AutoConfig.ensure_config()
      assert config.url == "http://localhost:31270"
      assert config.api_key == "test-api-key"
    end

    test "returns {:error, :not_found} when no config and not on Windows" do
      case :os.type() do
        {:win32, _} ->
          # On Windows, it would attempt auto-detection
          :ok

        _ ->
          assert {:error, :not_found} = AutoConfig.ensure_config()
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
    |> TswIo.Repo.insert()
  end
end
