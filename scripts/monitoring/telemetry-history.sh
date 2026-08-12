#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.5.0
# Historical Telemetry Writer
#
# Properties:
#   - Idempotent by generated_at
#   - Atomic parent/child transaction
#   - Duplicate snapshots are harmless
#   - Optional snapshot path for testing
# ==========================================================

set -Eeuo pipefail

PROJECT_ROOT="/opt/wzi/core-stack"
DEFAULT_SNAPSHOT="${PROJECT_ROOT}/dashboard/storage/live/status.json"

SNAPSHOT="${1:-$DEFAULT_SNAPSHOT}"

POSTGRES_CONTAINER="wzi-postgres"
DATABASE="wzi_saas"

TEMP_SQL="$(mktemp)"

cleanup() {
    rm -f "$TEMP_SQL"
}

trap cleanup EXIT

# ----------------------------------------------------------
# Pre-flight
# ----------------------------------------------------------

if [[ ! -r "$SNAPSHOT" ]]; then
    echo "[ERROR] Telemetry snapshot unavailable: $SNAPSHOT" >&2
    exit 1
fi

if ! docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    echo "[ERROR] PostgreSQL container unavailable." >&2
    exit 1
fi

# ----------------------------------------------------------
# Validate JSON and obtain generated_at
# ----------------------------------------------------------

GENERATED_AT="$(
python3 - "$SNAPSHOT" <<'PY'
import json
import sys
from datetime import datetime

path = sys.argv[1]

try:
    with open(path) as f:
        d = json.load(f)

    generated = d.get("generated_at")

    if not isinstance(generated, str) or not generated:
        raise ValueError("generated_at missing")

    datetime.fromisoformat(generated.replace("Z", "+00:00"))

    print(generated)

except Exception as exc:
    print(f"ERROR:{exc}")
    raise SystemExit(1)
PY
)"

if [[ ! "$GENERATED_AT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    echo "[ERROR] Invalid generated_at value." >&2
    exit 1
fi

# ----------------------------------------------------------
# Fast duplicate check
# ----------------------------------------------------------

EXISTS="$(
docker exec "$POSTGRES_CONTAINER" \
    sh -c "psql -X -qAt \
        -v ON_ERROR_STOP=1 \
        -U \"\$POSTGRES_USER\" \
        -d '$DATABASE' \
        -c \"SELECT EXISTS (
            SELECT 1
            FROM operations.telemetry_runs
            WHERE generated_at = '$GENERATED_AT'::timestamptz
        );\""
)"

if [[ "$EXISTS" == "t" ]]; then
    echo "[INFO] Snapshot already stored; skipping."
    echo "Generated at: $GENERATED_AT"
    exit 0
fi

# ----------------------------------------------------------
# Generate one atomic SQL transaction
# ----------------------------------------------------------

python3 - "$SNAPSHOT" > "$TEMP_SQL" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path) as f:
    d = json.load(f)

def sql(value):
    if value is None:
        return "NULL"

    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"

    if isinstance(value, (int, float)):
        return str(value)

    value = str(value).replace("'", "''")

    return "'" + value + "'"

generated = d["generated_at"]

release_info = d.get("release_info", {})
services = d.get("services", {})
host = d.get("host", {})
backup = d.get("backup", {})
ssl = d.get("ssl", {})

print("BEGIN;")

# Parent
print(f"""
INSERT INTO operations.telemetry_runs (
    generated_at,
    environment,
    release_version,
    overall_status,
    latest_run,
    branch,
    commit_hash
)
VALUES (
    {sql(generated)}::timestamptz,
    {sql(d.get("environment", "Unknown"))},
    {sql(d.get("release"))},
    {sql(d.get("overall_status", "UNKNOWN"))},
    {sql(d.get("latest_run"))},
    {sql(release_info.get("branch"))},
    {sql(release_info.get("commit"))}
)
ON CONFLICT (generated_at) DO NOTHING;
""")

# Services
for name, service in services.items():
    print(f"""
INSERT INTO operations.service_health (
    telemetry_run_id,
    service_name,
    status,
    restart_count
)
SELECT
    id,
    {sql(name)},
    {sql(service.get("status", "UNKNOWN"))},
    {sql(service.get("restart_count"))}
FROM operations.telemetry_runs
WHERE generated_at = {sql(generated)}::timestamptz
ON CONFLICT (telemetry_run_id, service_name) DO NOTHING;
""")

# Host
print(f"""
INSERT INTO operations.host_metrics (
    telemetry_run_id,
    cpu_percent,
    memory_percent,
    disk_percent,
    disk_available,
    load_1,
    load_5,
    load_15,
    uptime
)
SELECT
    id,
    {sql(host.get("cpu_percent"))},
    {sql(host.get("memory_percent"))},
    {sql(host.get("disk_percent"))},
    {sql(host.get("disk_available"))},
    {sql(host.get("load_1"))},
    {sql(host.get("load_5"))},
    {sql(host.get("load_15"))},
    {sql(host.get("uptime"))}
FROM operations.telemetry_runs
WHERE generated_at = {sql(generated)}::timestamptz
ON CONFLICT (telemetry_run_id) DO NOTHING;
""")

# Backup
print(f"""
INSERT INTO operations.backup_history (
    telemetry_run_id,
    status,
    age_hours,
    backup_size
)
SELECT
    id,
    {sql(backup.get("status", "UNKNOWN"))},
    {sql(backup.get("age_hours"))},
    {sql(backup.get("size"))}
FROM operations.telemetry_runs
WHERE generated_at = {sql(generated)}::timestamptz
ON CONFLICT (telemetry_run_id) DO NOTHING;
""")

# SSL
print(f"""
INSERT INTO operations.ssl_history (
    telemetry_run_id,
    status,
    hostname,
    days_remaining,
    expires_at
)
SELECT
    id,
    {sql(ssl.get("status", "UNKNOWN"))},
    {sql(ssl.get("hostname"))},
    {sql(ssl.get("days_remaining"))},
    {sql(ssl.get("expires_at"))}
FROM operations.telemetry_runs
WHERE generated_at = {sql(generated)}::timestamptz
ON CONFLICT (telemetry_run_id) DO NOTHING;
""")

print("COMMIT;")
PY

# ----------------------------------------------------------
# Execute transaction
# ----------------------------------------------------------

if ! docker exec -i "$POSTGRES_CONTAINER" \
    sh -c 'psql -X -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d wzi_saas' \
    < "$TEMP_SQL"
then
    echo "[ERROR] Historical telemetry transaction failed." >&2
    echo "[INFO] PostgreSQL transaction rolled back." >&2
    exit 1
fi

echo "Historical telemetry stored successfully."
echo "Generated at: $GENERATED_AT"

exit 0
