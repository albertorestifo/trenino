# Storage migration fixtures

These SQL dumps are produced from disposable databases migrated by Ecto. The v0.7.4 fixture is built from all migration files and the `mix.lock` extracted from Git tag `v0.7.4` (36 Ecto migrations through 20260503114723). `generate_v074_pinned.ps1` creates a minimal isolated Mix project, uses only the tagged adapter dependency and its tagged locked transitive dependencies, and exports the historical fixture and schema fingerprint. The selected versions are Ecto 3.13.5, Ecto SQL 3.13.5, ecto_sqlite3 0.22.0, exqlite 0.33.1, DBConnection 2.9.0, and Decimal 2.3.0. The current fixture runs all 41 migration modules from the selected worktree. The `sqlite_master` definitions from those databases are exported as schema fingerprints under `src/storage/schema/`.

Both schemas receive representative device, calibrated input, train, lever, notch, binding, script, and setting records. The current fixture also includes one I2C module, display binding, and existing virtual-joystick configuration/mapping. IDs are fixed for tests. No application database is read by the generator.

On Windows, regenerate from a checkout whose Ecto dependencies have already been fetched and compiled:

```powershell
.crates\trenino-runtime\tests\fixtures\storage\generate.ps1 `
  -EctoCheckout C:\path\to\ecto-checkout `
  -RustWorktree C:\path\to\rust-worktree `
  -PythonExe C:\path\to\python.exe
```

The script extracts the actual v0.7.4 migration directory using `git archive`, migrates two uniquely named databases below `%TEMP%`, inserts deterministic rows, and exports both SQL fixtures and schema fingerprints. The Elixir script converts Windows separators to `/` before `Ecto.Migrator`, since `Path.wildcard` otherwise finds no migration files.

Regenerate the historical baseline with its actual tag lock and an isolated temp dependency/build directory:

```powershell
.\crates\trenino-runtime\tests\fixtures\storage\generate_v074_pinned.ps1 `
  -RustWorktree C:\path\to\rust-worktree `
  -PythonExe C:\path\to\python.exe
```

This exports only the v0.7.4 side; it leaves the current fixture and schema files alone. The fixture generator normalizes migration timestamps so SQL output is reproducible. The historical DDL export is byte-for-byte the same as the existing `ecto-0.7.4.sql` fingerprint.
