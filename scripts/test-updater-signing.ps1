$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('trenino-key-mismatch-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $root
# No real private material: mismatch must be rejected before decryption or upload.
[IO.File]::WriteAllText((Join-Path $root 'trenino-release.key'), 'not a private key')
[IO.File]::WriteAllText((Join-Path $root 'trenino-release.key.pub'), 'different-public-key')
try {
    & "$PSScriptRoot/setup-updater-signing.ps1" -KeyDirectory $root -Repository 'invalid/never-upload'
    throw 'Expected key mismatch rejection.'
} catch {
    if ($_.Exception.Message -notlike '*does not match the embedded updater public key*') { throw }
}
Write-Output 'PASS: mismatched signing key rejected before decryption or GitHub upload.'
