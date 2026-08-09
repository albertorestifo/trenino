[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [uri]$Url,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $true)]
    [string]$Destination,

    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$expected = $ExpectedSha256.ToLowerInvariant()
$destinationPath = [System.IO.Path]::GetFullPath($Destination)

function Test-ExpectedHash([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    $actual = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
    return $actual -eq $expected
}

if ($VerifyOnly) {
    if (-not (Test-ExpectedHash $destinationPath)) {
        throw "vJoy $Version checksum verification failed for '$destinationPath'."
    }

    Write-Host "Verified vJoy $Version artifact: $destinationPath"
    exit 0
}

if (Test-ExpectedHash $destinationPath) {
    Write-Host "Using existing verified vJoy $Version artifact: $destinationPath"
    exit 0
}

$destinationDirectory = Split-Path -Parent $destinationPath
if (-not $destinationDirectory) {
    $destinationDirectory = (Get-Location).Path
}
[System.IO.Directory]::CreateDirectory($destinationDirectory) | Out-Null

# The temporary file is a sibling of the destination so the final rename is on
# one filesystem. An invalid download never replaces an existing artifact.
$temporaryPath = Join-Path $destinationDirectory (".{0}.{1}.download" -f ([System.IO.Path]::GetFileName($destinationPath)), [guid]::NewGuid())

try {
    Invoke-WebRequest -Uri $Url -OutFile $temporaryPath -UseBasicParsing

    if (-not (Test-ExpectedHash $temporaryPath)) {
        throw "vJoy $Version download checksum mismatch for '$Url'."
    }

    Move-Item -LiteralPath $temporaryPath -Destination $destinationPath -Force
    Write-Host "Downloaded and verified vJoy $Version artifact: $destinationPath"
}
finally {
    if (Test-Path -LiteralPath $temporaryPath) {
        Remove-Item -LiteralPath $temporaryPath -Force
    }
}
