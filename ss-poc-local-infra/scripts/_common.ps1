$ErrorActionPreference = "Stop"

$Script:RootDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $Script:RootDir

$envFile = Join-Path $Script:RootDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line.Length -gt 0 -and -not $line.StartsWith("#")) {
            $separatorIndex = $line.IndexOf("=")
            if ($separatorIndex -gt 0) {
                $name = $line.Substring(0, $separatorIndex).Trim()
                $value = $line.Substring($separatorIndex + 1).Trim()
                if ($value.Length -ge 2) {
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                }

                Set-Item -Path "Env:$name" -Value $value
            }
        }
    }
}

$Script:ComposeProfiles = @(
    "--profile", "edge",
    "--profile", "core",
    "--profile", "broker",
    "--profile", "mail",
    "--profile", "obs",
    "--profile", "secrets",
    "--profile", "tools"
)

function Invoke-Compose {
    & docker compose @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Docker {
    & docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker failed with exit code $LASTEXITCODE."
    }
}

function Get-ComposeOutput {
    $output = & docker compose @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose failed with exit code $LASTEXITCODE."
    }

    return $output
}

function Get-DockerOutput {
    $output = & docker @args
    if ($LASTEXITCODE -ne 0) {
        throw "docker failed with exit code $LASTEXITCODE."
    }

    return $output
}

function Wait-ForHealthy {
    param(
        [Parameter(Mandatory = $true)]
        [string] $Service,

        [int] $Attempts = 60
    )

    for ($i = 1; $i -le $Attempts; $i++) {
        $containerId = (& docker compose ps -q $Service 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($containerId)) {
            $health = (& docker inspect $containerId --format "{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}" 2>$null)
            if ($LASTEXITCODE -eq 0 -and ($health -eq "healthy" -or $health -eq "running")) {
                return
            }
        }

        Start-Sleep -Seconds 2
    }

    [Console]::Error.WriteLine("Timed out waiting for $Service to become healthy.")
    & docker compose ps $Service 1>&2
    throw "Timed out waiting for $Service to become healthy."
}
