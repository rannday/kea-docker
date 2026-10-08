param(
    [switch]$Firewall
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$composeFiles = @('-f', 'docker-compose.yml')
if ($Firewall) {
    $composeFiles += @('-f', 'docker-compose.firewall.yml')
}

Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $repoRoot '.logs\dhcp1'), `
        (Join-Path $repoRoot '.logs\dhcp2') | Out-Null

    docker compose @composeFiles up -d
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose up failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
