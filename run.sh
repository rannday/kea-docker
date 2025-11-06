#!/usr/bin/env bash
set -e

echo "Stopping and removing kea-custom..."
docker rm -f kea-custom 2>/dev/null || true

echo
echo "Running Kea Docker container on Linux..."

docker run --rm -it \
  --cap-add=NET_ADMIN \
  -p 6767:67/udp \
  -p 6547:547/udp \
  -p 8001:8000 \
  -v "$(pwd)/config:/etc/kea:ro" \
  -v "$(pwd)/logs:/var/log/kea" \
  kea-custom
