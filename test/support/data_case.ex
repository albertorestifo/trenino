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

      use Mimic
    end
  end

  setup tags do
    if tags[:async] do
      Trenino.DataCase.setup_isolated_repo()
    else
      Trenino.DataCase.setup_sandbox(tags)
    end

    Trenino.DataCase.setup_forbidden_serial_stubs()
    :ok
  end

  @doc """
  Installs default Mimic stubs that forbid real serial / avrdude / discovery
  access. Tests that legitimately need to simulate one of these subsystems
  override the default with `Mimic.expect/3` or `Mimic.stub/3`.
  """
  def setup_forbidden_serial_stubs do
    Mimic.set_mimic_private()
    Mimic.stub_with(Circuits.UART, Trenino.Test.ForbiddenUART)
    Mimic.stub_with(Trenino.Firmware.Avrdude, Trenino.Test.ForbiddenAvrdude)
    Mimic.stub_with(Trenino.Firmware.AvrdudeRunner, Trenino.Test.ForbiddenAvrdudeRunner)
    Mimic.stub_with(Trenino.Serial.Discovery, Trenino.Test.ForbiddenSerialDiscovery)
    :ok
  end

  @doc """
  For async tests: copies the pre-migrated template SQLite file to a
  unique per-test path, starts a dynamic Trenino.Repo against it, and
  routes the test process's queries via put_dynamic_repo/1. On test
  exit, restores the default repo and removes the temp file.

  Each test gets its own SQLite file, eliminating writer-lock contention
  between async tests.
  """
  def setup_isolated_repo do
    template_path = Application.fetch_env!(:trenino, :test_template_db_path)
    test_id = :erlang.unique_integer([:positive])
    test_db_path = Path.join(Path.dirname(template_path), "isolated_test_#{test_id}.db")
    File.cp!(template_path, test_db_path)

    {:ok, repo_pid} =
      Trenino.Repo.start_link(
        name: nil,
        database: test_db_path,
        pool: DBConnection.ConnectionPool,
        pool_size: 1,
        journal_mode: :wal,
        synchronous: :normal,
        busy_timeout: 1_000
      )

    Trenino.Repo.put_dynamic_repo(repo_pid)

    ExUnit.Callbacks.on_exit(fn ->
      Trenino.Repo.put_dynamic_repo(Trenino.Repo)

      try do
        :ok = GenServer.stop(repo_pid)
      catch
        :exit, _ -> :ok
      end

      File.rm(test_db_path)
      File.rm(test_db_path <> "-wal")
      File.rm(test_db_path <> "-shm")
    end)

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
  Captures Logger output during the given function. Use to wrap calls
  in tests that intentionally exercise error/cleanup paths and would
  otherwise leak [warning]/[error] lines into the test output.

      silently(fn -> Connection.handle_decode_failure(garbage) end)
  """
  def silently(fun) when is_function(fun, 0) do
    ExUnit.CaptureLog.capture_log(fun)
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
            "requires1200bpsTouch" => true
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
            "requires1200bpsTouch" => true
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
            "requires1200bpsTouch" => true
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
