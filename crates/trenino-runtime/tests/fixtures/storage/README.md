# Storage migration fixtures

These SQL dumps are produced from disposable databases migrated by Ecto. The v0.7.4 fixture is built from all migration files extracted from Git tag `v0.7.4` (36 Ecto migrations through 20260503114723). The current fixture runs all 41 migration modules from the selected worktree. The `sqlite_master` definitions from those same databases are exported as schema fingerprints under `src/storage/schema/`.

Both schemas receive representative device, calibrated input, train, lever, notch, binding, script, and setting records. The current fixture also includes one I2C module, display binding, and existing virtual-joystick configuration/mapping. IDs are fixed for tests. No application database is read by the generator.

On Windows, regenerate from a checkout whose Ecto dependencies have already been fetched and compiled:

```powershell
.crates\trenino-runtime\tests\fixtures\storage\generate.ps1 `
  -EctoCheckout C:\path\to\ecto-checkout `
  -RustWorktree C:\path\to\rust-worktree `
  -PythonExe C:\path\to\python.exe
```

The script extracts the actual v0.7.4 migration directory using `git archive`, migrates two uniquely named databases below `%TEMP%`, inserts deterministic rows, and exports both SQL fixtures and schema fingerprints. The Elixir script converts Windows separators to `/` before `Ecto.Migrator`, since `Path.wildcard` otherwise finds no migration files.
