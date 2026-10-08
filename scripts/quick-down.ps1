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
    docker compose @composeFiles down --remove-orphans
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose down failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}
