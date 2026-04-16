$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$logPaths = @(
    (Join-Path $repoRoot '.logs\dhcp1'),
    (Join-Path $repoRoot '.logs\dhcp2')
)

Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path $logPaths | Out-Null

    docker compose build --no-cache
    docker compose up -d --force-recreate
}
finally {
    Pop-Location
}
