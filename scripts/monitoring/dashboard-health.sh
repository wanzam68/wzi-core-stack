#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.5.0
# Dashboard Health Monitor
# ==========================================================

set -u
set -o pipefail

CONTAINER="wzi-dashboard"
FRONTEND_URL="http://127.0.0.1:8088/"
API_URL="http://127.0.0.1:8088/api/status.php"
HISTORY_API_URL="http://127.0.0.1:8088/api/history.php"
CHARTJS_URL="http://127.0.0.1:8088/assets/vendor/chartjs/chart.umd.min.js"
EXPORT_TIMER="wzi-dashboard-export.timer"
HISTORICAL_TIMER="wzi-historical-export.timer"

WARNING_RESPONSE_MS=1500
WARNING_TELEMETRY_AGE=180
CRITICAL_TELEMETRY_AGE=300

HISTORICAL_WARNING_AGE=600
HISTORICAL_CRITICAL_AGE=900

FAILED=0
WARNINGS=0

TEMP_API="$(mktemp)"
TEMP_HISTORY="$(mktemp)"

cleanup() {
    rm -f "$TEMP_API" "$TEMP_HISTORY"
}

trap cleanup EXIT

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

ok() {
    echo "[OK]       $1"
}

warning() {
    echo "[WARNING]  $1"
    WARNINGS=$((WARNINGS + 1))
}

critical() {
    echo "[CRITICAL] $1"
    FAILED=$((FAILED + 1))
}

echo "=================================================="
echo "WZI Dashboard Health Monitor"
echo "=================================================="
echo "Timestamp : $(timestamp)"
echo "Host      : $(hostname)"
echo "Container : ${CONTAINER}"
echo

# ----------------------------------------------------------
# Required commands
# ----------------------------------------------------------

for cmd in docker curl python3 systemctl date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        critical "Required command unavailable: $cmd"
    fi
done

if (( FAILED > 0 )); then
    echo
    echo "Overall Result: CRITICAL"
    exit 2
fi

# ----------------------------------------------------------
# Container existence
# ----------------------------------------------------------

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
    critical "Dashboard container not found."
    echo
    echo "Overall Result: CRITICAL"
    exit 2
fi

ok "Dashboard container exists"

# ----------------------------------------------------------
# Container runtime state
# ----------------------------------------------------------

STATUS="$(
    docker inspect \
        --format='{{.State.Status}}' \
        "$CONTAINER" 2>/dev/null
)"

HEALTH="$(
    docker inspect \
        --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
        "$CONTAINER" 2>/dev/null
)"

RESTARTS="$(
    docker inspect \
        --format='{{.RestartCount}}' \
        "$CONTAINER" 2>/dev/null
)"

if [ "$STATUS" = "running" ]; then
    ok "Container status: $STATUS"
else
    critical "Container status: $STATUS"
fi

case "$HEALTH" in
    healthy)
        ok "Docker health: $HEALTH"
        ;;
    starting)
        warning "Docker health: $HEALTH"
        ;;
    none)
        warning "Docker healthcheck is not defined."
        ;;
    *)
        critical "Docker health: $HEALTH"
        ;;
esac

if [[ "$RESTARTS" =~ ^[0-9]+$ ]] && [ "$RESTARTS" -eq 0 ]; then
    ok "Container restart count: $RESTARTS"
else
    warning "Container restart count: $RESTARTS"
fi

echo

# ----------------------------------------------------------
# Frontend HTTP check
# ----------------------------------------------------------

FRONTEND_RESULT="$(
    curl \
        --silent \
        --show-error \
        --output /dev/null \
        --max-time 10 \
        --write-out '%{http_code} %{time_total}' \
        "$FRONTEND_URL" 2>/dev/null
)"

CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
    critical "Dashboard frontend request failed."
else
    FRONTEND_HTTP="$(awk '{print $1}' <<< "$FRONTEND_RESULT")"
    FRONTEND_TIME="$(awk '{print $2}' <<< "$FRONTEND_RESULT")"

    FRONTEND_MS="$(
        awk -v seconds="$FRONTEND_TIME" \
            'BEGIN { printf "%.0f", seconds * 1000 }'
    )"

    if [ "$FRONTEND_HTTP" = "200" ]; then
        ok "Frontend HTTP status: 200"
    else
        critical "Frontend HTTP status: $FRONTEND_HTTP"
    fi

    if [ "$FRONTEND_MS" -gt "$WARNING_RESPONSE_MS" ]; then
        warning "Frontend response time: ${FRONTEND_MS} ms"
    else
        ok "Frontend response time: ${FRONTEND_MS} ms"
    fi
