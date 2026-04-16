#!/bin/sh
set -eu

NAMED_PID=""
EXPORTER_PID=""

find_bind_exporter_bin() {
  if command -v prometheus-bind-exporter >/dev/null 2>&1; then
    command -v prometheus-bind-exporter
    return 0
  fi

  if command -v bind_exporter >/dev/null 2>&1; then
    command -v bind_exporter
    return 0
  fi

  echo "[entrypoint] could not find bind_exporter binary" >&2
  exit 1
}

BIND_EXPORTER_BIN="$(find_bind_exporter_bin)"

load_nftables() {
  echo "[entrypoint] loading nftables rules"
  nft -f /etc/nftables.conf
}

prepare_zone_files() {
  echo "[entrypoint] preparing writable primary zones"
  mkdir -p /var/cache/bind/primary /var/run/named
  chown -R bind:bind /var/cache/bind /var/run/named

  for zone_file in db.example.com db.3.0.192 db.1.0.0.0.9.6.0.0.9.6.0.0.9.6.d.f.ip6.arpa; do
    if [ ! -f "/var/cache/bind/primary/${zone_file}" ]; then
      cp "/usr/local/share/bind/zones/${zone_file}" "/var/cache/bind/primary/${zone_file}"
    fi
  done

  chown -R bind:bind /var/cache/bind/primary
}

validate_config() {
  echo "[entrypoint] validating named configuration"
  named-checkconf /etc/bind/named.conf
  named-checkzone example.com /var/cache/bind/primary/db.example.com
  named-checkzone 3.0.192.in-addr.arpa /var/cache/bind/primary/db.3.0.192
  named-checkzone 1.0.0.0.9.6.0.0.9.6.0.0.9.6.d.f.ip6.arpa /var/cache/bind/primary/db.1.0.0.0.9.6.0.0.9.6.0.0.9.6.d.f.ip6.arpa
}

start_named() {
  echo "[entrypoint] starting named"
  named -u bind -c /etc/bind/named.conf -g &
  NAMED_PID=$!
}

start_exporter() {
  echo "[entrypoint] starting bind_exporter"
  "${BIND_EXPORTER_BIN}" \
    --bind.stats-url=http://127.0.0.1:8053/ \
    --bind.pid-file=/var/cache/bind/named.pid \
    --web.listen-address=0.0.0.0:9119 &
  EXPORTER_PID=$!
}

stop_services() {
  if [ -n "${EXPORTER_PID}" ]; then
    kill "${EXPORTER_PID}" 2>/dev/null || true
  fi

  if [ -n "${NAMED_PID}" ]; then
    kill "${NAMED_PID}" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
}

trap '
  echo "[entrypoint] received stop signal"
  stop_services
  exit 0
' INT TERM

load_nftables
prepare_zone_files
validate_config
start_named
start_exporter

while :; do
  if ! kill -0 "${NAMED_PID}" 2>/dev/null; then
    echo "[entrypoint] named exited"
    break
  fi

  if ! kill -0 "${EXPORTER_PID}" 2>/dev/null; then
    echo "[entrypoint] bind_exporter exited"
    break
  fi

  sleep 1
done

echo "[entrypoint] a service exited, shutting down"
stop_services
exit 1
