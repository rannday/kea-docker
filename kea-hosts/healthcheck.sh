#!/bin/sh
set -eu

version="$(
  kea-admin db-version mysql \
    -u kea \
    -p keapass \
    -n kea_hosts \
    -h 127.0.0.1 2>/dev/null
)"

printf '%s\n' "$version" | grep -qx '30\.0'