fi

# ----------------------------------------------------------
# Page identity check
# ----------------------------------------------------------

FRONTEND_BODY="$(
    curl -fsS         --max-time 10         "$FRONTEND_URL"         2>/dev/null || true
)"

if grep -qF     "WZI Enterprise Operations Center"     <<< "$FRONTEND_BODY"
then
    ok "Expected dashboard page detected"
else
    critical "Expected dashboard page content not detected"
fi

echo

# ----------------------------------------------------------
# API check
# ----------------------------------------------------------

API_HTTP="$(
    curl \
        --silent \
        --show-error \
        --output "$TEMP_API" \
        --max-time 10 \
        --write-out '%{http_code}' \
        "$API_URL" 2>/dev/null
)"

API_CURL_EXIT=$?

if [ "$API_CURL_EXIT" -ne 0 ]; then
    critical "Monitoring API request failed."
elif [ "$API_HTTP" != "200" ]; then
    critical "Monitoring API HTTP status: $API_HTTP"
else
    ok "Monitoring API HTTP status: 200"
fi

# ----------------------------------------------------------
# JSON validation
# ----------------------------------------------------------

if python3 -m json.tool "$TEMP_API" >/dev/null 2>&1; then
    ok "Monitoring API returned valid JSON"
else
    critical "Monitoring API returned invalid JSON"
fi

# ----------------------------------------------------------
# API contract and telemetry freshness
# ----------------------------------------------------------

API_CHECK="$(
    python3 - "$TEMP_API" <<'PY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]

try:
    with open(path) as f:
        payload = json.load(f)

    if payload.get("ok") is not True:
        print("CONTRACT_ERROR")
        raise SystemExit

    data = payload.get("data")

    if not isinstance(data, dict):
        print("CONTRACT_ERROR")
        raise SystemExit

    generated = data.get("generated_at")

    if not generated:
        print("CONTRACT_ERROR")
        raise SystemExit

    generated_dt = datetime.fromisoformat(
        generated.replace("Z", "+00:00")
    )

    now = datetime.now(timezone.utc)
    age = int((now - generated_dt).total_seconds())

    print(f"OK {age}")

except Exception:
    print("CONTRACT_ERROR")
PY
)"

if [[ "$API_CHECK" == OK\ * ]]; then
    TELEMETRY_AGE="${API_CHECK#OK }"

    ok "Monitoring API contract validated"

    if [ "$TELEMETRY_AGE" -gt "$CRITICAL_TELEMETRY_AGE" ]; then
        critical "Telemetry is stale: ${TELEMETRY_AGE} seconds old"
    elif [ "$TELEMETRY_AGE" -gt "$WARNING_TELEMETRY_AGE" ]; then
        warning "Telemetry age: ${TELEMETRY_AGE} seconds"
    else
        ok "Telemetry age: ${TELEMETRY_AGE} seconds"
    fi
else
    critical "Monitoring API contract validation failed"
fi

echo

# ----------------------------------------------------------
# Historical API
# ----------------------------------------------------------

HISTORY_HTTP="$(
    curl \
        --silent \
        --show-error \
        --output "$TEMP_HISTORY" \
        --max-time 10 \
        --write-out '%{http_code}' \
        "$HISTORY_API_URL" 2>/dev/null
)"

HISTORY_CURL_EXIT=$?

if [ "$HISTORY_CURL_EXIT" -ne 0 ]; then
    critical "Historical API request failed."
elif [ "$HISTORY_HTTP" != "200" ]; then
    critical "Historical API HTTP status: $HISTORY_HTTP"
else
    ok "Historical API HTTP status: 200"
fi

# ----------------------------------------------------------
# Historical JSON validation
# ----------------------------------------------------------

if python3 -m json.tool "$TEMP_HISTORY" >/dev/null 2>&1; then
    ok "Historical API returned valid JSON"
else
    critical "Historical API returned invalid JSON"
fi

# ----------------------------------------------------------
# Historical API contract and freshness
# ----------------------------------------------------------

HISTORY_CHECK="$(
    python3 - "$TEMP_HISTORY" <<'PYHISTORY'
import json
import sys
from datetime import datetime, timezone

path = sys.argv[1]

