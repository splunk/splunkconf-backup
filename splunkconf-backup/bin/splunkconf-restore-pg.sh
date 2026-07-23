#!/bin/bash
# Restore Splunk embedded PostgreSQL before splunkd starts.
# Uses postgres_admin credentials from restored passwords.conf (ETC backup).
# Does NOT start splunkd — only postgres (pg_ctl) for dump restore, or
# pgBackRest for offline physical restore when configured.

VERSION="20260717a"

###### BEGIN default parameters 
# dont change here, use the configuration file to override them

# Note : we can be called either from splunk via a input or via direct call 
# get script dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR/.."
SPLUNK_HOME="$(cd ../../..; pwd)"

unset LD_LIBRARY_PATH
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/bin
umask 027

ID=$(date '+%s')
TODAY=$(date '+%Y%m%d-%H%M%Z_%u')
PG_SQL_PORT=5432
PG_ADMIN_USER="postgres_admin"
PG_RESTORE_DIR="${SPLUNK_HOME}/var/run/splunkconf-backup/pg/restore"
PG_RESTORE_LOG="${SPLUNK_HOME}/var/log/splunk/splunkconf-pg-restore.log"
PG_BACKUP_METHOD="sidecar"
PGBACKREST_CONFIG="${SPLUNK_HOME}/etc/apps/splunkconf-backup/default/pgbackrest.conf"
PGBACKREST_STANZA="splunk"
PGBACKREST_CMD="pgbackrest"

function echo_log_ext {
  echo "$(date '+%m-%d-%Y %H:%M:%S.%3N %z') splunkconf-restore-pg INFO id=${ID} $1"
}

function echo_log { echo_log_ext "$1"; }
function fail_log { echo_log_ext "FAIL id=${ID} $1"; }
function warn_log { echo_log_ext "WARN id=${ID} $1"; }
function debug_log { echo_log_ext "DEBUG id=${ID} $1"; }

function load_settings_from_file () {
  local FI="$1"
  local regclass2="^(#|\[)"
  if [ ! -e "$FI" ]; then
    return 0
  fi
  while read -r line; do
    if [[ "${line}" =~ $regclass2 ]] || [ -z "${line}" ]; then
      continue
    elif [[ $(echo "$line" | sed -nE 's/([a-zA-Z0-9_]+)\s*=\s*"?([a-zA-Z0-9_:\/\.\-\,]+)"?/\1 \2/p') ]]; then
      read -r var_name var_value <<< "$(echo "$line" | sed -nE 's/([a-zA-Z0-9_]+)\s*=\s*"?([a-zA-Z0-9_:\/\.\-\,]+)"?/\1 \2/p')"
      var_value2=$(echo "$var_value" | sed 's/"$//')
      declare -g "$var_name=${var_value2}"
    fi
  done < "$FI"
}


function get_pg_admin_pass () {
  local stanza="credential:postgres:postgres_admin:"
  local obfuscated
  obfuscated=$("${SPLUNK_HOME}/bin/splunk" btool passwords list "$stanza" 2>/dev/null | grep "password =" | awk '{print $3}')
  if [ -z "$obfuscated" ]; then
    return 1
  fi
  PG_ADMIN_PASS=$("${SPLUNK_HOME}/bin/splunk" show-decrypted --value "$obfuscated" 2>/dev/null)
  if [ $? -ne 0 ] || [ -z "$PG_ADMIN_PASS" ]; then
    PG_ADMIN_PASS=""
    return 1
  fi
  return 0
}

function find_pgdata () {
  local candidate
  PGDATA=""
  if [ -n "${PGBACKREST_PGDATA+x}" ] && [ -f "${PGBACKREST_PGDATA}/PG_VERSION" ]; then
    PGDATA="${PGBACKREST_PGDATA}"
    return 0
  fi
  for candidate in \
    "${SPLUNK_HOME}/var/packages/data/postgres/data" \
    "${SPLUNK_HOME}/var/packages/data/postgres/pgdata" \
    "${SPLUNK_HOME}/var/packages/data/postgres"; do
    if [ -f "${candidate}/PG_VERSION" ]; then
      PGDATA="${candidate}"
      return 0
    fi
  done
  candidate=$(find "${SPLUNK_HOME}/var/packages/data/postgres" -name PG_VERSION 2>/dev/null | head -n 1)
  if [ -n "$candidate" ]; then
    PGDATA=$(dirname "$candidate")
    return 0
  fi
  return 1
}

