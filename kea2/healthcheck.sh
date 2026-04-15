#!/bin/sh
set -eu

AUTH='kea:keapass'

check_http() {
  port="$1"
  response="$(
    curl -sf \
      -u "$AUTH" \
      -X POST \
      -H "Content-Type: application/json" \
      -d '{"command":"status-get"}' \
      "http://127.0.0.1:${port}/"
  )"
  printf '%s\n' "$response" | grep -q '"result"[[:space:]]*:[[:space:]]*0'
}

check_pg() {
  kea-admin db-version pgsql \
    -u kea \
    -p keapass \
    -n kea_db \
    -h 127.0.0.1 \
    -4 >/dev/null 2>&1

  kea-admin db-version pgsql \
    -u kea \
    -p keapass \
    -n kea_db \
    -h 127.0.0.1 \
    -6 >/dev/null 2>&1
}

check_pg
check_http 8001
check_http 9001
