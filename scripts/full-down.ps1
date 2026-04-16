$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$logPaths = @(
    (Join-Path $repoRoot '.logs\dhcp1'),
    (Join-Path $repoRoot '.logs\dhcp2')
)

Push-Location $repoRoot
try {
    docker compose down --volumes --rmi all --remove-orphans

    foreach ($logPath in $logPaths) {
        if (Test-Path $logPath) {
            Get-ChildItem -Force -LiteralPath $logPath | Remove-Item -Recurse -Force
        }
    }
}
finally {
    Pop-Location
}
