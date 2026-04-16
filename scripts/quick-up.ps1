$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent

Push-Location $repoRoot
try {
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $repoRoot '.logs\dhcp1'), `
        (Join-Path $repoRoot '.logs\dhcp2') | Out-Null

    docker compose up -d
}
finally {
    Pop-Location
}
