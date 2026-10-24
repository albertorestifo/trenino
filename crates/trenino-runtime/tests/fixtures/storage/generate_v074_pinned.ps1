param(
  [Parameter(Mandatory = $true)][string]$RustWorktree,
  [Parameter(Mandatory = $true)][string]$PythonExe
)

$ErrorActionPreference = 'Stop'
$RustWorktree = (Resolve-Path -LiteralPath $RustWorktree).Path
$FixtureDir = $PSScriptRoot
$MixExe = (Get-Command mix).Source
$ErlangBin = Split-Path -Parent (Get-Command erl).Source
$TempRoot = Join-Path $env:TEMP ("trenino-v074-pinned-" + [guid]::NewGuid().ToString('N'))
$TagRoot = Join-Path $TempRoot 'tag-v074'
$V074Db = Join-Path $TempRoot 'ecto-v074.db'
$DepsPath = Join-Path $TempRoot 'deps'
$BuildPath = Join-Path $TempRoot 'build'

New-Item -ItemType Directory -Path $TempRoot, $TagRoot, $DepsPath, $BuildPath | Out-Null
$Archive = Join-Path $TempRoot 'v074-project.tar'
git -C $RustWorktree archive --format=tar --output=$Archive v0.7.4 mix.lock priv/repo/migrations
if ($LASTEXITCODE -ne 0) { throw 'Could not export the v0.7.4 lockfile and migration modules.' }
tar -xf $Archive -C $TagRoot
if ($LASTEXITCODE -ne 0) { throw 'Could not unpack the v0.7.4 project.' }

@'
defmodule StorageMigrationFixture.MixProject do
  use Mix.Project

  def project do
    [app: :storage_migration_fixture, version: "0.1.0", elixir: ">= 1.15.0", deps: [{:ecto_sqlite3, "== 0.22.0"}]]
  end

  def application, do: [extra_applications: [:logger]]
end
'@ | Set-Content -LiteralPath (Join-Path $TagRoot 'mix.exs') -Encoding utf8

$env:MIX_ENV = 'test'
$env:MIX_DEPS_PATH = $DepsPath
$env:MIX_BUILD_PATH = $BuildPath
$env:MIGRATION_FIXTURE_V074_DB = $V074Db
$env:MIGRATION_FIXTURE_V074_DIR = Join-Path $TagRoot 'priv/repo/migrations'
Push-Location $TagRoot
try {
  $env:PATH = "$ErlangBin;$env:PATH"
  & $MixExe deps.get
  if ($LASTEXITCODE -ne 0) { throw 'Could not fetch the v0.7.4 locked dependencies.' }
  & $MixExe deps | Select-String 'ecto|exqlite|db_connection|decimal'
  $MixScript = Join-Path $FixtureDir 'generate_v074_migrations.exs'
  & $MixExe run --no-start $MixScript
  if ($LASTEXITCODE -ne 0) { throw 'v0.7.4 pinned Ecto migration execution failed.' }
} finally {
  Pop-Location
}

$SchemaDir = Join-Path $RustWorktree 'crates/trenino-runtime/src/storage/schema'
& $PythonExe (Join-Path $FixtureDir 'generate_fixtures.py') `
  --v074-db $V074Db `
  --fixture-dir $FixtureDir `
  --schema-dir $SchemaDir
if ($LASTEXITCODE -ne 0) { throw 'Could not populate and export the v0.7.4 fixture.' }
Copy-Item -LiteralPath ([System.IO.Path]::ChangeExtension($V074Db, '.sql')) -Destination (Join-Path $FixtureDir 'ecto-0.7.4.sql') -Force
Write-Output "Pinned v0.7.4 fixture generated in disposable directory $TempRoot"
