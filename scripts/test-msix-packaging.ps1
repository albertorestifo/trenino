[CmdletBinding()]
param([switch]$Pack)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('trenino-msix-test-' + [guid]::NewGuid())
$build = Join-Path $root 'build with spaces'
$null = New-Item -ItemType Directory -Path $build -Force
$required = @(
    'target/release/trenino.exe',
    'binaries/trenino_backend-x86_64-pc-windows-msvc.exe',
    'binaries/avrdude-x86_64-pc-windows-msvc.exe',
    'binaries/keystroke-x86_64-pc-windows-msvc.exe',
    'binaries/virtual_joystick-x86_64-pc-windows-msvc.exe',
    'binaries/avrdude.conf', 'resources/vJoyConfig.exe',
    'resources/vJoyInterface.dll', 'resources/vJoy-LICENSE.txt', 'resources/THIRD_PARTY_NOTICES.md'
)
foreach ($file in $required + @('resources/vJoySetup.exe', 'resources/vc_redist.x64.exe', 'uninstall.exe', 'private.pfx')) {
    $path = Join-Path $build $file
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
    [IO.File]::WriteAllText($path, 'Fixture only; not a runnable application.')
}
$null = New-Item -ItemType Directory -Path (Join-Path $build 'icons')
foreach ($icon in @('StoreLogo.png', 'Square44x44Logo.png', 'Square150x150Logo.png')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "../tauri/src-tauri/icons/$icon") -Destination (Join-Path $build 'icons')
}
$parameters = @{
    IdentityName = 'Trenino.PackagingTest'
    Publisher = 'CN=Trenino Packaging Test'
    PublisherDisplayName = 'Test & Publisher'
    DisplayName = 'Trenino & Test'
    Version = '1.8.0.0'
    BuildDirectory = $build
    OutputDirectory = (Join-Path $root 'output')
    LayoutOnly = $true
}
function Assert-Throws([scriptblock]$Action, [string]$Expected) {
    try { & $Action; throw "Expected failure containing: $Expected" }
    catch { if ($_.Exception.Message -notlike "*$Expected*" -or $_.Exception.Message -like 'Expected failure*') { throw } }
}
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'vJoyInstall.dll'
if (Test-Path -LiteralPath $parameters.OutputDirectory) { throw 'Missing dependency left a partial output.' }
[IO.File]::WriteAllText((Join-Path $build 'resources/vJoyInstall.dll'), 'Fixture dependency.')
& "$PSScriptRoot/package-msix.ps1" @parameters | Out-Null
$layout = Join-Path $parameters.OutputDirectory 'layout'
if (-not (Test-Path -LiteralPath (Join-Path $layout 'avrdude.conf') -PathType Leaf)) {
    throw 'Firmware flashing requires avrdude.conf beside avrdude.exe (APP_PATH).'
}
[xml]$manifest = Get-Content -Raw -LiteralPath (Join-Path $layout 'AppxManifest.xml')
if ($manifest.Package.Properties.PublisherDisplayName -ne 'Test & Publisher') { throw 'XML escaping failed.' }
if ($manifest.Package.Identity.Version -ne '1.8.0.0') { throw 'Wrong package version.' }
if ($manifest.Package.Identity.ProcessorArchitecture -ne 'x64') { throw 'Wrong architecture.' }
foreach ($excluded in @('vJoySetup.exe', 'vc_redist.x64.exe', 'uninstall.exe', 'private.pfx')) {
    if (Get-ChildItem -LiteralPath $layout -Recurse -File | Where-Object Name -EQ $excluded) { throw "Leaked $excluded into MSIX." }
}
foreach ($included in @('trenino.exe', 'trenino_backend.exe', 'avrdude.exe', 'keystroke.exe', 'virtual_joystick.exe', 'resources/vJoyInstall.dll')) {
    if (-not (Test-Path -LiteralPath (Join-Path $layout $included))) { throw "Missing payload $included." }
}
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'already exists'
$parameters.OutputDirectory = Join-Path $root 'invalid'
$parameters.Version = '0.8.0.0'
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'nonzero major'
$parameters.Version = '1.65536.0.0'
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'components <= 65535'
$parameters.Version = '1.8.0.1'
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'pattern'
$parameters.Version = '1.8.0.0'
$parameters.Publisher = 'not-a-publisher'
Assert-Throws { & "$PSScriptRoot/package-msix.ps1" @parameters } 'CN='
$parameters.Publisher = 'CN=Trenino Packaging Test'
if ($Pack) {
    $parameters.OutputDirectory = Join-Path $root 'packed'
    $parameters.LayoutOnly = $false
    & "$PSScriptRoot/package-msix.ps1" @parameters
    $package = Join-Path $parameters.OutputDirectory 'Trenino-1.8.0.0-x64.msix'
    if (-not (Test-Path -LiteralPath $package -PathType Leaf)) { throw 'MakeAppx did not produce a package.' }
}
Write-Output "PASS: MSIX payload, missing dependency, exclusion, XML, overwrite and version checks. Fixtures: $root"
