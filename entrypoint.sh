#!/bin/bash
set -e

echo "Starting MySQL..."
/usr/sbin/mysqld \
  --socket=/var/run/mysqld/mysqld.sock \
  --user=root \
  --log-bin-trust-function-creators=1 \
  --innodb-flush-log-at-trx-commit=2 \
  --default-time-zone='+00:00' &

echo "Waiting for MySQL to be ready..."
for i in $(seq 1 30); do
  if mysqladmin ping --silent; then
    echo "MySQL is ready."
    break
  fi
  sleep 1
done

if ! mysqladmin ping --silent; then
  echo "MySQL did not start within timeout." >&2
  exit 1
fi

echo "Starting Kea DHCP4..."
/usr/sbin/kea-dhcp4 -c /etc/kea/kea-dhcp4.conf -d &

echo "Starting Kea DHCP6..."
/usr/sbin/kea-dhcp6 -c /etc/kea/kea-dhcp6.conf -d &

echo "Starting Kea DDNS..."
/usr/sbin/kea-dhcp-ddns -c /etc/kea/kea-dhcp-ddns.conf -d &

echo "Starting Kea Control Agent..."
/usr/sbin/kea-ctrl-agent -c /etc/kea/kea-ctrl-agent.conf -d &

wait
