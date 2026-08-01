#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/utils.sh"

FAILED=0
WARNINGS=0

print_header "WZI PostgreSQL Health Monitor"

printf 'Timestamp : %s\n' "$(log_timestamp)"
printf 'Host      : %s\n' "$HOST_NAME"
printf 'Container : %s\n\n' "$POSTGRES_CONTAINER"

if ! container_exists "$POSTGRES_CONTAINER"; then
  print_error "PostgreSQL container was not found."
  log_message ERROR "PostgreSQL container not found: $POSTGRES_CONTAINER"
  exit 1
fi

STATUS="$(container_status "$POSTGRES_CONTAINER")"
HEALTH="$(container_health "$POSTGRES_CONTAINER")"
RESTARTS="$(container_restarts "$POSTGRES_CONTAINER")"

if [[ "$STATUS" == "running" ]]; then
  print_ok "Container status: $STATUS"
else
  print_error "Container status: $STATUS"
  FAILED=1
fi

if [[ "$HEALTH" == "healthy" ]]; then
  print_ok "Docker health: $HEALTH"
elif [[ "$HEALTH" == "not-configured" ]]; then
  print_warning "Docker health check is not configured."
  WARNINGS=$((WARNINGS + 1))
else
  print_error "Docker health: $HEALTH"
  FAILED=1
fi

if (( RESTARTS == 0 )); then
  print_ok "Container restart count: $RESTARTS"
else
  print_warning "Container restart count: $RESTARTS"
  WARNINGS=$((WARNINGS + 1))
fi

echo

if docker exec "$POSTGRES_CONTAINER" \
  pg_isready \
  --username="$POSTGRES_USER" \
  --dbname=postgres >/dev/null 2>&1; then
  print_ok "PostgreSQL accepts connections."
else
  print_error "PostgreSQL is not accepting connections."
  FAILED=1
fi

if VERSION="$(
  docker exec "$POSTGRES_CONTAINER" \
    psql \
      -P pager=off \
      --tuples-only \
      --no-align \
      --username="$POSTGRES_USER" \
      --dbname=postgres \
      --command='SELECT version();' 2>/dev/null
)"; then
  print_ok "Version: $VERSION"
else
  print_error "Unable to retrieve PostgreSQL version."
  FAILED=1
fi

if DATABASE_COUNT="$(
  docker exec "$POSTGRES_CONTAINER" \
    psql \
      -P pager=off \
      --tuples-only \
      --no-align \
      --username="$POSTGRES_USER" \
      --dbname=postgres \
      --command="
        SELECT COUNT(*)
        FROM pg_database
        WHERE datallowconn = true
          AND datistemplate = false;
      " 2>/dev/null
)"; then
  print_ok "Connectable databases: $DATABASE_COUNT"
else
  print_error "Unable to count databases."
  FAILED=1
fi

if ACTIVE_CONNECTIONS="$(
  docker exec "$POSTGRES_CONTAINER" \
    psql \
      -P pager=off \
      --tuples-only \
      --no-align \
      --username="$POSTGRES_USER" \
      --dbname=postgres \
      --command="
        SELECT COUNT(*)
        FROM pg_stat_activity
        WHERE backend_type = 'client backend';
      " 2>/dev/null
)"; then
  print_ok "Active client connections: $ACTIVE_CONNECTIONS"
else
  print_error "Unable to read active connections."
  FAILED=1
fi

echo
echo "Application database sizes:"

if ! docker exec "$POSTGRES_CONTAINER" \
  psql \
    -P pager=off \
    --username="$POSTGRES_USER" \
    --dbname=postgres \
    --command="
      SELECT
        datname AS database,
        pg_size_pretty(pg_database_size(datname)) AS size
      FROM pg_database
      WHERE datallowconn = true
        AND datistemplate = false
        AND datname <> 'postgres'
      ORDER BY datname;
    "; then
  print_error "Unable to retrieve database sizes."
  FAILED=1
fi

echo

if [[ -d "$BACKUP_ROOT" ]]; then
  LATEST_BACKUP_DIR="$(
    find "$BACKUP_ROOT" \
      -mindepth 1 \
      -maxdepth 1 \
      -type d \
      -printf '%T@ %p\n' 2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
  )"

  if [[ -n "$LATEST_BACKUP_DIR" ]]; then
    BACKUP_EPOCH="$(stat -c %Y "$LATEST_BACKUP_DIR")"
    BACKUP_AGE_HOURS="$(hours_since_epoch "$BACKUP_EPOCH")"

    if (( BACKUP_AGE_HOURS >= BACKUP_CRITICAL_HOURS )); then
      print_error "Latest backup is ${BACKUP_AGE_HOURS} hours old."
      FAILED=1
    elif (( BACKUP_AGE_HOURS >= BACKUP_WARNING_HOURS )); then
      print_warning "Latest backup is ${BACKUP_AGE_HOURS} hours old."
      WARNINGS=$((WARNINGS + 1))
    else
      print_ok "Latest backup age: ${BACKUP_AGE_HOURS} hours"
    fi

    printf 'Backup set: %s\n' "$LATEST_BACKUP_DIR"
  else
    print_error "No timestamped backup directory was found."
    FAILED=1
  fi
else
  print_error "Backup root does not exist: $BACKUP_ROOT"
  FAILED=1
fi

echo

if (( FAILED > 0 )); then
  RESULT="CRITICAL"
  EXIT_CODE=1
elif (( WARNINGS > 0 )); then
  RESULT="WARNING"
  EXIT_CODE=0
else
  RESULT="HEALTHY"
  EXIT_CODE=0
fi

echo "Overall Result: $RESULT"
log_message "$RESULT" \
  "PostgreSQL monitor completed; warnings=$WARNINGS failures=$FAILED"

exit "$EXIT_CODE"
