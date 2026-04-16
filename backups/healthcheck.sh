#!/bin/sh
set -eu

check_standby() {
  port="$1"

  pg_isready -h 127.0.0.1 -p "${port}" -U postgres -d postgres >/dev/null 2>&1
  psql -h 127.0.0.1 -p "${port}" -U postgres -d postgres -tAc 'SELECT pg_is_in_recovery()' | grep -qx t
}

check_standby 5432
check_standby 5433
