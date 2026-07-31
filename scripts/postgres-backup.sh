#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

STACK_DIR="/opt/wzi/core-stack"
BACKUP_ROOT="/opt/wzi/backups/postgres"
RETENTION_DAYS=14
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

cd "$STACK_DIR"

set -a
source .env
set +a

POSTGRES_USER="${POSTGRES_USER:?POSTGRES_USER is missing from .env}"

mkdir -p "$RUN_DIR"

cleanup_on_error() {
  find "$RUN_DIR" -type f -name '*.tmp' -delete 2>/dev/null || true
}

trap cleanup_on_error ERR

echo "Discovering application databases..."

mapfile -t DATABASES < <(
  ./scripts/wzi-compose exec -T postgres \
    psql \
      --username="$POSTGRES_USER" \
      --dbname=postgres \
      --tuples-only \
      --no-align \
      --command="
        SELECT datname
        FROM pg_database
        WHERE datallowconn = true
          AND datistemplate = false
          AND datname <> 'postgres'
        ORDER BY datname;
      "
)

if (( ${#DATABASES[@]} == 0 )); then
  echo "ERROR: No application databases were found."
  exit 1
fi

printf 'Databases selected:\n'
printf ' - %s\n' "${DATABASES[@]}"

for DATABASE in "${DATABASES[@]}"; do
  [[ -n "$DATABASE" ]] || continue

  TEMP_FILE="${RUN_DIR}/${DATABASE}.dump.tmp"
  FINAL_FILE="${RUN_DIR}/${DATABASE}.dump"

  echo "Backing up database: $DATABASE"

  ./scripts/wzi-compose exec -T postgres \
    pg_dump \
      --username="$POSTGRES_USER" \
      --dbname="$DATABASE" \
      --format=custom \
      --no-owner \
      --no-privileges \
      > "$TEMP_FILE"

  if [[ ! -s "$TEMP_FILE" ]]; then
    echo "ERROR: Backup for $DATABASE is empty."
    exit 1
  fi

  mv "$TEMP_FILE" "$FINAL_FILE"

  (
    cd "$RUN_DIR"
    sha256sum "${DATABASE}.dump" > "${DATABASE}.dump.sha256"
  )
done

{
  echo "WZI PostgreSQL backup"
  echo "Timestamp UTC: $TIMESTAMP"
  echo "PostgreSQL user: $POSTGRES_USER"
  echo "Databases:"
  printf ' - %s\n' "${DATABASES[@]}"
} > "${RUN_DIR}/MANIFEST.txt"

find "$BACKUP_ROOT" \
  -mindepth 1 \
  -maxdepth 1 \
  -type d \
  -mtime +"$RETENTION_DAYS" \
  -exec rm -rf {} +

find "$BACKUP_ROOT" \
  -maxdepth 1 \
  -type f \
  \( -name '*.dump' -o -name '*.sha256' -o -name '*.tmp' \) \
  -mtime +"$RETENTION_DAYS" \
  -delete

echo
echo "Backup completed successfully:"
echo "$RUN_DIR"
