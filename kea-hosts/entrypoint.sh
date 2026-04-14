#!/bin/sh
set -eu

MYSQL_HOST="127.0.0.1"
MYSQL_ROOT_PASSWORD="rootpass"
MYSQL_USER="kea"
MYSQL_PASSWORD="keapass"
MYSQL_DB="kea-hosts"
MYSQL_REPL_USER="repl"
MYSQL_REPL_PASSWORD="replpass"
MYSQL_DUMP_USER="backup"
MYSQL_DUMP_PASSWORD="backuppass"
MYSQL_BACKUP_HOST="192.168.69.69"

MYSQL_DATADIR="/var/lib/mysql"
MYSQL_RUN_DIR="/run/mysqld"
MYSQL_SOCKET="${MYSQL_RUN_DIR}/mysqld.sock"
MYSQL_PIDFILE="${MYSQL_RUN_DIR}/mysqld.pid"

MYSQL_PID=""

cleanup() {
  if [ -n "${MYSQL_PID}" ]; then
    kill "${MYSQL_PID}" 2>/dev/null || true
    wait "${MYSQL_PID}" 2>/dev/null || true
  fi
}
trap cleanup INT TERM

init_mysql_datadir() {
  echo "[init] preparing MariaDB datadir"

  mkdir -p "${MYSQL_DATADIR}" "${MYSQL_RUN_DIR}"
  chown -R mysql:mysql "${MYSQL_RUN_DIR}" "${MYSQL_DATADIR}"

  if [ -d "${MYSQL_DATADIR}/mysql" ]; then
    echo "[init] MariaDB system tables already present"
    return
  fi

  echo "[init] initializing MariaDB datadir"
  mariadb-install-db \
    --user=mysql \
    --datadir="${MYSQL_DATADIR}" \
    --auth-root-authentication-method=normal \
    --skip-test-db
}

start_mysql() {
  echo "[init] starting MariaDB"

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
      echo "[init] MariaDB did not become ready"
      exit 1
    fi
    sleep 1
  done

  echo "[init] MariaDB is ready"
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

configure_mysql() {
  echo "[init] configuring root/database/user"

  mysql_root_exec_stdin <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\`;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_REPL_USER}'@'${MYSQL_BACKUP_HOST}' IDENTIFIED BY '${MYSQL_REPL_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_DUMP_USER}'@'${MYSQL_BACKUP_HOST}' IDENTIFIED BY '${MYSQL_DUMP_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'%';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${MYSQL_REPL_USER}'@'${MYSQL_BACKUP_HOST}';
GRANT SELECT, SHOW VIEW, EVENT, TRIGGER, LOCK TABLES ON \`${MYSQL_DB}\`.* TO '${MYSQL_DUMP_USER}'@'${MYSQL_BACKUP_HOST}';
GRANT RELOAD, REPLICATION CLIENT ON *.* TO '${MYSQL_DUMP_USER}'@'${MYSQL_BACKUP_HOST}';
FLUSH PRIVILEGES;
SQL
}

mysql_db_exists() {
  mysql_root_exec -Nse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${MYSQL_DB}'" \
    | grep -qx "${MYSQL_DB}"
}

kea_schema_table_exists() {
  mysql_root_exec -Nse "
    SELECT TABLE_NAME
    FROM INFORMATION_SCHEMA.TABLES
    WHERE TABLE_SCHEMA='${MYSQL_DB}'
      AND TABLE_NAME='schema_version'
  " | grep -qx "schema_version"
}

kea_schema_ready() {
  kea-admin db-version mysql \
    -u "${MYSQL_USER}" \
    -p "${MYSQL_PASSWORD}" \
    -n "${MYSQL_DB}" \
    -h "${MYSQL_HOST}" >/dev/null 2>&1
}

kea_schema_version() {
  kea-admin db-version mysql \
    -u "${MYSQL_USER}" \
    -p "${MYSQL_PASSWORD}" \
    -n "${MYSQL_DB}" \
    -h "${MYSQL_HOST}"
}

require_kea_schema_version() {
  version="$(kea_schema_version)"

  if [ "${version}" != "30.0" ]; then
    echo "[init] unexpected Kea schema version: ${version}"
    exit 1
  fi
}

init_or_upgrade_kea_schema() {
  echo "[init] checking Kea schema"

  if kea_schema_ready; then
    echo "[init] Kea schema already present"
    return
  fi

  if ! mysql_db_exists; then
    echo "[init] database missing, creating Kea schema"
    kea-admin db-init mysql \
      -u "${MYSQL_USER}" \
      -p "${MYSQL_PASSWORD}" \
      -n "${MYSQL_DB}" \
      -h "${MYSQL_HOST}"
    return
  fi

  if ! kea_schema_table_exists; then
    echo "[init] schema_version table missing, initializing Kea schema"
    kea-admin db-init mysql \
      -u "${MYSQL_USER}" \
      -p "${MYSQL_PASSWORD}" \
      -n "${MYSQL_DB}" \
      -h "${MYSQL_HOST}"
    return
  fi

  echo "[init] existing Kea schema found but not current, upgrading"
  kea-admin db-upgrade mysql \
    -u "${MYSQL_USER}" \
    -p "${MYSQL_PASSWORD}" \
    -n "${MYSQL_DB}" \
    -h "${MYSQL_HOST}"
}

echo "[init] starting kea-hosts setup"
init_mysql_datadir
start_mysql
configure_mysql
init_or_upgrade_kea_schema
require_kea_schema_version

wait "${MYSQL_PID}"
