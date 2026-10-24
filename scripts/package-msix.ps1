[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9.-]{3,50}$')][string]$IdentityName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Publisher,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PublisherDisplayName,
    [Parameter(Mandatory)][ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+\.0$')][string]$Version,
    [string]$DisplayName = 'Trenino',
    [string]$BuildDirectory = (Join-Path $PSScriptRoot '../tauri/src-tauri'),
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$MakeAppxPath,
    [switch]$LayoutOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Store identity values must come from Partner Center, never a generated certificate.
$parsedVersion = [version]$Version
if ($parsedVersion.Major -lt 1 -or @($Version.Split('.') | Where-Object { [long]$_ -gt 65535 }).Count) {
    throw 'Store versions require a nonzero major, components <= 65535, and revision 0.'
}
if ($Publisher -notmatch '^CN=') { throw 'Publisher must be the CN=... value from Partner Center.' }
$null = [Security.Cryptography.X509Certificates.X500DistinguishedName]::new($Publisher)
$build = (Resolve-Path -LiteralPath $BuildDirectory).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $output) { throw "Output directory already exists; choose a new directory: $output" }

# An explicit allowlist prevents driver installers, uninstallers, user data and
# development credentials from becoming part of the Store submission.
$files = [ordered]@{
    'target/release/trenino.exe' = 'trenino.exe'
    'binaries/trenino_backend-x86_64-pc-windows-msvc.exe' = 'trenino_backend.exe'
    'binaries/avrdude-x86_64-pc-windows-msvc.exe' = 'avrdude.exe'
    'binaries/keystroke-x86_64-pc-windows-msvc.exe' = 'keystroke.exe'
    'binaries/virtual_joystick-x86_64-pc-windows-msvc.exe' = 'virtual_joystick.exe'
    'binaries/avrdude.conf' = 'avrdude.conf'
    'resources/vJoyConfig.exe' = 'resources/vJoyConfig.exe'
    'resources/vJoyInstall.dll' = 'resources/vJoyInstall.dll'
    'resources/vJoyInterface.dll' = 'resources/vJoyInterface.dll'
    'resources/vJoy-LICENSE.txt' = 'resources/vJoy-LICENSE.txt'
    'resources/THIRD_PARTY_NOTICES.md' = 'resources/THIRD_PARTY_NOTICES.md'
    'icons/StoreLogo.png' = 'Assets/StoreLogo.png'
    'icons/Square44x44Logo.png' = 'Assets/Square44x44Logo.png'
    'icons/Square150x150Logo.png' = 'Assets/Square150x150Logo.png'
}
foreach ($source in $files.Keys) {
    if (-not (Test-Path -LiteralPath (Join-Path $build $source) -PathType Leaf)) {
        throw "Missing Store payload: $source. Build and stage all Windows resources first."
    }
}

if (-not $LayoutOnly) {
    if (-not $MakeAppxPath) {
        $sdkBin = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits/10/bin'
        $candidates = @(Get-ChildItem -LiteralPath $sdkBin -Directory | Where-Object Name -Match '^10\.0\.\d+\.\d+$' |
            Sort-Object { [version]$_.Name } -Descending |
            ForEach-Object { Join-Path $_.FullName 'x64/makeappx.exe' } |
            Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
        if (-not $candidates.Count) { throw 'Install the Windows SDK MSIX packaging tools (MakeAppx.exe).' }
        $MakeAppxPath = $candidates[0]
    }
    if (-not (Test-Path -LiteralPath $MakeAppxPath -PathType Leaf)) { throw 'MakeAppx.exe was not found.' }
}

$layout = Join-Path $output 'layout'
foreach ($entry in $files.GetEnumerator()) {
    $destination = Join-Path $layout $entry.Value
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
    Copy-Item -LiteralPath (Join-Path $build $entry.Key) -Destination $destination
}

$nameXml = [Security.SecurityElement]::Escape($IdentityName)
$publisherXml = [Security.SecurityElement]::Escape($Publisher)
$publisherDisplayXml = [Security.SecurityElement]::Escape($PublisherDisplayName)
$displayXml = [Security.SecurityElement]::Escape($DisplayName)
$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:uap10="http://schemas.microsoft.com/appx/manifest/uap/windows10/10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap uap10 rescap">
  <Identity Name="$nameXml" Publisher="$publisherXml" Version="$Version" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>$displayXml</DisplayName>
    <PublisherDisplayName>$publisherDisplayXml</PublisherDisplayName>
    <Description>Bridge physical controls and displays to Train Sim World.</Description>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Resources><Resource Language="en-US" /></Resources>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.19041.0" MaxVersionTested="10.0.26100.0" />
    <PackageDependency Name="Microsoft.VCLibs.140.00.UWPDesktop" MinVersion="14.0.30704.0"
      Publisher="CN=Microsoft Corporation, O=Microsoft Corporation, L=Redmond, S=Washington, C=US" />
  </Dependencies>
  <Applications>
    <Application Id="Trenino" Executable="trenino.exe" uap10:RuntimeBehavior="packagedClassicApp" uap10:TrustLevel="mediumIL">
      <uap:VisualElements DisplayName="$displayXml" Description="Bridge hardware to Train Sim World"
        Square150x150Logo="Assets\Square150x150Logo.png" Square44x44Logo="Assets\Square44x44Logo.png"
        BackgroundColor="transparent" />
    </Application>
  </Applications>
  <Capabilities><rescap:Capability Name="runFullTrust" /></Capabilities>
</Package>
"@
[IO.File]::WriteAllText((Join-Path $layout 'AppxManifest.xml'), $manifest, [Text.UTF8Encoding]::new($false))
if ($LayoutOnly) { Write-Output $layout; return }

$package = Join-Path $output "Trenino-$Version-x64.msix"
& $MakeAppxPath pack /d $layout /p $package /h SHA256
if ($LASTEXITCODE -ne 0) { throw "MakeAppx failed with exit code $LASTEXITCODE." }
Write-Output "Unsigned Store submission package: $package"
Write-Output 'Microsoft signs accepted Store submissions. This file is not a signed direct-download release.'
