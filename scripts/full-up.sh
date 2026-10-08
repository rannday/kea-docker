#!/bin/sh
set -eu

case "$#:${1-}" in
    0:)
        set -- -f docker-compose.yml
        ;;
    1:--firewall)
        set -- -f docker-compose.yml -f docker-compose.firewall.yml
        ;;
    *)
        echo "Usage: $0 [--firewall]" >&2
        exit 2
        ;;
esac

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

mkdir -p "$repo_root/.logs/dhcp1" "$repo_root/.logs/dhcp2"

docker compose "$@" build --no-cache
docker compose "$@" up -d --force-recreate
