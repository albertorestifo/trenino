# Ensure the application is started before setting up test infrastructure
{:ok, _} = Application.ensure_all_started(:trenino)

Mimic.copy(Req, type_check: true)
Mimic.copy(Trenino.Train.Identifier)
Mimic.copy(Trenino.Simulator.Client)
Mimic.copy(Trenino.Simulator)
Mimic.copy(Trenino.Simulator.Connection)
Mimic.copy(Trenino.Settings)
Mimic.copy(Trenino.Settings.Simulator)
Mimic.copy(Trenino.Simulator.ControlDetectionSession)
Mimic.copy(Trenino.AppVersion)
Mimic.copy(Circuits.UART, type_check: true)
Mimic.copy(Trenino.Serial.Discovery, type_check: true)
Mimic.copy(Trenino.Firmware.Avrdude)
Mimic.copy(Trenino.Firmware.AvrdudeRunner)
Mimic.copy(Trenino.Serial.Connection)

# Build a pre-migrated template SQLite file once. Async DataCase tests
# copy it to get an isolated per-test DB without paying the migration cost.
template_path = Path.expand("../tmp/test_template.db", __DIR__)
File.mkdir_p!(Path.dirname(template_path))
File.rm(template_path)

{:ok, template_pid} =
  Trenino.Repo.start_link(
    name: nil,
    database: template_path,
    pool: DBConnection.ConnectionPool,
    pool_size: 1,
    journal_mode: :wal,
    synchronous: :normal
  )

Trenino.Repo.put_dynamic_repo(template_pid)

migrations_path = Application.app_dir(:trenino, "priv/repo/migrations")

Ecto.Migrator.run(Trenino.Repo, migrations_path, :up,
  all: true,
  dynamic_repo: template_pid
)

Trenino.Repo.put_dynamic_repo(Trenino.Repo)
:ok = GenServer.stop(template_pid)

# Make the path available at runtime to DataCase
Application.put_env(:trenino, :test_template_db_path, template_path)

ExUnit.start(capture_log: true)
ExUnit.configure(exclude: [:skip_without_avrdude])
Ecto.Adapters.SQL.Sandbox.mode(Trenino.Repo, :manual)
