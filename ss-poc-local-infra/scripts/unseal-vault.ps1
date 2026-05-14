$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_common.ps1"

$vaultInitFile = if ($env:VAULT_INIT_FILE) { $env:VAULT_INIT_FILE } else { "vault/.vault-init.json" }

Invoke-Compose --profile secrets up -d vault

$statusJson = (& docker compose exec -T vault vault status -format=json 2>$null) -join "`n"

$status = $null
if (-not [string]::IsNullOrWhiteSpace($statusJson)) {
    $status = $statusJson | ConvertFrom-Json
}

if ($status -and $status.initialized -eq $false) {
    $initJson = Get-ComposeOutput exec -T vault vault operator init -key-shares=1 -key-threshold=1 -format=json
    Set-Content -Path $vaultInitFile -Value $initJson -Encoding UTF8
    $statusJson = (& docker compose exec -T vault vault status -format=json 2>$null) -join "`n"
    $status = $statusJson | ConvertFrom-Json
    Write-Host "Initialized Vault and wrote local init material to $vaultInitFile."
}

if (-not (Test-Path $vaultInitFile)) {
    [Console]::Error.WriteLine("Vault is initialized, but $vaultInitFile is missing. Unseal manually with your saved key.")
    exit 1
}

if ($status -and $status.sealed -eq $false) {
    Write-Host "Vault is already unsealed."
} else {
    $init = (Get-Content $vaultInitFile -Raw) | ConvertFrom-Json
    $unsealKey = $init.unseal_keys_b64[0]
    Invoke-Compose exec -T vault vault operator unseal $unsealKey
    Write-Host "Vault unsealed."
}

Invoke-Compose exec -T vault vault status
