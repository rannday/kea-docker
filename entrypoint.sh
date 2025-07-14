#!/bin/bash
set -euo pipefail

echo "[entrypoint] Starting MySQL..."
/usr/sbin/mysqld \
  --socket=/var/run/mysqld/mysqld.sock \
  --user=root \
  --log-bin-trust-function-creators=1 \
  --innodb-flush-log-at-trx-commit=2 \
  --default-time-zone='+00:00' &

MYSQL_PID=$!

echo "[entrypoint] Waiting for MySQL to be ready..."
for i in $(seq 1 30); do
  if mysqladmin ping --silent; then
    echo "[entrypoint] MySQL is ready."
    break
  fi
  sleep 1
done

if ! mysqladmin ping --silent; then
  echo "[entrypoint] ERROR: MySQL did not start within timeout." >&2
  kill $MYSQL_PID
  exit 1
fi

# Optional: Confirm Kea DB is accessible
if ! mysql -ukea -pkea -e "USE kea;" >/dev/null 2>&1; then
  echo "[entrypoint] ERROR: Kea DB not accessible or missing. Aborting."
  kill $MYSQL_PID
  exit 1
fi

echo "[entrypoint] Starting Kea DHCP4..."
/usr/sbin/kea-dhcp4 -c /etc/kea/kea-dhcp4.conf -d &

echo "[entrypoint] Starting Kea DHCP6..."
/usr/sbin/kea-dhcp6 -c /etc/kea/kea-dhcp6.conf -d &

echo "[entrypoint] Starting Kea DDNS..."
/usr/sbin/kea-dhcp-ddns -c /etc/kea/kea-dhcp-ddns.conf -d &

echo "[entrypoint] Starting Kea Control Agent..."
/usr/sbin/kea-ctrl-agent -c /etc/kea/kea-ctrl-agent.conf -d &

# Wait for all background jobs (Kea and MySQL)
wait
