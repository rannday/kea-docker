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
    docker compose @composeFiles down --volumes --rmi all --remove-orphans
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose down failed with exit code $LASTEXITCODE."
    }

    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            Get-ChildItem -Force -LiteralPath $logPath | Remove-Item -Recurse -Force
        }
    }
}
finally {
    Pop-Location
}
