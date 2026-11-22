# Saves the current SimRail train's full bridge dump as a profile.
#
#   .\integrations\simrail\capture-profile.ps1            # file named after the vehicle in the game
#   .\integrations\simrail\capture-profile.ps1 -Name EN57  # explicit file name
#
# Requires SimRail running with the TreninoBridge mod and the player in a cab.
# The dump is saved verbatim: its raw control properties can contain keys that
# differ only in case, which Windows PowerShell's JSON parser cannot represent.
param(
    [string]$Name,
    [string]$BaseUrl = "http://127.0.0.1:31275"
)

$ErrorActionPreference = "Stop"

if (-not $Name) {
    $vehicle = Invoke-RestMethod -Uri "$BaseUrl/api/v1/vehicle" -TimeoutSec 10
    $Name = $vehicle.vehicle.name
    if (-not $Name) { $Name = $vehicle.vehicle.objectName }
}
$safe = ($Name -replace '[^A-Za-z0-9_.-]', '_')

$dir = Join-Path $PSScriptRoot "profiles"
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$path = Join-Path $dir "$safe.json"

Invoke-WebRequest -Uri "$BaseUrl/api/v1/dump" -TimeoutSec 30 -UseBasicParsing -OutFile $path
$size = [math]::Round((Get-Item $path).Length / 1KB)
Write-Host "Saved $path ($size KB)"