function ensure_pgdata () {
  if find_pgdata; then
    echo_log "action=restorebackup type=local object=pg result=running reason=pgdatafound dir=${PGDATA}"
    return 0
  fi
  PGDATA="${SPLUNK_HOME}/var/packages/data/postgres/data"
  mkdir -p "$(dirname "${PGDATA}")"
  if [ ! -x "${SPLUNK_HOME}/bin/initdb" ]; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=initdbmissing dir=${PGDATA}"
    return 1
  fi
  echo_log "action=restorebackup type=local object=pg result=running reason=initpgdata dir=${PGDATA}"
  export LD_LIBRARY_PATH="${SPLUNK_HOME}/lib"
  "${SPLUNK_HOME}/bin/initdb" -D "${PGDATA}" -U "${PG_ADMIN_USER}" --auth-local=trust --auth-host=scram-sha-256 >/dev/null 2>&1
  if [ ! -f "${PGDATA}/PG_VERSION" ]; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=initdbfailed dir=${PGDATA}"
    return 1
  fi
  return 0
}

function postgres_is_running () {
  export LD_LIBRARY_PATH="${SPLUNK_HOME}/lib"
  export PGPASSWORD="${PG_ADMIN_PASS}"
  "${SPLUNK_HOME}/bin/psql" -h localhost -d postgres -U "${PG_ADMIN_USER}" -p "${PG_SQL_PORT}" \
    -tAc "SELECT 1" >/dev/null 2>&1
}

function start_postgres_standalone () {
  export LD_LIBRARY_PATH="${SPLUNK_HOME}/lib"
  if postgres_is_running; then
    echo_log "action=restorebackup type=local object=pg result=running reason=postgresalreadyup"
    return 0
  fi
  if [ ! -x "${SPLUNK_HOME}/bin/pg_ctl" ]; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=pgctlmissing"
    return 1
  fi
  mkdir -p "$(dirname "${PG_RESTORE_LOG}")"
  "${SPLUNK_HOME}/bin/pg_ctl" -D "${PGDATA}" -l "${PG_RESTORE_LOG}" -o "-p ${PG_SQL_PORT}" start -w >/dev/null 2>&1
  if ! postgres_is_running; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=pgstartfailed dir=${PGDATA}"
    return 1
  fi
  PG_STARTED=1
  echo_log "action=restorebackup type=local object=pg result=success reason=postgresstarted dir=${PGDATA}"
  return 0
}

function stop_postgres_standalone () {
  if [ "${PG_STARTED:-0}" -ne 1 ]; then
    return 0
  fi
  export LD_LIBRARY_PATH="${SPLUNK_HOME}/lib"
  "${SPLUNK_HOME}/bin/pg_ctl" -D "${PGDATA}" stop -m fast -w >/dev/null 2>&1 || true
  echo_log "action=restorebackup type=local object=pg result=success reason=postgresstopped dir=${PGDATA}"
}

function restore_pg_dumps () {
  local dump_file db_name db_exists
  local restored=0 failed=0

  if [ ! -x "${SPLUNK_HOME}/bin/pg_restore" ]; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=pgrestoremissing"
    return 1
  fi

  if [ -z "$(find "${PG_RESTORE_DIR}" -name '*.dump' -type f 2>/dev/null | head -n 1)" ]; then
    echo_log "action=restorebackup type=local object=pg result=noop reason=nodumpfiles dir=${PG_RESTORE_DIR}"
    return 0
  fi

  export LD_LIBRARY_PATH="${SPLUNK_HOME}/lib"
  export PGPASSWORD="${PG_ADMIN_PASS}"

  while IFS= read -r dump_file; do
    [ -z "$dump_file" ] && continue
    db_name=$(basename "$dump_file" .dump)
    db_exists=$("${SPLUNK_HOME}/bin/psql" -h localhost -d postgres -U "${PG_ADMIN_USER}" -p "${PG_SQL_PORT}" \
      -tAc "SELECT 1 FROM pg_database WHERE datname='${db_name}'" 2>/dev/null)
    if [ "$db_exists" != "1" ]; then
      "${SPLUNK_HOME}/bin/psql" -h localhost -d postgres -U "${PG_ADMIN_USER}" -p "${PG_SQL_PORT}" \
        -c "CREATE DATABASE \"${db_name}\"" >/dev/null 2>&1 || {
        fail_log "action=restorebackup type=local object=pg-db db=${db_name} result=failure reason=createdbfailed"
        failed=$((failed + 1))
        continue
      }
    fi
    if "${SPLUNK_HOME}/bin/pg_restore" -h localhost -p "${PG_SQL_PORT}" -U "${PG_ADMIN_USER}" \
      -d "${db_name}" --clean --if-exists --no-owner "${dump_file}" >>"${PG_RESTORE_LOG}" 2>&1; then
      echo_log "action=restorebackup type=local object=pg-db db=${db_name} result=success dest=${dump_file}"
      restored=$((restored + 1))
    else
      fail_log "action=restorebackup type=local object=pg-db db=${db_name} result=failure dest=${dump_file}"
      failed=$((failed + 1))
    fi
  done < <(find "${PG_RESTORE_DIR}" -name '*.dump' -type f 2>/dev/null | sort)

  echo_log "action=restorebackup type=local object=pg result=summary restored=${restored} failed=${failed}"
  [ "$failed" -eq 0 ] && [ "$restored" -gt 0 ]
}

