defmodule TswIo.Simulator.ConfigTest do
  use ExUnit.Case, async: true

  alias TswIo.Simulator.Config

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        url: "http://localhost:31270",
        api_key: "test-api-key"
      }

      changeset = Config.changeset(%Config{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with auto_detected flag" do
      attrs = %{
        url: "http://localhost:31270",
        api_key: "test-api-key",
        auto_detected: true
      }

      changeset = Config.changeset(%Config{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :auto_detected) == true
    end

    test "invalid changeset without url" do
      attrs = %{
        api_key: "test-api-key"
      }

      changeset = Config.changeset(%Config{}, attrs)

      refute changeset.valid?
      assert {:url, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "invalid changeset without api_key" do
      attrs = %{
        url: "http://localhost:31270"
      }

      changeset = Config.changeset(%Config{}, attrs)

      refute changeset.valid?
      assert {:api_key, {"can't be blank", _}} = hd(changeset.errors)
    end

    test "invalid changeset with invalid url scheme" do
      attrs = %{
        url: "ftp://localhost:31270",
        api_key: "test-api-key"
      }

      changeset = Config.changeset(%Config{}, attrs)

      refute changeset.valid?
      assert {:url, {"must be a valid HTTP or HTTPS URL", _}} = hd(changeset.errors)
    end

    test "invalid changeset with invalid url format" do
      attrs = %{
        url: "not-a-url",
        api_key: "test-api-key"
      }

      changeset = Config.changeset(%Config{}, attrs)

      refute changeset.valid?
      assert {:url, {"must be a valid HTTP or HTTPS URL", _}} = hd(changeset.errors)
    end

    test "valid changeset with https url" do
      attrs = %{
        url: "https://192.168.1.100:31270",
        api_key: "test-api-key"
      }

      changeset = Config.changeset(%Config{}, attrs)

      assert changeset.valid?
    end
  end
end
