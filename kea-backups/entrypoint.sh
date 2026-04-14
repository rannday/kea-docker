#!/bin/sh
set -eu

# MariaDB replica source
MYSQL_PRIMARY_HOST="kea-hosts"
MYSQL_PRIMARY_PORT="3306"
MYSQL_ROOT_PASSWORD="rootpass"
MYSQL_REPL_USER="repl"
MYSQL_REPL_PASSWORD="replpass"

# Local MariaDB
MYSQL_DATADIR="/var/lib/mysql"
MYSQL_RUN_DIR="/run/mysqld"
MYSQL_SOCKET="${MYSQL_RUN_DIR}/mysqld.sock"
MYSQL_PIDFILE="${MYSQL_RUN_DIR}/mysqld.pid"

# PostgreSQL replica source
# A single standby can follow only one upstream cluster.
# Defaulting to kea1 here.
PG_PRIMARY_HOST="kea1"
PG_PRIMARY_PORT="5432"
PG_PRIMARY_USER="repl"
PG_PRIMARY_PASSWORD="replpass"
PGDATABASE="kea_leases"

# Local PostgreSQL
PGDATA="/var/lib/postgresql/data"
PGPORT="5432"

MYSQL_PID=""
PG_READY=0

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

cleanup() {
  if [ -n "${MYSQL_PID}" ]; then
    kill "${MYSQL_PID}" 2>/dev/null || true
    wait "${MYSQL_PID}" 2>/dev/null || true
  fi

  if [ "${PG_READY}" = "1" ]; then
    su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -m fast stop >/dev/null" 2>/dev/null || true
  fi
}
trap cleanup INT TERM

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

init_mysql_datadir() {
  echo "[entrypoint] preparing MariaDB datadir"

  mkdir -p "${MYSQL_DATADIR}" "${MYSQL_RUN_DIR}"
  chown -R mysql:mysql "${MYSQL_DATADIR}" "${MYSQL_RUN_DIR}"

  if [ -d "${MYSQL_DATADIR}/mysql" ]; then
    echo "[entrypoint] MariaDB datadir already initialized"
    return
  fi

  mariadb-install-db \
    --user=mysql \
    --datadir="${MYSQL_DATADIR}" \
    --auth-root-authentication-method=normal \
    --skip-test-db
}

start_mysql() {
  echo "[entrypoint] starting MariaDB"

  mkdir -p "${MYSQL_RUN_DIR}"
  chown -R mysql:mysql "${MYSQL_RUN_DIR}" "${MYSQL_DATADIR}"

  mariadbd-safe \
    --datadir="${MYSQL_DATADIR}" \
    --socket="${MYSQL_SOCKET}" \
    --pid-file="${MYSQL_PIDFILE}" \
    --bind-address=0.0.0.0 \
    --skip-syslog \
    >/dev/stdout 2>/dev/stderr &
  MYSQL_PID=$!

  i=0
  while ! mariadb-admin --socket="${MYSQL_SOCKET}" ping >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "${i}" -ge 60 ]; then
      echo "[entrypoint] MariaDB did not become ready"
      exit 1
    fi
    sleep 1
  done

  echo "[entrypoint] MariaDB is ready"
}

mysql_root_exec() {
  if mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot -e 'SELECT 1' >/dev/null 2>&1; then
    mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot "$@"
  else
    mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" "$@"
  fi
}

mysql_root_exec_stdin() {
  if mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot -e 'SELECT 1' >/dev/null 2>&1; then
    mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot
  else
    mariadb --protocol=socket --socket="${MYSQL_SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}"
  fi
}

configure_mysql_root() {
  echo "[entrypoint] setting MariaDB root password"

  mysql_root_exec_stdin <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL
}

mysql_replica_already_configured() {
  mysql_root_exec -Nse "SHOW REPLICA STATUS\\G" 2>/dev/null | grep -q "Source_Host: ${MYSQL_PRIMARY_HOST}"
}

configure_mysql_replica() {
  echo "[entrypoint] configuring MariaDB replica"

  if mysql_replica_already_configured; then
    echo "[entrypoint] MariaDB replica already configured"
    return
  fi

  mysql_root_exec_stdin <<SQL
STOP REPLICA;
RESET REPLICA ALL;
CHANGE MASTER TO
  MASTER_HOST='${MYSQL_PRIMARY_HOST}',
  MASTER_PORT=${MYSQL_PRIMARY_PORT},
  MASTER_USER='${MYSQL_REPL_USER}',
  MASTER_PASSWORD='${MYSQL_REPL_PASSWORD}',
  MASTER_USE_GTID=slave_pos;
START REPLICA;
SQL
}

