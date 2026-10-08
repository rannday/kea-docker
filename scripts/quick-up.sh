#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

mkdir -p "$repo_root/.logs/dhcp1" "$repo_root/.logs/dhcp2"

docker compose up -d
