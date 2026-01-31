defmodule Trenino.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Trenino.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Firmware.DeviceRegistry

  using do
    quote do
      alias Trenino.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Trenino.DataCase
    end
  end

  setup tags do
    Trenino.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(Trenino.Repo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @doc """
  Loads basic device configurations into the DeviceRegistry for testing.

  This helper loads a minimal manifest with common Arduino devices to support
  tests that need device configurations available.
  """
  def load_test_devices do
    manifest = %{
      "version" => "test",
      "project" => "trenino_firmware",
      "devices" => [
        %{
          "environment" => "uno",
          "displayName" => "Arduino Uno",
          "firmwareFile" => "trenino-uno.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "arduino",
            "mcu" => "atmega328p",
            "speed" => 115_200
          }
        },
        %{
          "environment" => "leonardo",
          "displayName" => "Arduino Leonardo",
          "firmwareFile" => "trenino-leonardo.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "avr109",
            "mcu" => "atmega32u4",
            "speed" => 57_600,
            "use1200bpsTouch" => true
          }
        },
        %{
          "environment" => "nanoatmega328",
          "displayName" => "Arduino Nano",
          "firmwareFile" => "trenino-nano.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "arduino",
            "mcu" => "atmega328p",
            "speed" => 115_200
          }
        },
        %{
          "environment" => "micro",
          "displayName" => "Arduino Micro",
          "firmwareFile" => "trenino-micro.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "avr109",
            "mcu" => "atmega32u4",
            "speed" => 57_600,
            "use1200bpsTouch" => true
          }
        },
        %{
          "environment" => "sparkfun_promicro16",
          "displayName" => "SparkFun Pro Micro",
          "firmwareFile" => "trenino-sparkfun-promicro.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "avr109",
            "mcu" => "atmega32u4",
            "speed" => 57_600,
            "use1200bpsTouch" => true
          }
        },
        %{
          "environment" => "megaatmega2560",
          "displayName" => "Arduino Mega 2560",
          "firmwareFile" => "trenino-mega2560.firmware.hex",
          "uploadConfig" => %{
            "protocol" => "wiring",
            "mcu" => "atmega2560",
            "speed" => 115_200
          }
        }
      ]
    }

    DeviceRegistry.reload_from_manifest(manifest, 0)
  end
end
