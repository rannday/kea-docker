param(
    [switch]$Firewall
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$composeFiles = @('-f', 'docker-compose.yml')
if ($Firewall) {
    $composeFiles += @('-f', 'docker-compose.firewall.yml')
}
$logPaths = @(
    (Join-Path $repoRoot '.logs\dhcp1'),
    (Join-Path $repoRoot '.logs\dhcp2')
)

Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path $logPaths | Out-Null

    docker compose @composeFiles build --no-cache
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose build failed with exit code $LASTEXITCODE."
    }
    docker compose @composeFiles up -d --force-recreate
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose up failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
