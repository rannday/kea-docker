#!/bin/sh
set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
cd "$repo_root"

# Remove volumes, images, orphan containers, and DHCP log contents.
docker compose down --volumes --rmi all --remove-orphans

for log_path in "$repo_root/.logs/dhcp1" "$repo_root/.logs/dhcp2"; do
    if [ -d "$log_path" ]; then
        # Include hidden entries while preserving the log directory itself.
        rm -rf "$log_path"/* "$log_path"/.[!.]* "$log_path"/..?*
    fi
done
