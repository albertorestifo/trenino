[CmdletBinding()]
param(
    [string]$DestinationDirectory = "tauri/src-tauri/resources"
)

$ErrorActionPreference = 'Stop'
$version = '2.2.2.0'
$releaseBase = "https://github.com/BrunnerInnovation/vJoy/releases/download/v$version"
$installerSha256 = 'ef569a3105cd301b89580f18f60c66b339e95296acf2c0dfcaf4b4bbf8ab68fe'
$sdkSha256 = '0e796b185b66819d5fbeae645f3f038ecbfbbde837d3d3f06cba82ae1db07c67'
$licenseSha256 = '7f0ed151caab68bbfd1a37727c8fe75c94be45aff98a88d63bc7e46e3fb0c5e1'
$resources = [System.IO.Path]::GetFullPath($DestinationDirectory)
$downloader = Join-Path $PSScriptRoot 'download-vjoy.ps1'
$stage = Join-Path ([System.IO.Path]::GetTempPath()) ("trenino-vjoy-{0}" -f [guid]::NewGuid())

[System.IO.Directory]::CreateDirectory($resources) | Out-Null
[System.IO.Directory]::CreateDirectory($stage) | Out-Null

try {
    $installer = Join-Path $resources 'vJoySetup.exe'
    $sdk = Join-Path $resources 'SDK.zip'
    $license = Join-Path $resources 'vJoy-LICENSE.txt'

    & $downloader -Version $version -Url "$releaseBase/vJoySetup_v2.2.2.0_Win10_Win11.exe" -ExpectedSha256 $installerSha256 -Destination $installer
    & $downloader -Version "$version-sdk" -Url "$releaseBase/SDK.zip" -ExpectedSha256 $sdkSha256 -Destination $sdk
    & $downloader -Version "$version-license" -Url "https://raw.githubusercontent.com/BrunnerInnovation/vJoy/v$version/LICENSE.txt" -ExpectedSha256 $licenseSha256 -Destination $license

    $signature = Get-AuthenticodeSignature -LiteralPath $installer
    if ($signature.Status -ne 'Valid') {
        throw "vJoy installer Authenticode status is $($signature.Status)."
    }
    if ($signature.SignerCertificate.Subject -notmatch 'BRUNNER') {
        throw "Unexpected vJoy signer: $($signature.SignerCertificate.Subject)"
    }

    $sdkStage = Join-Path $stage 'sdk'
    [System.IO.Directory]::CreateDirectory($sdkStage) | Out-Null
    & 7z x -y "-o$sdkStage" $sdk | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "7-Zip failed to extract the vJoy SDK." }

    $interface = Join-Path $sdkStage 'SDK/lib/x64/vJoyInterface.dll'
    if (-not (Test-Path -LiteralPath $interface -PathType Leaf)) {
        throw "vJoyInterface.dll was not found in the verified SDK archive."
    }
    Copy-Item -LiteralPath $interface -Destination (Join-Path $resources 'vJoyInterface.dll')

    $installerStage = Join-Path $stage 'installer'
    [System.IO.Directory]::CreateDirectory($installerStage) | Out-Null
    & innoextract --silent --extract --output-dir $installerStage $installer
    if ($LASTEXITCODE -ne 0) { throw "innoextract failed to extract the vJoy installer." }

    $config = Join-Path $installerStage 'app/x64/vJoyConfig.exe'
    if (-not (Test-Path -LiteralPath $config -PathType Leaf)) {
        throw "vJoyConfig.exe was not found in the verified installer."
    }
    Copy-Item -LiteralPath $config -Destination (Join-Path $resources 'vJoyConfig.exe')
    Remove-Item -LiteralPath $sdk

    Write-Host "Staged verified vJoy $version resources in '$resources'."
}
finally {
    if (Test-Path -LiteralPath $stage) {
        Remove-Item -LiteralPath $stage -Recurse -Force
    }
}