try:
    with open(path) as f:
        payload = json.load(f)

    if payload.get("ok") is not True:
        print("CONTRACT_ERROR")
        raise SystemExit

    data = payload.get("data")

    if not isinstance(data, dict):
        print("CONTRACT_ERROR")
        raise SystemExit

    if data.get("schema_version") != 1:
        print("CONTRACT_ERROR")
        raise SystemExit

    generated = data.get("generated_at")
    range_data = data.get("range")
    summary = data.get("summary")
    series = data.get("series")

    if not generated:
        print("CONTRACT_ERROR")
        raise SystemExit

    if not isinstance(range_data, dict):
        print("CONTRACT_ERROR")
        raise SystemExit

    if not isinstance(summary, dict):
        print("CONTRACT_ERROR")
        raise SystemExit

    if not isinstance(series, dict):
        print("CONTRACT_ERROR")
        raise SystemExit

    required_series = {
        "host",
        "backup",
        "ssl",
        "services",
    }

    if not required_series.issubset(series):
        print("CONTRACT_ERROR")
        raise SystemExit

    generated_dt = datetime.fromisoformat(
        generated.replace("Z", "+00:00")
    )

    now = datetime.now(timezone.utc)
    age = int((now - generated_dt).total_seconds())

    print(f"OK {age}")

except Exception:
    print("CONTRACT_ERROR")
PYHISTORY
)"

if [[ "$HISTORY_CHECK" == OK\ * ]]; then
    HISTORY_AGE="${HISTORY_CHECK#OK }"

    ok "Historical API contract validated"

    if [ "$HISTORY_AGE" -gt "$HISTORICAL_CRITICAL_AGE" ]; then
        critical "Historical telemetry is stale: ${HISTORY_AGE} seconds old"
    elif [ "$HISTORY_AGE" -gt "$HISTORICAL_WARNING_AGE" ]; then
        warning "Historical telemetry age: ${HISTORY_AGE} seconds"
    else
        ok "Historical telemetry age: ${HISTORY_AGE} seconds"
    fi
else
    critical "Historical API contract validation failed"
fi

# ----------------------------------------------------------
# Chart.js asset
# ----------------------------------------------------------

CHARTJS_HTTP="$(
    curl \
        --silent \
        --output /dev/null \
        --max-time 10 \
        --write-out '%{http_code}' \
        "$CHARTJS_URL" 2>/dev/null
)"

if [ "$CHARTJS_HTTP" = "200" ]; then
    ok "Chart.js asset HTTP status: 200"
else
    critical "Chart.js asset HTTP status: $CHARTJS_HTTP"
fi

# ----------------------------------------------------------
# Historical exporter timer
# ----------------------------------------------------------

if systemctl is-active --quiet "$HISTORICAL_TIMER"; then
    ok "Historical exporter timer is active"
else
    critical "Historical exporter timer is inactive"
fi

if systemctl is-enabled --quiet "$HISTORICAL_TIMER"; then
    ok "Historical exporter timer is enabled"
else
    warning "Historical exporter timer is not enabled"
fi

echo

# ----------------------------------------------------------
# Exporter timer
# ----------------------------------------------------------

if systemctl is-active --quiet "$EXPORT_TIMER"; then
    ok "Telemetry exporter timer is active"
else
    critical "Telemetry exporter timer is inactive"
fi

if systemctl is-enabled --quiet "$EXPORT_TIMER"; then
    ok "Telemetry exporter timer is enabled"
else
    warning "Telemetry exporter timer is not enabled"
fi

# ----------------------------------------------------------
# Read-only telemetry mount
# ----------------------------------------------------------

MOUNT_RW="$(
    docker inspect "$CONTAINER" \
        --format='{{range .Mounts}}{{if eq .Destination "/var/www/dashboard-data"}}{{.RW}}{{end}}{{end}}' \
        2>/dev/null
)"

case "$MOUNT_RW" in
    false)
        ok "Telemetry data mount is read-only"
        ;;
    true)
        critical "Telemetry data mount is writable"
        ;;
    *)
        critical "Telemetry data mount was not found"
        ;;
esac

echo

# ----------------------------------------------------------
# Overall result
# ----------------------------------------------------------

if (( FAILED > 0 )); then
    echo "Overall Result: CRITICAL"
    exit 2
elif (( WARNINGS > 0 )); then
    echo "Overall Result: WARNING"
    exit 1
else
    echo "Overall Result: HEALTHY"
    exit 0
fi
