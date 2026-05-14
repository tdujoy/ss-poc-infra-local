$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_common.ps1"

$profiles = $Script:ComposeProfiles
Invoke-Compose @profiles up -d
& "$PSScriptRoot/setup-garage.ps1"
& "$PSScriptRoot/unseal-vault.ps1"
& "$PSScriptRoot/health.ps1"
