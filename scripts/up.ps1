$ErrorActionPreference = "Stop"

docker compose down --remove-orphans

$repoRoot = Split-Path $PSScriptRoot -Parent; New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot '.logs\dhcp1'), (Join-Path $repoRoot '.logs\dhcp2') | Out-Null

docker compose build --no-cache

docker compose up -d --force-recreate