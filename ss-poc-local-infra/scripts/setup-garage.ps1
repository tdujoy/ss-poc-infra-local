$ErrorActionPreference = "Stop"

. "$PSScriptRoot/_common.ps1"

$garageBucket = if ($env:GARAGE_BUCKET) { $env:GARAGE_BUCKET } else { "st-poc-local" }
$garageKeyName = if ($env:GARAGE_KEY_NAME) { $env:GARAGE_KEY_NAME } else { "st-poc-local-app" }
$garageNodeZone = if ($env:GARAGE_NODE_ZONE) { $env:GARAGE_NODE_ZONE } else { "local" }
$garageNodeCapacity = if ($env:GARAGE_NODE_CAPACITY) { $env:GARAGE_NODE_CAPACITY } else { "1GB" }
$keyFile = Join-Path "garage" ".garage-$garageKeyName.txt"

Invoke-Compose --profile core up -d garage
Wait-ForHealthy -Service "garage" -Attempts 60

$status = Get-ComposeOutput exec -T garage /garage status
$nodeIdLine = $status | Where-Object { $_ -match "^[0-9a-f][0-9a-f]" } | Select-Object -First 1
$nodeId = if ($nodeIdLine) { ($nodeIdLine -split "\s+")[0] } else { $null }

if ([string]::IsNullOrWhiteSpace($nodeId)) {
    [Console]::Error.WriteLine("Could not find a healthy Garage node ID.")
    & docker compose exec -T garage /garage status 1>&2
    exit 1
}

$layout = Get-ComposeOutput exec -T garage /garage layout show
if ($layout -match [regex]::Escape($nodeId)) {
    Write-Host "Garage node $nodeId is already assigned in the layout."
} else {
    $versionLine = $layout | Where-Object { $_ -match "Current cluster layout version:" } | Select-Object -First 1
    if (-not $versionLine -or $versionLine -notmatch "Current cluster layout version:\s+(\d+)") {
        throw "Could not determine Garage layout version."
    }

    $nextVersion = [int]$Matches[1] + 1
    Invoke-Compose exec -T garage /garage layout assign $nodeId -z $garageNodeZone -c $garageNodeCapacity
    Invoke-Compose exec -T garage /garage layout apply --version $nextVersion
}

& docker compose exec -T garage /garage bucket info $garageBucket *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Garage bucket $garageBucket already exists."
} else {
    Invoke-Compose exec -T garage /garage bucket create $garageBucket
}

& docker compose exec -T garage /garage key info $garageKeyName *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Garage key $garageKeyName already exists."
    if (-not (Test-Path $keyFile)) {
        Write-Warning "$keyFile is missing; Garage cannot show an existing secret key again."
    }
} else {
    $keyMaterial = Get-ComposeOutput exec -T garage /garage key create $garageKeyName
    Set-Content -Path $keyFile -Value $keyMaterial -Encoding UTF8
    Write-Host "Wrote Garage key material to $keyFile."
}

Invoke-Compose exec -T garage /garage bucket allow $garageBucket --key $garageKeyName --read --write
Invoke-Compose exec -T garage /garage bucket info $garageBucket
