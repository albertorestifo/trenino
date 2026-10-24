param(
  [Parameter(Mandatory = $true)][string]$EctoCheckout,
  [Parameter(Mandatory = $true)][string]$RustWorktree,
  [Parameter(Mandatory = $true)][string]$PythonExe,
  [string]$DepsPath = (Join-Path $EctoCheckout 'deps'),
  [string]$BuildPath = (Join-Path $EctoCheckout '_build/test')
)

$ErrorActionPreference = 'Stop'
$EctoCheckout = (Resolve-Path -LiteralPath $EctoCheckout).Path
$RustWorktree = (Resolve-Path -LiteralPath $RustWorktree).Path
$DepsPath = (Resolve-Path -LiteralPath $DepsPath).Path
$BuildPath = (Resolve-Path -LiteralPath $BuildPath).Path
$FixtureDir = $PSScriptRoot
$TempRoot = Join-Path $env:TEMP ("trenino-storage-fixtures-" + [guid]::NewGuid().ToString('N'))
$TagRoot = Join-Path $TempRoot 'tag-v074'
$V074Db = Join-Path $TempRoot 'ecto-v074.db'
$CurrentDb = Join-Path $TempRoot 'ecto-current.db'

New-Item -ItemType Directory -Path $TempRoot, $TagRoot | Out-Null
$Archive = Join-Path $TempRoot 'v074-migrations.tar'
git -C $RustWorktree archive --format=tar --output=$Archive v0.7.4 -- priv/repo/migrations
if ($LASTEXITCODE -ne 0) { throw 'Could not export the v0.7.4 tag migration directory.' }
tar -xf $Archive -C $TagRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not unpack the v0.7.4 migrations.' }

$env:MIX_ENV = 'test'
$env:MIX_DEPS_PATH = $DepsPath
$env:MIX_BUILD_PATH = $BuildPath
$env:MIGRATION_FIXTURE_V074_DB = $V074Db
$env:MIGRATION_FIXTURE_CURRENT_DB = $CurrentDb
$env:MIGRATION_FIXTURE_V074_DIR = Join-Path $TagRoot 'priv/repo/migrations'
$env:MIGRATION_FIXTURE_CURRENT_DIR = Join-Path $RustWorktree 'priv/repo/migrations'
$MixScript = Join-Path $FixtureDir 'generate_migration_fixtures.exs'
Push-Location $EctoCheckout
try {
  mix run --no-compile --no-deps-check --no-start $MixScript
  if ($LASTEXITCODE -ne 0) { throw 'Ecto migration execution failed.' }
} finally {
  Pop-Location
}

$SchemaDir = Join-Path $RustWorktree 'crates/trenino-runtime/src/storage/schema'
& $PythonExe (Join-Path $FixtureDir 'generate_fixtures.py') `
  --v074-db $V074Db `
  --current-db $CurrentDb `
  --fixture-dir $FixtureDir `
  --schema-dir $SchemaDir
if ($LASTEXITCODE -ne 0) { throw 'Fixture population and schema export failed.' }

$V074Sql = [System.IO.Path]::ChangeExtension($V074Db, '.sql')
$CurrentSql = [System.IO.Path]::ChangeExtension($CurrentDb, '.sql')
Copy-Item -LiteralPath $V074Sql -Destination (Join-Path $FixtureDir 'ecto-0.7.4.sql') -Force
Copy-Item -LiteralPath $CurrentSql -Destination (Join-Path $FixtureDir 'ecto-current.sql') -Force
Write-Output "Fixtures were generated from Ecto migrations in disposable directory $TempRoot"
