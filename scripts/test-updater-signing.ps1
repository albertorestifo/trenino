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

# A stale .pub file must not hide a different valid private key. Only the
# external upload boundary is replaced; key generation and signing are real.
$cli = Join-Path $PSScriptRoot '../tauri/node_modules/@tauri-apps/cli/tauri.js'
$key = Join-Path $root 'different.key'
$password = 'throwaway-test-password'
& node $cli signer generate --ci --password $password --write-keys $key *> $null
if ($LASTEXITCODE -ne 0) { throw 'Could not generate throwaway test key.' }
$testPublic = (Get-Content -Raw -LiteralPath "$key.pub").Trim()
Copy-Item -LiteralPath $key -Destination (Join-Path $root 'trenino-release.key')
$config = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../tauri/src-tauri/tauri.conf.json') | ConvertFrom-Json
[IO.File]::WriteAllText((Join-Path $root 'trenino-release.key.pub'), $config.plugins.updater.pubkey)
$password | ConvertTo-SecureString -AsPlainText -Force | Export-Clixml -LiteralPath (Join-Path $root 'trenino-release-password.xml')
function gh { throw 'Unexpected secret upload: private key was not verified.' }
try {
    & "$PSScriptRoot/setup-updater-signing.ps1" -KeyDirectory $root -Repository 'invalid/never-upload'
    throw 'Expected cryptographic key mismatch rejection.'
} catch {
    if ($_.Exception.Message -notlike '*Fixture signature does not verify against the embedded updater public key*') { throw }
}
Write-Output 'PASS: different private key with matching public file rejected before GitHub upload.'

$verifier = Join-Path $PSScriptRoot 'updater-signature-verifier/Cargo.toml'
$fixture = Join-Path $root 'verification-fixture.json'
& cargo run --quiet --locked --manifest-path $verifier -- $testPublic $fixture "$fixture.sig"
if ($LASTEXITCODE -ne 0) { throw 'Verifier rejected a valid Tauri signature.' }
Write-Output 'PASS: valid Tauri fixture signature accepted.'

[IO.File]::AppendAllText($fixture, 'tampered')
& cargo run --quiet --locked --manifest-path $verifier -- $testPublic $fixture "$fixture.sig"
if ($LASTEXITCODE -eq 0) { throw 'Verifier accepted a tampered payload.' }
Write-Output 'PASS: tampered payload rejected.'
# Expected verifier rejection must not make the successful test script fail CI.
$global:LASTEXITCODE = 0
