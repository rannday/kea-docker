#!/bin/sh
set -eu

check_standby() {
  name="$1"
  port="$2"

  if ! pg_isready -h 127.0.0.1 -p "${port}" -t 1 -U postgres -d postgres >/dev/null 2>&1; then
    echo "${name}: locally unavailable"
    return 1
  fi

  if ! state=$(PGCONNECT_TIMEOUT=2 psql -X -w -h 127.0.0.1 -p "${port}" -U postgres -d postgres -v ON_ERROR_STOP=1 -tAc "
    SELECT pg_is_in_recovery(),
           COALESCE((SELECT status FROM pg_stat_wal_receiver), 'disconnected'),
           COALESCE(pg_last_wal_receive_lsn()::text, 'unknown'),
           COALESCE(pg_last_wal_replay_lsn()::text, 'unknown');
  "); then
    echo "${name}: local SQL check failed"
    return 1
  fi

  case "${state}" in
    t\|*) ;;
    *)
      echo "${name}: not in recovery mode"
      return 1
      ;;
  esac

  details=${state#*|}
  receiver=${details%%|*}
  if [ "${receiver}" = "streaming" ]; then
    streaming="active"
  else
    streaming="${receiver}"
  fi
  positions=${details#*|}
  received=${positions%%|*}
  replayed=${positions#*|}
  echo "${name}: locally ready, streaming ${streaming}; recovery=true; receiver=${receiver}; receive_lsn=${received}; replay_lsn=${replayed}"
}

result=0
check_standby lease 5432 || result=1
check_standby shared 5433 || result=1
exit "${result}"
