[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Fa-f0-9]{64}$')]
    [string]$ExpectedSha256,

    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$TargetTriple
)

$ErrorActionPreference = 'Stop'
$url = "https://github.com/avrdudes/avrdude/releases/download/v$Version/avrdude-v$Version-windows-x64.zip"
$destination = [System.IO.Path]::GetFullPath($DestinationDirectory)
[System.IO.Directory]::CreateDirectory($destination) | Out-Null

$temporaryRoot = [System.IO.Path]::GetTempPath()
$archive = Join-Path $temporaryRoot ("avrdude-v{0}-{1}.zip" -f $Version, [guid]::NewGuid())
$staging = Join-Path $temporaryRoot ("avrdude-v{0}-{1}" -f $Version, [guid]::NewGuid())

try {
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()

    if ($actual -ne $ExpectedSha256.ToLowerInvariant()) {
        throw "avrdude $Version checksum mismatch: expected $ExpectedSha256, got $actual"
    }

    [System.IO.Directory]::CreateDirectory($staging) | Out-Null
    Expand-Archive -LiteralPath $archive -DestinationPath $staging

    $executable = Join-Path $staging 'avrdude.exe'
    $configuration = Join-Path $staging 'avrdude.conf'
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Verified avrdude archive does not contain avrdude.exe"
    }
    if (-not (Test-Path -LiteralPath $configuration -PathType Leaf)) {
        throw "Verified avrdude archive does not contain avrdude.conf"
    }

    Copy-Item -LiteralPath $executable -Destination (Join-Path $destination "avrdude-$TargetTriple.exe") -Force
    Copy-Item -LiteralPath $configuration -Destination (Join-Path $destination 'avrdude.conf') -Force
    Write-Host "Staged verified avrdude $Version for $TargetTriple"
}
finally {
    if (Test-Path -LiteralPath $archive -PathType Leaf) {
        Remove-Item -LiteralPath $archive -Force
    }
    if (Test-Path -LiteralPath $staging -PathType Container) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}