function restore_pgbackrest () {
  local repo_archive="$1"
  if ! command -v "${PGBACKREST_CMD}" >/dev/null 2>&1; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=pgbackrestmissing cmd=${PGBACKREST_CMD}"
    return 1
  fi
  if [ ! -f "${PGBACKREST_CONFIG}" ]; then
    fail_log "action=restorebackup type=local object=pg result=failure reason=pgbackrestconfmissing file=${PGBACKREST_CONFIG}"
    return 1
  fi
  if [ -n "$repo_archive" ] && [ -f "$repo_archive" ]; then
    echo_log "action=restorebackup type=local object=pg result=running reason=extractpgbackrestarchive file=${repo_archive}"
    rm -rf "${PG_RESTORE_DIR}/pgbackrest-repo"
    mkdir -p "${PG_RESTORE_DIR}/pgbackrest-repo"
    tar -xf "$repo_archive" -C "${PG_RESTORE_DIR}/pgbackrest-repo"
  fi
  "${PGBACKREST_CMD}" --config="${PGBACKREST_CONFIG}" --stanza="${PGBACKREST_STANZA}" restore --type=immediate --delta
  if [ $? -eq 0 ]; then
    echo_log "action=restorebackup type=local object=pg result=success method=pgbackrest stanza=${PGBACKREST_STANZA}"
    return 0
  fi
  fail_log "action=restorebackup type=local object=pg result=failure method=pgbackrest stanza=${PGBACKREST_STANZA}"
  return 1
}

# start 
# load settings from configuration files

load_settings_from_file "${SPLUNK_HOME}/etc/apps/splunkconf-backup/default/splunkconf-backup.conf"
load_settings_from_file "${SPLUNK_HOME}/etc/apps/splunkconf-backup/local/splunkconf-backup.conf"

if [ -z "${PGBACKREST_CONFIG}" ]; then
  PGBACKREST_CONFIG="${SPLUNK_HOME}/etc/apps/splunkconf-backup/default/pgbackrest.conf"
fi


PG_STARTED=0
ARCHIVE_PATH="${1:-}"

echo_log "action=restorebackup type=local object=pg result=running method=${PG_BACKUP_METHOD} splunkstarted=no"

if [ -z "${PG_BACKUP_METHOD}" ]; then
  PG_BACKUP_METHOD="sidecar"
fi

case "${PG_BACKUP_METHOD}" in
  pgbackrest)
    restore_pgbackrest "${ARCHIVE_PATH}"
    exit $?
    ;;
  sidecar|dump|*)
    if [ -n "${ARCHIVE_PATH}" ] && [ -f "${ARCHIVE_PATH}" ]; then
      rm -rf "${PG_RESTORE_DIR}"
      mkdir -p "${PG_RESTORE_DIR}"
      tar -xf "${ARCHIVE_PATH}" -C "${PG_RESTORE_DIR}"
    fi
    if ! get_pg_admin_pass; then
      fail_log "action=restorebackup type=local object=pg result=failure reason=nopgcredentialfound stanza=credential:postgres:postgres_admin:"
      exit 1
    fi
    if ! ensure_pgdata; then
      exit 1
    fi
    if ! start_postgres_standalone; then
      exit 1
    fi
    RESTORE_OK=0
    restore_pg_dumps && RESTORE_OK=1
    stop_postgres_standalone
    if [ "$RESTORE_OK" -eq 1 ]; then
      echo_log "action=restorebackup type=local object=pg result=success method=pgrestore prestart=yes"
      exit 0
    fi
    fail_log "action=restorebackup type=local object=pg result=failure method=pgrestore prestart=yes"
    exit 1
    ;;
esac
