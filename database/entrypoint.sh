#!/bin/sh
set -eu

PGHOST="127.0.0.1"
PG_LISTEN_ADDRESSES="0.0.0.0"
PGPORT="5432"
PGDATA="/var/lib/postgresql/data"
PGUSER="kea"
PGPASSWORD="keapass"
PGDATABASE="kea_db"
PG_REPL_USER="repl"
PG_REPL_PASSWORD="replpass"
PG_TEMPLATE_DIR="/usr/local/share/kea"

export PGPASSWORD

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
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -m fast stop >/dev/null" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM

start_postgres() {
  echo "[entrypoint] preparing PostgreSQL shared DB"

  mkdir -p "${PGDATA}" /var/run/postgresql
  chown -R postgres:postgres /var/lib/postgresql /var/run/postgresql
  chmod 2775 /var/run/postgresql

  if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    echo "[entrypoint] initializing PostgreSQL shared cluster"
    su -s /bin/sh postgres -c "${PGBIN}/initdb -D '${PGDATA}' >/dev/null"
  fi

  cp "${PG_TEMPLATE_DIR}/postgresql.conf" "${PGDATA}/postgresql.conf"
  cp "${PG_TEMPLATE_DIR}/pg_hba.conf" "${PGDATA}/pg_hba.conf"
  chown postgres:postgres "${PGDATA}/postgresql.conf" "${PGDATA}/pg_hba.conf"

  echo "[entrypoint] starting PostgreSQL shared DB"
  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -o '-c listen_addresses=${PG_LISTEN_ADDRESSES} -c shared_preload_libraries=pg_cron -c cron.database_name=${PGDATABASE} -p ${PGPORT}' -w start >/dev/null"
}

wait_postgres() {
  echo "[entrypoint] waiting for PostgreSQL shared DB"
  until pg_isready -h "${PGHOST}" -p "${PGPORT}" >/dev/null 2>&1; do
    sleep 1
  done
}

setup_postgres_db() {
  echo "[entrypoint] ensuring shared PostgreSQL role and database exist"

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${PGUSER}'\"" | grep -q 1 || \
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' postgres -c \"CREATE ROLE ${PGUSER} LOGIN PASSWORD '${PGPASSWORD}'\""

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -tAc \"SELECT 1 FROM pg_roles WHERE rolname='${PG_REPL_USER}'\"" | grep -q 1 || \
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' postgres -c \"CREATE ROLE ${PG_REPL_USER} WITH LOGIN REPLICATION PASSWORD '${PG_REPL_PASSWORD}'\""

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -tAc \"SELECT 1 FROM pg_database WHERE datname='${PGDATABASE}'\"" | grep -q 1 || \
    su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' postgres -c \"CREATE DATABASE ${PGDATABASE} OWNER ${PGUSER}\""
}

init_pgsql_v4() {
  echo "[init] shared pgsql dhcp4 schema: checking"
  if kea-admin db-version pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -4 >/dev/null 2>&1; then
    echo "[init] shared pgsql dhcp4 schema already present"
  else
    echo "[init] shared pgsql dhcp4 schema: initializing"
    kea-admin db-init pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -4
  fi
}

init_pgsql_v6() {
  echo "[init] shared pgsql dhcp6 schema: checking"
  if kea-admin db-version pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -6 >/dev/null 2>&1; then
    echo "[init] shared pgsql dhcp6 schema already present"
  else
    echo "[init] shared pgsql dhcp6 schema: initializing"
    kea-admin db-init pgsql -u "${PGUSER}" -p "${PGPASSWORD}" -n "${PGDATABASE}" -h "${PGHOST}" -6
  fi
}

configure_pg_cron() {
  echo "[entrypoint] ensuring shared DB pg_cron cleanup jobs exist"

  su -s /bin/sh postgres -c "psql -v ON_ERROR_STOP=1 -h '${PGHOST}' -p '${PGPORT}' -d '${PGDATABASE}'" <<'SQL'
CREATE EXTENSION IF NOT EXISTS pg_cron;

SELECT cron.unschedule(jobid)
FROM cron.job
WHERE jobname IN ('kea_logs_purge_batch', 'kea_logs_vacuum');

SELECT cron.schedule(
  'kea_logs_purge_batch',
  '0 * * * *',
  $sql$
    DELETE FROM public.logs
    WHERE ctid IN (
      SELECT ctid
      FROM public.logs
      WHERE "timestamp" < now() - interval '2 years'
      ORDER BY "timestamp"
      LIMIT 10000
    );
  $sql$
);

SELECT cron.schedule(
  'kea_logs_vacuum',
  '10 3 * * *',
  'VACUUM (ANALYZE) public.logs;'
);
SQL
}

main_loop() {
  while :; do
    if ! pg_isready -h "${PGHOST}" -p "${PGPORT}" -U "${PGUSER}" -d "${PGDATABASE}" >/dev/null 2>&1; then
      echo "[entrypoint] shared PostgreSQL health check failed"
      return 1
    fi

    sleep 5
  done
}

echo "[entrypoint] starting shared PostgreSQL setup"
load_nftables
start_postgres
wait_postgres
setup_postgres_db
init_pgsql_v4
init_pgsql_v6
configure_pg_cron

echo "[entrypoint] shared PostgreSQL is up"
main_loop
