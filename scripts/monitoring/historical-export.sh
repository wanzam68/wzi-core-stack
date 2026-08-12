#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.5.0
# Historical Telemetry Exporter
#
# Initial contract:
#   Range          : 24 hours
#   Bucket size    : 5 minutes
#   Output         : history.json
#   Database       : wzi_saas / operations schema
#   Security       : sanitized JSON only
# ==========================================================

set -Eeuo pipefail

PROJECT_ROOT="/opt/wzi/core-stack"

POSTGRES_CONTAINER="wzi-postgres"
DATABASE="wzi_saas"

OUTPUT_DIR="${PROJECT_ROOT}/dashboard/storage/live"
OUTPUT_FILE="${OUTPUT_DIR}/history.json"

TEMP_SQL="$(mktemp)"
TEMP_JSON="$(mktemp)"

RANGE_NAME="24h"
RANGE_INTERVAL="24 hours"
BUCKET_INTERVAL="5 minutes"
BUCKET_SECONDS=300

cleanup() {
    rm -f "$TEMP_SQL" "$TEMP_JSON"
}

trap cleanup EXIT

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

error() {
    echo "[ERROR] $1" >&2
}

info() {
    echo "[INFO] $1"
}

# ----------------------------------------------------------
# Pre-flight
# ----------------------------------------------------------

mkdir -p "$OUTPUT_DIR"
chmod 755 "$OUTPUT_DIR"

if ! docker inspect "$POSTGRES_CONTAINER" >/dev/null 2>&1; then
    error "PostgreSQL container unavailable."
    exit 1
fi

POSTGRES_RUNNING="$(
    docker inspect \
        --format='{{.State.Running}}' \
        "$POSTGRES_CONTAINER" \
        2>/dev/null
)"

if [[ "$POSTGRES_RUNNING" != "true" ]]; then
    error "PostgreSQL container is not running."
    exit 1
fi

# ----------------------------------------------------------
# Historical aggregation query
# ----------------------------------------------------------

cat > "$TEMP_SQL" <<SQL
WITH
params AS (
    SELECT
        NOW() AS range_to,
        NOW() - INTERVAL '${RANGE_INTERVAL}' AS range_from,
        INTERVAL '${BUCKET_INTERVAL}' AS bucket_interval
),

runs AS (
    SELECT
        r.*
    FROM operations.telemetry_runs r
    CROSS JOIN params p
    WHERE r.generated_at >= p.range_from
      AND r.generated_at <= p.range_to
),

run_buckets AS (
    SELECT
        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        ) AS bucket,
        MAX(
            CASE r.overall_status
                WHEN 'HEALTHY'  THEN 0
                WHEN 'WARNING'  THEN 1
                WHEN 'CRITICAL' THEN 2
                ELSE 3
            END
        ) AS severity
    FROM runs r
    CROSS JOIN params p
    GROUP BY 1
),

overall_bucket_summary AS (
    SELECT
        bucket,
        CASE severity
            WHEN 0 THEN 'HEALTHY'
            WHEN 1 THEN 'WARNING'
            WHEN 2 THEN 'CRITICAL'
            ELSE 'UNKNOWN'
        END AS status
    FROM run_buckets
),

latest_run AS (
    SELECT
        overall_status
    FROM runs
    ORDER BY generated_at DESC
    LIMIT 1
),

availability AS (
    SELECT
        CASE
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(
                (
                    COUNT(*) FILTER (
                        WHERE status <> 'CRITICAL'
                    )::numeric
                    /
                    COUNT(*)::numeric
                ) * 100,
                2
            )
        END AS availability_percent
    FROM overall_bucket_summary
),

host_bucket AS (
    SELECT
        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        ) AS bucket,

        ROUND(AVG(h.cpu_percent), 2) AS cpu_percent,
        ROUND(AVG(h.memory_percent), 2) AS memory_percent,
        ROUND(AVG(h.disk_percent), 2) AS disk_percent,
        ROUND(AVG(h.load_1), 2) AS load_1

    FROM runs r
    JOIN operations.host_metrics h
      ON h.telemetry_run_id = r.id
    CROSS JOIN params p
    GROUP BY 1
    ORDER BY 1
),

