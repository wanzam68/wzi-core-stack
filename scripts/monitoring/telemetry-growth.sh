#!/usr/bin/env bash

set -Eeuo pipefail

POSTGRES_CONTAINER="wzi-postgres"
DATABASE="wzi_saas"

WARNING_MB=500
CRITICAL_MB=1000

DB_BYTES="$(
docker exec "$POSTGRES_CONTAINER" \
  sh -c 'psql -U "$POSTGRES_USER" -d wzi_saas -Atc "
SELECT pg_database_size(current_database());
"'
)"

if [[ ! "$DB_BYTES" =~ ^[0-9]+$ ]]; then
    echo "[CRITICAL] Unable to determine database size."
    exit 2
fi

DB_MB=$((DB_BYTES / 1024 / 1024))

echo "=============================================="
echo "WZI Telemetry Database Growth Monitor"
echo "=============================================="
echo "Database size : ${DB_MB} MB"

if [ "$DB_MB" -ge "$CRITICAL_MB" ]; then
    echo "Overall Result: CRITICAL"
    exit 2
elif [ "$DB_MB" -ge "$WARNING_MB" ]; then
    echo "Overall Result: WARNING"
    exit 1
else
    echo "Overall Result: HEALTHY"
    exit 0
fi
