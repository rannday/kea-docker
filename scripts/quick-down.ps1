$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent

Push-Location $repoRoot
try {
    docker compose down --remove-orphans
}
finally {
    Pop-Location
}