host_summary AS (
    SELECT
        ROUND(AVG(cpu_percent), 2) AS cpu_avg,
        ROUND(MAX(cpu_percent), 2) AS cpu_max,

        ROUND(AVG(memory_percent), 2) AS memory_avg,
        ROUND(MAX(memory_percent), 2) AS memory_max,

        ROUND(AVG(disk_percent), 2) AS disk_avg,
        ROUND(MAX(disk_percent), 2) AS disk_max,

        ROUND(MAX(load_1), 2) AS load_1_max
    FROM host_bucket
),

backup_bucket_raw AS (
    SELECT
        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        ) AS bucket,

        MAX(
            CASE b.status
                WHEN 'HEALTHY'  THEN 0
                WHEN 'WARNING'  THEN 1
                WHEN 'CRITICAL' THEN 2
                ELSE 3
            END
        ) AS severity,

        MAX(b.age_hours) AS age_hours

    FROM runs r
    JOIN operations.backup_history b
      ON b.telemetry_run_id = r.id
    CROSS JOIN params p
    GROUP BY 1
),

backup_bucket AS (
    SELECT
        bucket,

        CASE severity
            WHEN 0 THEN 'HEALTHY'
            WHEN 1 THEN 'WARNING'
            WHEN 2 THEN 'CRITICAL'
            ELSE 'UNKNOWN'
        END AS status,

        age_hours

    FROM backup_bucket_raw
    ORDER BY bucket
),

backup_summary AS (
    SELECT
        (
            SELECT status
            FROM backup_bucket
            ORDER BY bucket DESC
            LIMIT 1
        ) AS current_status,

        MAX(age_hours) AS max_age_hours

    FROM backup_bucket
),

ssl_bucket_raw AS (
    SELECT
        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        ) AS bucket,

        MAX(
            CASE s.status
                WHEN 'HEALTHY'  THEN 0
                WHEN 'WARNING'  THEN 1
                WHEN 'CRITICAL' THEN 2
                ELSE 3
            END
        ) AS severity,

        MIN(s.days_remaining) AS days_remaining

    FROM runs r
    JOIN operations.ssl_history s
      ON s.telemetry_run_id = r.id
    CROSS JOIN params p
    GROUP BY 1
),

ssl_bucket AS (
    SELECT
        bucket,

        CASE severity
            WHEN 0 THEN 'HEALTHY'
            WHEN 1 THEN 'WARNING'
            WHEN 2 THEN 'CRITICAL'
            ELSE 'UNKNOWN'
        END AS status,

        days_remaining

    FROM ssl_bucket_raw
    ORDER BY bucket
),

ssl_summary AS (
    SELECT
        (
            SELECT status
            FROM ssl_bucket
            ORDER BY bucket DESC
            LIMIT 1
        ) AS current_status,

        MIN(days_remaining) AS minimum_days_remaining

    FROM ssl_bucket
),

service_bucket_raw AS (
    SELECT
        sh.service_name,

        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        ) AS bucket,

        MAX(
            CASE sh.status
                WHEN 'HEALTHY'  THEN 0
                WHEN 'WARNING'  THEN 1
                WHEN 'CRITICAL' THEN 2
                ELSE 3
            END
        ) AS severity,

        MAX(COALESCE(sh.restart_count, 0)) AS restart_count

    FROM runs r
    JOIN operations.service_health sh
      ON sh.telemetry_run_id = r.id
    CROSS JOIN params p
    GROUP BY
        sh.service_name,
        date_bin(
            p.bucket_interval,
            r.generated_at,
            TIMESTAMPTZ '2000-01-01 00:00:00+00'
        )
),

service_bucket AS (
    SELECT
        service_name,
        bucket,

        CASE severity
            WHEN 0 THEN 'HEALTHY'
            WHEN 1 THEN 'WARNING'
            WHEN 2 THEN 'CRITICAL'
            ELSE 'UNKNOWN'
        END AS status,

        restart_count

    FROM service_bucket_raw
),

