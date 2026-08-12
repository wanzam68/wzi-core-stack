#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.5.0
# Historical Telemetry Retention Engine
# ==========================================================

set -Eeuo pipefail

PROJECT_ROOT="/opt/wzi/core-stack"

POSTGRES_CONTAINER="wzi-postgres"
DATABASE="wzi_saas"

RETENTION_DAYS=90

MODE="${1:---dry-run}"

LOG_DIR="${PROJECT_ROOT}/logs"
LOG_FILE="${LOG_DIR}/telemetry-retention.log"

mkdir -p "$LOG_DIR"

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log() {
    local message="$1"

    echo "$message"

    printf '%s %s\n' \
        "$(timestamp)" \
        "$message" >> "$LOG_FILE"
}

case "$MODE" in
    --dry-run|--apply)
        ;;
    *)
        echo "Usage:"
        echo "  $0 --dry-run"
        echo "  $0 --apply"
        exit 2
        ;;
esac

# ----------------------------------------------------------
# PostgreSQL pre-flight
# ----------------------------------------------------------

if ! docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    log "[CRITICAL] PostgreSQL container unavailable."
    exit 2
fi

POSTGRES_RUNNING="$(
    docker inspect \
        --format='{{.State.Running}}' \
        "$POSTGRES_CONTAINER" 2>/dev/null
)"

if [[ "$POSTGRES_RUNNING" != "true" ]]; then
    log "[CRITICAL] PostgreSQL container is not running."
    exit 2
fi

# ----------------------------------------------------------
# Candidate count
# ----------------------------------------------------------

CANDIDATE_COUNT="$(
docker exec \
    -e WZI_RETENTION_DAYS="$RETENTION_DAYS" \
    "$POSTGRES_CONTAINER" \
    sh -c '
psql \
    -X \
    -qAt \
    -v ON_ERROR_STOP=1 \
    -U "$POSTGRES_USER" \
    -d wzi_saas <<SQL
SELECT COUNT(*)
FROM operations.telemetry_runs
WHERE generated_at <
      NOW() - make_interval(days => $WZI_RETENTION_DAYS);
SQL
'
)"

if [[ ! "$CANDIDATE_COUNT" =~ ^[0-9]+$ ]]; then
    log "[CRITICAL] Unable to determine retention candidate count."
    exit 2
fi

log "=============================================="
log "WZI Historical Telemetry Retention"
log "=============================================="
log "Mode           : ${MODE}"
log "Retention      : ${RETENTION_DAYS} days"
log "Expired runs   : ${CANDIDATE_COUNT}"

# ----------------------------------------------------------
# Dry-run mode
# ----------------------------------------------------------

if [[ "$MODE" == "--dry-run" ]]; then
    log "Result         : DRY RUN - no data deleted"
    exit 0
fi

# ----------------------------------------------------------
# Nothing to delete
# ----------------------------------------------------------

if [[ "$CANDIDATE_COUNT" -eq 0 ]]; then
    log "Result         : No expired telemetry detected"
    exit 0
fi

# ----------------------------------------------------------
# Backup safety gate
# ----------------------------------------------------------

BACKUP_MONITOR="${PROJECT_ROOT}/scripts/monitoring/backup-health.sh"

if [[ ! -x "$BACKUP_MONITOR" ]]; then
    log "[CRITICAL] Backup verification monitor unavailable."
    exit 2
fi

set +e

"$BACKUP_MONITOR" >/dev/null 2>&1
BACKUP_EXIT=$?

set -e

if [[ "$BACKUP_EXIT" -ne 0 ]]; then
    log "[CRITICAL] Backup safety gate failed."
    log "Retention deletion aborted."
    exit 2
fi

log "Backup safety  : PASSED"

# ----------------------------------------------------------
# Delete expired parent rows
#
# Child tables are removed automatically through:
# ON DELETE CASCADE
# ----------------------------------------------------------

DELETED_COUNT="$(
docker exec \
    -e WZI_RETENTION_DAYS="$RETENTION_DAYS" \
    "$POSTGRES_CONTAINER" \
    sh -c '
psql \
    -X \
    -qAt \
    -v ON_ERROR_STOP=1 \
    -U "$POSTGRES_USER" \
    -d wzi_saas <<SQL
BEGIN;

WITH deleted AS (
    DELETE FROM operations.telemetry_runs
    WHERE generated_at <
          NOW() - make_interval(days => $WZI_RETENTION_DAYS)
    RETURNING id
)
SELECT COUNT(*)
FROM deleted;

COMMIT;
SQL
'
)"

# BEGIN and COMMIT can appear around the numeric result.
DELETED_COUNT="$(
    printf '%s\n' "$DELETED_COUNT" |
    grep -E '^[0-9]+$' |
    tail -n 1
)"

if [[ ! "$DELETED_COUNT" =~ ^[0-9]+$ ]]; then
    log "[CRITICAL] Retention transaction result invalid."
    exit 2
fi

log "Deleted runs   : ${DELETED_COUNT}"
log "Child cleanup  : ON DELETE CASCADE"
log "Result         : SUCCESS"

exit 0
