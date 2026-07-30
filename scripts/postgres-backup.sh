#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

STACK_DIR="/opt/wzi/core-stack"
BACKUP_DIR="/opt/wzi/backups/postgres"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
TEMP_FILE="$BACKUP_DIR/wzi_saas-$TIMESTAMP.dump.tmp"
FINAL_FILE="$BACKUP_DIR/wzi_saas-$TIMESTAMP.dump"

mkdir -p "$BACKUP_DIR"
cd "$STACK_DIR"

set -a
source .env
set +a

./scripts/wzi-compose exec -T postgres \
  pg_dump \
  --username="$POSTGRES_USER" \
  --dbname="$POSTGRES_DB" \
  --format=custom \
  --no-owner \
  --no-privileges \
  > "$TEMP_FILE"

test -s "$TEMP_FILE"
mv "$TEMP_FILE" "$FINAL_FILE"

sha256sum "$FINAL_FILE" > "$FINAL_FILE.sha256"

find "$BACKUP_DIR" -type f \
  \( -name '*.dump' -o -name '*.sha256' \) \
  -mtime +14 -delete

echo "Backup completed: $FINAL_FILE"
