param(
    [int] $Attempts = 60
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_common.ps1"

for ($i = 1; $i -le $Attempts; $i++) {
    $status = Get-ComposeOutput ps --format "{{.Service}} {{.Status}}"
    $unhealthy = $status | Where-Object { $_ -match "health: starting|unhealthy|starting|exited" }

    Invoke-Compose ps --format "table {{.Service}}\t{{.Status}}"
    if (-not $unhealthy) {
        exit 0
    }

    Start-Sleep -Seconds 2
}

[Console]::Error.WriteLine("One or more services did not become healthy:")
& docker compose ps --format "table {{.Service}}\t{{.Status}}" 1>&2
exit 1
