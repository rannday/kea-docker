#!/bin/sh
set -eu

STORK_ENV_FILE="/etc/stork/server.env"
PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
GRAFANA_CONFIG="/etc/grafana/grafana.ini"
STORK_DB_HOST="127.0.0.1"
STORK_DB_PORT="5432"
STORK_DB_NAME="stork"
STORK_DB_USER="stork"
STORK_DB_PASSWORD="storkpass"
STORK_DB_DATA="/var/lib/postgresql/data"
STORK_DB_MAINTENANCE_NAME="postgres"
STORK_DB_MAINTENANCE_USER="postgres"
STORK_PID=""
PROMETHEUS_PID=""
GRAFANA_PID=""

find_postgres_bin() {
  if command -v postgres >/dev/null 2>&1; then
    dirname "$(command -v postgres)"
    return 0
  fi

  for dir in /usr/lib/postgresql/*/bin; do
    if [ -x "${dir}/postgres" ]; then
      echo "${dir}"
      return 0
    fi
  done

  echo "[entrypoint] could not find postgres binary" >&2
  exit 1
}

PGBIN="$(find_postgres_bin)"

load_nftables() {
  echo "[entrypoint] loading nftables rules"
  nft -f /etc/nftables.conf
}

start_postgres() {
  echo "[entrypoint] preparing Stork PostgreSQL database"

  mkdir -p "${STORK_DB_DATA}" /var/run/postgresql
  chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql
  chmod 2775 /var/run/postgresql

  if [ ! -s "${STORK_DB_DATA}/PG_VERSION" ]; then
    echo "[entrypoint] initializing Stork PostgreSQL cluster"
    su -s /bin/sh postgres -c "${PGBIN}/initdb -D '${STORK_DB_DATA}' >/dev/null"
  fi

  echo "[entrypoint] starting Stork PostgreSQL database"
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${STORK_DB_DATA}' -o '-c listen_addresses=${STORK_DB_HOST} -p ${STORK_DB_PORT}' -w start >/dev/null"
}

wait_postgres() {
  echo "[entrypoint] waiting for Stork PostgreSQL database"
  until pg_isready -h "${STORK_DB_HOST}" -p "${STORK_DB_PORT}" >/dev/null 2>&1; do
    sleep 1
  done
}

setup_stork_database() {
  echo "[entrypoint] ensuring Stork database and role exist"

  if ! su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_MAINTENANCE_NAME}' -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${STORK_DB_USER}'\"" | grep -q 1; then
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_MAINTENANCE_NAME}' -c \"CREATE ROLE ${STORK_DB_USER} LOGIN PASSWORD '${STORK_DB_PASSWORD}'\""
  fi

  if ! su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_MAINTENANCE_NAME}' -tAc \"SELECT 1 FROM pg_database WHERE datname='${STORK_DB_NAME}'\"" | grep -q 1; then
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_MAINTENANCE_NAME}' -c \"CREATE DATABASE ${STORK_DB_NAME} OWNER ${STORK_DB_USER}\""
  fi

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_NAME}' -c \"GRANT ALL PRIVILEGES ON SCHEMA public TO ${STORK_DB_USER}\""
  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${STORK_DB_HOST}' -p '${STORK_DB_PORT}' -d '${STORK_DB_NAME}' -c \"CREATE EXTENSION IF NOT EXISTS pgcrypto\""
}

prepare_dashboards() {
  echo "[entrypoint] preparing Grafana dashboards"
  mkdir -p /var/lib/grafana/dashboards

  if [ -d /usr/local/share/grafana/dashboards ]; then
    find /usr/local/share/grafana/dashboards -maxdepth 1 -type f -name '*.json' -exec cp {} /var/lib/grafana/dashboards/ \;
  fi

  if [ -d /usr/share/stork/grafana ]; then
    find /usr/share/stork/grafana -maxdepth 1 -type f -name '*.json' -exec cp {} /var/lib/grafana/dashboards/ \;
  fi
}

start_stork_server() {
  echo "[entrypoint] starting stork-server"
  stork-server --use-env-file &
  STORK_PID=$!
}

start_prometheus() {
  echo "[entrypoint] starting prometheus"
  /usr/bin/prometheus \
    --config.file="${PROMETHEUS_CONFIG}" \
    --storage.tsdb.path=/var/lib/prometheus \
    --web.console.templates=/usr/share/prometheus/consoles \
    --web.console.libraries=/usr/share/prometheus/console_libraries &
  PROMETHEUS_PID=$!
}

start_grafana() {
  echo "[entrypoint] starting grafana"
  /usr/sbin/grafana-server \
    --homepath=/usr/share/grafana \
    --config="${GRAFANA_CONFIG}" \
    cfg:default.paths.data=/var/lib/grafana \
    cfg:default.paths.logs=/var/log/grafana \
    cfg:default.paths.plugins=/var/lib/grafana/plugins \
    cfg:default.paths.provisioning=/etc/grafana/provisioning &
  GRAFANA_PID=$!
}

stop_services() {
  if [ -n "${GRAFANA_PID}" ]; then
    kill "${GRAFANA_PID}" 2>/dev/null || true
  fi

  if [ -n "${PROMETHEUS_PID}" ]; then
    kill "${PROMETHEUS_PID}" 2>/dev/null || true
  fi

  if [ -n "${STORK_PID}" ]; then
    kill "${STORK_PID}" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${STORK_DB_DATA}' -m fast stop >/dev/null" 2>/dev/null || true
}

trap '
  echo "[entrypoint] received stop signal"
  stop_services
  exit 0
' INT TERM

load_nftables
start_postgres
wait_postgres
setup_stork_database
prepare_dashboards
start_stork_server
start_prometheus
start_grafana

while :; do
  if ! kill -0 "${STORK_PID}" 2>/dev/null; then
    echo "[entrypoint] stork-server exited"
    break
  fi

  if ! pg_isready -h "${STORK_DB_HOST}" -p "${STORK_DB_PORT}" -U "${STORK_DB_USER}" -d "${STORK_DB_NAME}" >/dev/null 2>&1; then
    echo "[entrypoint] Stork PostgreSQL database is not ready"
    break
  fi

  if ! kill -0 "${PROMETHEUS_PID}" 2>/dev/null; then
    echo "[entrypoint] prometheus exited"
    break
  fi

  if ! kill -0 "${GRAFANA_PID}" 2>/dev/null; then
    echo "[entrypoint] grafana exited"
    break
  fi

  sleep 1
done

echo "[entrypoint] a service exited, shutting down"
stop_services
exit 1