service_json AS (
    SELECT
        service_name,

        jsonb_agg(
            jsonb_build_object(
                'timestamp',
                to_char(
                    bucket AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                ),
                'status',
                status,
                'restart_count',
                restart_count
            )
            ORDER BY bucket
        ) AS points

    FROM service_bucket
    GROUP BY service_name
),

service_object AS (
    SELECT
        COALESCE(
            jsonb_object_agg(service_name, points),
            '{}'::jsonb
        ) AS services
    FROM service_json
),

host_series AS (
    SELECT
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'timestamp',
                    to_char(
                        bucket AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                    ),
                    'cpu_percent',
                    cpu_percent,
                    'memory_percent',
                    memory_percent,
                    'disk_percent',
                    disk_percent,
                    'load_1',
                    load_1
                )
                ORDER BY bucket
            ),
            '[]'::jsonb
        ) AS points
    FROM host_bucket
),

backup_series AS (
    SELECT
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'timestamp',
                    to_char(
                        bucket AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                    ),
                    'status',
                    status,
                    'age_hours',
                    age_hours
                )
                ORDER BY bucket
            ),
            '[]'::jsonb
        ) AS points
    FROM backup_bucket
),

ssl_series AS (
    SELECT
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'timestamp',
                    to_char(
                        bucket AT TIME ZONE 'UTC',
                        'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                    ),
                    'status',
                    status,
                    'days_remaining',
                    days_remaining
                )
                ORDER BY bucket
            ),
            '[]'::jsonb
        ) AS points
    FROM ssl_bucket
),

run_stats AS (
    SELECT
        COUNT(*) AS source_rows
    FROM runs
),

returned_stats AS (
    SELECT
        COUNT(*) AS returned_points
    FROM host_bucket
),

