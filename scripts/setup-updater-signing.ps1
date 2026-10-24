[CmdletBinding()]
param(
    [string]$Repository = 'albertorestifo/trenino',
    [string]$KeyDirectory = (Join-Path $env:LOCALAPPDATA 'TreninoSigningSetup/tauri-updater')
)
$ErrorActionPreference = 'Stop'
$null = New-Item -ItemType Directory -Path $KeyDirectory -Force
$account = [Security.Principal.WindowsIdentity]::GetCurrent().Name
& icacls $KeyDirectory /inheritance:r /grant:r "${account}:(OI)(CI)F" 'SYSTEM:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Could not protect signing directory.' }
$key = Join-Path $KeyDirectory 'trenino-release.key'
$passwordFile = Join-Path $KeyDirectory 'trenino-release-password.xml'
$cli = Join-Path $PSScriptRoot '../tauri/node_modules/@tauri-apps/cli/tauri.js'
function Assert-MatchingPublicKey {
    $config = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../tauri/src-tauri/tauri.conf.json') | ConvertFrom-Json
    $public = (Get-Content -Raw -LiteralPath "$key.pub").Trim()
    if ($public -cne $config.plugins.updater.pubkey) {
        throw 'Signing key does not match the embedded updater public key. GitHub secrets unchanged. Recover the original key; do not rotate keys for installed clients. For a first unpublished release only, review and update tauri.conf.json before rerunning.'
    }
}
if (-not (Test-Path -LiteralPath $key)) {
    if (Test-Path -LiteralPath $passwordFile) { throw 'Existing password without key: inspect before proceeding.' }
    $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $password | ConvertTo-SecureString -AsPlainText -Force | Export-Clixml -LiteralPath $passwordFile
    & node $cli signer generate --ci --password $password --write-keys $key *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Key generation failed.' }
    Assert-MatchingPublicKey
} else {
    Assert-MatchingPublicKey
    $secure = Import-Clixml -LiteralPath $passwordFile
    $password = [Net.NetworkCredential]::new('', $secure).Password
}
try {
    # Validate the key before changing GitHub secrets. The fixture is public data.
    $fixture = Join-Path $KeyDirectory 'verification-fixture.json'
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../tauri/src-tauri/tauri.conf.json') -Destination $fixture
    & node $cli signer sign --private-key-path $key --password $password $fixture *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Key could not sign the verification fixture; GitHub secrets unchanged.' }
    # A .pub file can be stale: verify possession of the actual embedded key.
    $config = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot '../tauri/src-tauri/tauri.conf.json') | ConvertFrom-Json
    $verifier = Join-Path $PSScriptRoot 'updater-signature-verifier/Cargo.toml'
    & cargo run --quiet --locked --manifest-path $verifier -- $config.plugins.updater.pubkey $fixture "$fixture.sig"
    if ($LASTEXITCODE -ne 0) { throw 'Fixture signature does not verify against the embedded updater public key. GitHub secrets unchanged.' }
    Get-Content -Raw -LiteralPath $key | & gh secret set TAURI_SIGNING_PRIVATE_KEY --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw 'Private key upload failed.' }
    $password | & gh secret set TAURI_SIGNING_PRIVATE_KEY_PASSWORD --repo $Repository
    if ($LASTEXITCODE -ne 0) { throw 'Password upload failed.' }
    Write-Output "Signing secrets configured. Protected backup: $KeyDirectory"
    Get-Content -LiteralPath "$key.pub"
} finally {
    $password = $null
}
