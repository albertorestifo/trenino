defmodule Trenino.SettingsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Settings

  describe "error_reporting?/0" do
    test "returns false when no preference is set" do
      refute Settings.error_reporting?()
    end

    test "returns true when set to :enabled" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      assert Settings.error_reporting?()
    end

    test "returns false when set to :disabled" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      refute Settings.error_reporting?()
    end
  end

  describe "error_reporting_set?/0" do
    test "returns false when no preference is set" do
      refute Settings.error_reporting_set?()
    end

    test "returns true after a choice is made (enabled)" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      assert Settings.error_reporting_set?()
    end

    test "returns true after a choice is made (disabled)" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      assert Settings.error_reporting_set?()
    end
  end

  describe "set_error_reporting/1" do
    test "rejects values other than :enabled or :disabled" do
      assert_raise FunctionClauseError, fn ->
        Settings.set_error_reporting(:maybe)
      end
    end

    test "upserts an existing preference" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, _} = Settings.set_error_reporting(:disabled)
      refute Settings.error_reporting?()
    end
  end

  describe "sentry_before_send/1" do
    test "returns false when error reporting is disabled (default)" do
      assert false == Settings.sentry_before_send(%{event: :stub})
    end

    test "returns false when explicitly disabled" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      assert false == Settings.sentry_before_send(%{event: :stub})
    end

    test "returns the event unchanged when enabled" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      event = %{message: "boom"}
      assert ^event = Settings.sentry_before_send(event)
    end
  end

  describe "simulator_url/0" do
    test "returns the default URL when unset" do
      assert "http://localhost:31270" = Settings.simulator_url()
    end

    test "returns the stored URL when set" do
      {:ok, _} = Settings.set_simulator_url("http://192.168.1.10:31270")
      assert "http://192.168.1.10:31270" = Settings.simulator_url()
    end
  end

  describe "set_simulator_url/1" do
    test "stores a URL" do
      {:ok, _} = Settings.set_simulator_url("http://example.local:31270")
      assert "http://example.local:31270" = Settings.simulator_url()
    end
  end

  describe "api_key/0" do
    test "returns the stored key when set" do
      {:ok, _} = Settings.set_api_key("manual-key-123")
      assert {:ok, "manual-key-123"} = Settings.api_key()
    end

    test "delegates to Settings.Simulator on non-Windows when no key is stored" do
      # On non-Windows machines with no DB entry, file read returns :not_windows
      unless Trenino.Settings.Simulator.windows?() do
        assert {:error, :not_windows} = Settings.api_key()
      end
    end
  end

  describe "set_api_key/1" do
    test "persists the manual override" do
      {:ok, _} = Settings.set_api_key("override-abc")
      assert {:ok, "override-abc"} = Settings.api_key()
    end

    test "subsequent calls reflect the override" do
      {:ok, _} = Settings.set_api_key("first")
      {:ok, _} = Settings.set_api_key("second")
      assert {:ok, "second"} = Settings.api_key()
    end
  end
end