wait_mysql_replica() {
  echo "[entrypoint] waiting for MariaDB replication"

  i=0
  while :; do
    status="$(mysql_root_exec -Nse "SHOW REPLICA STATUS\\G" 2>/dev/null || true)"

    io_running="$(printf '%s\n' "${status}" | awk -F': ' '/Replica_IO_Running/ {print $2}')"
    sql_running="$(printf '%s\n' "${status}" | awk -F': ' '/Replica_SQL_Running/ {print $2}')"

    if [ "${io_running}" = "Yes" ] && [ "${sql_running}" = "Yes" ]; then
      echo "[entrypoint] MariaDB replication is running"
      return
    fi

    i=$((i + 1))
    if [ "${i}" -ge 60 ]; then
      echo "[entrypoint] MariaDB replication did not become healthy"
      printf '%s\n' "${status}"
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
  echo "[entrypoint] preparing PostgreSQL standby"

  if [ -s "${PGDATA}/PG_VERSION" ]; then
    echo "[entrypoint] PostgreSQL standby already initialized"
    return
  fi

  rm -rf "${PGDATA}"
  mkdir -p "${PGDATA}"
  chown -R postgres:postgres "${PGDATA}"

  export PGPASSWORD="${PG_PRIMARY_PASSWORD}"

  su -s /bin/sh postgres -c "
    ${PGBIN}/pg_basebackup \
      -h '${PG_PRIMARY_HOST}' \
      -p '${PG_PRIMARY_PORT}' \
      -U '${PG_PRIMARY_USER}' \
      -D '${PGDATA}' \
      -Fp \
      -Xs \
      -P \
      -R
  "
}

start_postgres() {
  echo "[entrypoint] starting PostgreSQL standby"

  su -s /bin/sh postgres -c "${PGBIN}/pg_ctl -D '${PGDATA}' -o '-c port=${PGPORT} -c listen_addresses=0.0.0.0' -w start >/dev/null"
  PG_READY=1
}

wait_postgres() {
  echo "[entrypoint] waiting for PostgreSQL standby"

  i=0
  until pg_isready -h 127.0.0.1 -p "${PGPORT}" >/dev/null 2>&1; do
    i=$((i + 1))
    if [ "${i}" -ge 60 ]; then
      echo "[entrypoint] PostgreSQL did not become ready"
      exit 1
    fi
    sleep 1
  done
}

postgres_is_in_recovery() {
  su -s /bin/sh postgres -c "psql -h 127.0.0.1 -p '${PGPORT}' -d postgres -tAc 'SELECT pg_is_in_recovery()'" | grep -qx t
}

wait_postgres_replica() {
  echo "[entrypoint] checking PostgreSQL standby state"

  i=0
  while ! postgres_is_in_recovery; do
    i=$((i + 1))
    if [ "${i}" -ge 30 ]; then
      echo "[entrypoint] PostgreSQL is not in recovery mode"
      exit 1
    fi
    sleep 1
  done

  echo "[entrypoint] PostgreSQL standby is running"
}

main_loop() {
  while :; do
    if ! kill -0 "${MYSQL_PID}" 2>/dev/null; then
      echo "[entrypoint] MariaDB exited"
      return 1
    fi

    if ! mariadb-admin --socket="${MYSQL_SOCKET}" -uroot -p"${MYSQL_ROOT_PASSWORD}" ping >/dev/null 2>&1; then
      echo "[entrypoint] MariaDB health check failed"
      return 1
    fi

    if ! pg_isready -h 127.0.0.1 -p "${PGPORT}" >/dev/null 2>&1; then
      echo "[entrypoint] PostgreSQL health check failed"
      return 1
    fi

    sleep 5
  done
}

echo "[entrypoint] starting kea-backups setup"

wait_for_host_port "${MYSQL_PRIMARY_HOST}" "${MYSQL_PRIMARY_PORT}" "MariaDB primary"
wait_for_host_port "${PG_PRIMARY_HOST}" "${PG_PRIMARY_PORT}" "PostgreSQL primary"

init_mysql_datadir
start_mysql
configure_mysql_root
configure_mysql_replica
wait_mysql_replica

prepare_postgres_dirs
init_postgres_standby
start_postgres
wait_postgres
wait_postgres_replica

echo "[entrypoint] replica services are up"
main_loop