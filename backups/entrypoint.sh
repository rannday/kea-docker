#!/bin/sh
set -eu

PG_PRIMARY_USER="repl"
PG_PRIMARY_PASSWORD="replpass"

PG_LEASE_PRIMARY_HOST="192.168.69.10"
PG_LEASE_PRIMARY_PORT="5432"
PG_LEASE_DATA="/var/lib/postgresql/lease"
PG_LEASE_PORT="5432"

PG_SHARED_PRIMARY_HOST="192.168.69.2"
PG_SHARED_PRIMARY_PORT="5432"
PG_SHARED_DATA="/var/lib/postgresql/shared"
PG_SHARED_PORT="5433"

PG_LEASE_READY=0
PG_SHARED_READY=0

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

cleanup() {
  if [ "${PG_LEASE_READY}" = "1" ]; then
    su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PG_LEASE_DATA}' -m fast stop >/dev/null" 2>/dev/null || true
  fi

  if [ "${PG_SHARED_READY}" = "1" ]; then
    su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PG_SHARED_DATA}' -m fast stop >/dev/null" 2>/dev/null || true
  fi
}
trap cleanup EXIT
trap 'exit 0' INT TERM

wait_for_host_port() {
  host="$1"
  port="$2"
  name="$3"

  echo "[entrypoint] waiting for ${name} at ${host}:${port}"
  i=0
  while ! nc -z "${host}" "${port}" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "${i}" -ge 120 ]; then
      echo "[entrypoint] timed out waiting for ${name}"
      exit 1
    fi
    sleep 1
  done
}

prepare_postgres_dirs() {
  echo "[entrypoint] preparing PostgreSQL directories"

  mkdir -p /var/lib/postgresql /var/run/postgresql
  chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql
  chmod 2775 /var/run/postgresql
}

init_postgres_standby() {
  cluster_name="$1"
  data_dir="$2"
  primary_host="$3"
  primary_port="$4"

  echo "[entrypoint] preparing PostgreSQL ${cluster_name} standby"

  if [ -s "${data_dir}/PG_VERSION" ]; then
    echo "[entrypoint] PostgreSQL ${cluster_name} standby already initialized"
    return
  fi

  rm -rf "${data_dir}"
  mkdir -p "${data_dir}"
  chown -R postgres:postgres "${data_dir}"
  chmod 700 "${data_dir}"

  export PGPASSWORD="${PG_PRIMARY_PASSWORD}"

  su -s /bin/sh postgres -c "
    ${PGBIN}/pg_basebackup \
      -h '${primary_host}' \
      -p '${primary_port}' \
      -U '${PG_PRIMARY_USER}' \
      -D '${data_dir}' \
      -Fp \
      -Xs \
      -P \
      -R
  "
}

start_postgres_cluster() {
  cluster_name="$1"
  data_dir="$2"
  port="$3"
  ready_var="$4"

  echo "[entrypoint] starting PostgreSQL ${cluster_name} standby on port ${port}"

  chown -R postgres:postgres "${data_dir}"
  chmod 700 "${data_dir}"
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${data_dir}' -o '-c port=${port} -c listen_addresses=0.0.0.0' -w start"
  eval "${ready_var}=1"
}

wait_postgres_cluster() {
  cluster_name="$1"
  port="$2"

  echo "[entrypoint] waiting for PostgreSQL ${cluster_name} standby"

  i=0
  until pg_isready -h 127.0.0.1 -p "${port}" -U postgres -d postgres >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "${i}" -ge 60 ]; then
      echo "[entrypoint] PostgreSQL ${cluster_name} did not become ready"
      exit 1
    fi
    sleep 1
  done
}

postgres_is_in_recovery() {
  port="$1"
  su -s /bin/sh postgres -c "psql -h 127.0.0.1 -p '${port}' -d postgres -tAc 'SELECT pg_is_in_recovery()'" | grep -qx t
}

wait_postgres_replica() {
  cluster_name="$1"
  port="$2"

  echo "[entrypoint] checking PostgreSQL ${cluster_name} standby state"

  i=0
  while ! postgres_is_in_recovery "${port}"; do
    i=$((i + 1))
    if [ "${i}" -ge 30 ]; then
      echo "[entrypoint] PostgreSQL ${cluster_name} is not in recovery mode"
      exit 1
    fi
    sleep 1
  done

  echo "[entrypoint] PostgreSQL ${cluster_name} standby is running"
}

main_loop() {
  while :; do
    if ! pg_isready -h 127.0.0.1 -p "${PG_LEASE_PORT}" -U postgres -d postgres >/dev/null 2>&1; then
      echo "[entrypoint] PostgreSQL lease health check failed"
      return 1
    fi

    if ! pg_isready -h 127.0.0.1 -p "${PG_SHARED_PORT}" -U postgres -d postgres >/dev/null 2>&1; then
      echo "[entrypoint] PostgreSQL shared DB health check failed"
      return 1
    fi

    sleep 5
  done
}

echo "[entrypoint] starting PostgreSQL backup setup"

load_nftables
wait_for_host_port "${PG_LEASE_PRIMARY_HOST}" "${PG_LEASE_PRIMARY_PORT}" "PostgreSQL lease primary"
wait_for_host_port "${PG_SHARED_PRIMARY_HOST}" "${PG_SHARED_PRIMARY_PORT}" "PostgreSQL shared primary"

prepare_postgres_dirs

init_postgres_standby "lease" "${PG_LEASE_DATA}" "${PG_LEASE_PRIMARY_HOST}" "${PG_LEASE_PRIMARY_PORT}"
start_postgres_cluster "lease" "${PG_LEASE_DATA}" "${PG_LEASE_PORT}" PG_LEASE_READY
wait_postgres_cluster "lease" "${PG_LEASE_PORT}"
wait_postgres_replica "lease" "${PG_LEASE_PORT}"

init_postgres_standby "shared" "${PG_SHARED_DATA}" "${PG_SHARED_PRIMARY_HOST}" "${PG_SHARED_PRIMARY_PORT}"
start_postgres_cluster "shared" "${PG_SHARED_DATA}" "${PG_SHARED_PORT}" PG_SHARED_READY
wait_postgres_cluster "shared" "${PG_SHARED_PORT}"
wait_postgres_replica "shared" "${PG_SHARED_PORT}"

echo "[entrypoint] PostgreSQL standby clusters are up"
main_loop
