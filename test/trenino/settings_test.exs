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
    test "returns :ignore when error reporting is disabled (default)" do
      assert :ignore = Settings.sentry_before_send(%{event: :stub})
    end

    test "returns :ignore when explicitly disabled" do
      {:ok, _} = Settings.set_error_reporting(:disabled)
      assert :ignore = Settings.sentry_before_send(%{event: :stub})
    end

    test "returns the event unchanged when enabled" do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      event = %{message: "boom"}
      assert ^event = Settings.sentry_before_send(event)
    end
  end
end
