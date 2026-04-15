#!/bin/sh
set -eu

DHCP4_FILE="/etc/kea/kea-dhcp4.conf"
DHCP6_FILE="/etc/kea/kea-dhcp6.conf"

PGHOST="127.0.0.1"
PGPORT="5432"
PGDATA="/var/lib/postgresql/data"
PGUSER="kea"
PGPASSWORD="keapass"
PGDATABASE="kea_leases"
PG_TEMPLATE_DIR="/usr/local/share/kea"
STORK_AGENT_ENV_FILE="/etc/stork/agent.env"
STORK_AGENT_HOST="192.168.69.11"
STORK_AGENT_PORT="8080"
STORK_AGENT_SERVER_URL="http://192.168.69.100:8080"
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_ADDRESS="0.0.0.0"
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PORT="9547"
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_INTERVAL="10"
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PER_SUBNET_STATS="false"

export PGPASSWORD

DHCP4_PID=""
DHCP6_PID=""
STORK_AGENT_PID=""

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
  echo "[entrypoint] preparing postgres"

  mkdir -p "${PGDATA}" /var/run/postgresql
  chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql
  chmod 2775 /var/run/postgresql

  if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "[entrypoint] initializing postgres cluster"
    su -s /bin/sh postgres -c "${PGBIN}/initdb -D '${PGDATA}' >/dev/null"
  fi

  cp "${PG_TEMPLATE_DIR}/postgresql.conf" "${PGDATA}/postgresql.conf"
  chown postgres:postgres "${PGDATA}/postgresql.conf"

  echo "[entrypoint] starting postgres"
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -o '-c listen_addresses=${PGHOST} -p ${PGPORT}' -w start >/dev/null"
}

wait_postgres() {
  echo "[entrypoint] waiting for postgres"
  until pg_isready -h "${PGHOST}" -p "${PGPORT}" >/dev/null 2>&1; do
    sleep 1
  done
}

setup_postgres_db() {
  echo "[entrypoint] ensuring postgres role and database exist"

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${PGUSER}'\"" | grep -q 1 || \
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' postgres -c \"CREATE ROLE ${PGUSER} LOGIN PASSWORD '${PGPASSWORD}'\""

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -tAc \"SELECT 1 FROM pg_database WHERE datname='${PGDATABASE}'\"" | grep -q 1 || \
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' postgres -c \"CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER}\""
}

init_pgsql_v4() {
  echo "[init] pgsql dhcp4: checking schema"
  if kea-admin db-version pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -4 >/dev/null 2>&1; then
    echo "[init] pgsql dhcp4: schema already present"
  else
    echo "[init] pgsql dhcp4: initializing schema"
    kea-admin db-init pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -4
  fi
}

init_pgsql_v6() {
  echo "[init] pgsql dhcp6: checking schema"
  if kea-admin db-version pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -6 >/dev/null 2>&1; then
    echo "[init] pgsql dhcp6: schema already present"
  else
    echo "[init] pgsql dhcp6: initializing schema"
    kea-admin db-init pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -6
  fi
}

validate_configs() {
  echo "[entrypoint] validating ${DHCP4_FILE}"
  kea-dhcp4 -t "${DHCP4_FILE}"

  echo "[entrypoint] validating ${DHCP6_FILE}"
  kea-dhcp6 -t "${DHCP6_FILE}"
}

write_stork_agent_config() {
  echo "[entrypoint] writing Stork agent configuration"

  mkdir -p /etc/stork /var/lib/stork-agent /usr/lib/stork-agent/hooks

  cat > "${STORK_AGENT_ENV_FILE}" <<EOF
STORK_AGENT_SERVER_URL=${STORK_AGENT_SERVER_URL}
STORK_AGENT_HOST=${STORK_AGENT_HOST}
STORK_AGENT_PORT=${STORK_AGENT_PORT}
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_ADDRESS=${STORK_AGENT_PROMETHEUS_KEA_EXPORTER_ADDRESS}
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PORT=${STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PORT}
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_INTERVAL=${STORK_AGENT_PROMETHEUS_KEA_EXPORTER_INTERVAL}
STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PER_SUBNET_STATS=${STORK_AGENT_PROMETHEUS_KEA_EXPORTER_PER_SUBNET_STATS}
STORK_LOG_LEVEL=INFO
EOF
}

start_stork_agent() {
  echo "[entrypoint] starting stork-agent"
  stork-agent --use-env-file &
  STORK_AGENT_PID=$!
}

stop_services() {
  if [ -n "${STORK_AGENT_PID}" ]; then
    kill "${STORK_AGENT_PID}" 2>/dev/null || true
  fi

  if [ -n "${DHCP4_PID}" ]; then
    kill "${DHCP4_PID}" 2>/dev/null || true
  fi

  if [ -n "${DHCP6_PID}" ]; then
    kill "${DHCP6_PID}" 2>/dev/null || true
  fi

  wait 2>/dev/null || true
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -m fast stop >/dev/null" 2>/dev/null || true
}

trap '
  echo "[entrypoint] received stop signal"
  stop_services
  exit 0
' INT TERM

load_nftables
start_postgres
wait_postgres
setup_postgres_db
init_pgsql_v4
init_pgsql_v6
validate_configs
write_stork_agent_config

echo "[entrypoint] starting kea-dhcp4"
kea-dhcp4 -c "${DHCP4_FILE}" &
DHCP4_PID=$!

echo "[entrypoint] starting kea-dhcp6"
kea-dhcp6 -c "${DHCP6_FILE}" &
DHCP6_PID=$!

start_stork_agent

while :; do
  if ! kill -0 "${DHCP4_PID}" 2>/dev/null; then
    echo "[entrypoint] kea-dhcp4 exited"
    break
  fi

  if ! kill -0 "${DHCP6_PID}" 2>/dev/null; then
    echo "[entrypoint] kea-dhcp6 exited"
    break
  fi

  if ! kill -0 "${STORK_AGENT_PID}" 2>/dev/null; then
    echo "[entrypoint] stork-agent exited"
    break
  fi

  if ! pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" >/dev/null 2>&1; then
    echo "[entrypoint] postgres is not ready"
    break
  fi

  sleep 1
done

echo "[entrypoint] a service exited, shutting down"
stop_services
exit 1