final_document AS (
    SELECT
        jsonb_build_object(

            'schema_version', 1,

            'generated_at',
            to_char(
                NOW() AT TIME ZONE 'UTC',
                'YYYY-MM-DD"T"HH24:MI:SS"Z"'
            ),

            'range',
            jsonb_build_object(
                'name',
                '${RANGE_NAME}',

                'from',
                to_char(
                    p.range_from AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                ),

                'to',
                to_char(
                    p.range_to AT TIME ZONE 'UTC',
                    'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                ),

                'bucket_seconds',
                ${BUCKET_SECONDS},

                'source_rows',
                rs.source_rows,

                'returned_points',
                rts.returned_points
            ),

            'summary',
            jsonb_build_object(

                'overall_status',
                COALESCE(
                    (
                        SELECT overall_status
                        FROM latest_run
                    ),
                    'UNKNOWN'
                ),

                'availability_percent',
                a.availability_percent,

                'host',
                jsonb_build_object(
                    'cpu_avg',
                    hs.cpu_avg,
                    'cpu_max',
                    hs.cpu_max,
                    'memory_avg',
                    hs.memory_avg,
                    'memory_max',
                    hs.memory_max,
                    'disk_avg',
                    hs.disk_avg,
                    'disk_max',
                    hs.disk_max,
                    'load_1_max',
                    hs.load_1_max
                ),

                'backup',
                jsonb_build_object(
                    'current_status',
                    COALESCE(
                        bs.current_status,
                        'UNKNOWN'
                    ),
                    'max_age_hours',
                    bs.max_age_hours
                ),

                'ssl',
                jsonb_build_object(
                    'current_status',
                    COALESCE(
                        ss.current_status,
                        'UNKNOWN'
                    ),
                    'minimum_days_remaining',
                    ss.minimum_days_remaining
                )
            ),

            'series',
            jsonb_build_object(

                'host',
                hseries.points,

                'backup',
                bseries.points,

                'ssl',
                sseries.points,

                'services',
                jsonb_build_object(
                    'docker',
                    COALESCE(
                        so.services -> 'docker',
                        '[]'::jsonb
                    ),

                    'postgresql',
                    COALESCE(
                        so.services -> 'postgresql',
                        '[]'::jsonb
                    ),

                    'redis',
                    COALESCE(
                        so.services -> 'redis',
                        '[]'::jsonb
                    ),

                    'n8n',
                    COALESCE(
                        so.services -> 'n8n',
                        '[]'::jsonb
                    ),

                    'caddy',
                    COALESCE(
                        so.services -> 'caddy',
                        '[]'::jsonb
                    ),

                    'dashboard',
                    COALESCE(
                        so.services -> 'dashboard',
                        '[]'::jsonb
                    )
                )
            )
        ) AS document

    FROM params p
    CROSS JOIN run_stats rs
    CROSS JOIN returned_stats rts
    CROSS JOIN availability a
    CROSS JOIN host_summary hs
    CROSS JOIN backup_summary bs
    CROSS JOIN ssl_summary ss
    CROSS JOIN host_series hseries
    CROSS JOIN backup_series bseries
    CROSS JOIN ssl_series sseries
    CROSS JOIN service_object so
)

SELECT document
FROM final_document;
SQL

# ----------------------------------------------------------
# Execute query
# ----------------------------------------------------------

if ! docker exec -i "$POSTGRES_CONTAINER" \
    sh -c 'psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d wzi_saas' \
    < "$TEMP_SQL" \
    > "$TEMP_JSON"
then
    error "Historical telemetry query failed."
    exit 1
fi

# ----------------------------------------------------------
# Validate generated JSON
# ----------------------------------------------------------

if [[ ! -s "$TEMP_JSON" ]]; then
    error "Historical JSON output is empty."
    exit 1
fi

if ! python3 -m json.tool "$TEMP_JSON" >/dev/null 2>&1; then
    error "Historical JSON validation failed."
    exit 1
fi

# ----------------------------------------------------------
# Contract validation
# ----------------------------------------------------------

if ! python3 - "$TEMP_JSON" <<'PY'
import json
import sys

path = sys.argv[1]

with open(path) as f:
    d = json.load(f)

required_top = {
    "schema_version",
    "generated_at",
    "range",
    "summary",
    "series",
}

missing = required_top - set(d)

if missing:
    raise SystemExit(
        "Missing top-level fields: " + ", ".join(sorted(missing))
    )

if d.get("schema_version") != 1:
    raise SystemExit("Unexpected schema_version")

range_data = d.get("range", {})

for key in (
    "name",
    "from",
    "to",
    "bucket_seconds",
    "source_rows",
    "returned_points",
):
    if key not in range_data:
        raise SystemExit(f"Missing range field: {key}")

series = d.get("series", {})

for key in (
    "host",
    "backup",
    "ssl",
    "services",
):
    if key not in series:
        raise SystemExit(f"Missing series: {key}")

services = series.get("services", {})

for service in (
    "docker",
    "postgresql",
    "redis",
    "n8n",
    "caddy",
    "dashboard",
):
    if service not in services:
        raise SystemExit(
            f"Missing service series: {service}"
        )

print("Historical JSON contract validated.")
PY
then
    error "Historical API contract validation failed."
    exit 1
fi

# ----------------------------------------------------------
# Atomic publish
# ----------------------------------------------------------

chmod 644 "$TEMP_JSON"

mv "$TEMP_JSON" "$OUTPUT_FILE"

# TEMP_JSON was moved, so prevent cleanup from caring about it.
TEMP_JSON=""

info "Historical telemetry export completed."
info "Output: $OUTPUT_FILE"

python3 - "$OUTPUT_FILE" <<'PY'
import json
import sys

with open(sys.argv[1]) as f:
    d = json.load(f)

print("Range            :", d["range"]["name"])
print("Source rows      :", d["range"]["source_rows"])
print("Returned points  :", d["range"]["returned_points"])
print("Overall status   :", d["summary"]["overall_status"])
print("Availability     :", str(d["summary"]["availability_percent"]) + "%")
print("Host points      :", len(d["series"]["host"]))
print("Backup points    :", len(d["series"]["backup"]))
print("SSL points       :", len(d["series"]["ssl"]))

for name, points in d["series"]["services"].items():
    print(
        f"Service {name:<10}:",
        len(points),
        "points"
    )
PY

exit 0
