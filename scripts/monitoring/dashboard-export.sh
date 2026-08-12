#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.5.0
# Dashboard Read-Only Data Exporter
# ==========================================================

set -u
set -o pipefail

PROJECT_ROOT="/opt/wzi/core-stack"
MONITORING_DIR="${PROJECT_ROOT}/scripts/monitoring"
LOG_ROOT="${PROJECT_ROOT}/logs"
STATE_FILE="${LOG_ROOT}/state/overall-status.state"

OUTPUT_DIR="${PROJECT_ROOT}/dashboard/storage/live"
OUTPUT_FILE="${OUTPUT_DIR}/status.json"
TEMP_FILE="${OUTPUT_FILE}.tmp"

mkdir -p "$OUTPUT_DIR"
chmod 755 "$OUTPUT_DIR"

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

json_escape() {
    python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().rstrip("\n")))'
}

service_status() {
    local container="$1"

    if ! docker inspect "$container" >/dev/null 2>&1; then
        printf '%s' "MISSING"
        return
    fi

    local running
    local health

    running="$(
        docker inspect \
            --format='{{.State.Running}}' \
            "$container" 2>/dev/null
    )"

    if [ "$running" != "true" ]; then
        printf '%s' "CRITICAL"
        return
    fi

    health="$(
        docker inspect \
            --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
            "$container" 2>/dev/null
    )"

    case "$health" in
        healthy|none)
            printf '%s' "HEALTHY"
            ;;
        starting)
            printf '%s' "WARNING"
            ;;
        *)
            printf '%s' "CRITICAL"
            ;;
    esac
}

restart_count() {
    docker inspect \
        --format='{{.RestartCount}}' \
        "$1" 2>/dev/null || printf '0'
}

# ----------------------------------------------------------
# Overall monitoring status
# ----------------------------------------------------------

OVERALL_STATUS="UNKNOWN"

if [ -s "$STATE_FILE" ]; then
    OVERALL_STATUS="$(
        head -n 1 "$STATE_FILE" |
        tr -d '\r\n'
    )"
fi

# ----------------------------------------------------------
# Latest monitoring run
# ----------------------------------------------------------

LATEST_RUN_DIR="$(
    find "${LOG_ROOT}/runs" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        2>/dev/null |
    sort |
    tail -n 1
)"

LATEST_RUN_ID="unknown"

if [ -n "$LATEST_RUN_DIR" ]; then
    LATEST_RUN_ID="$(basename "$LATEST_RUN_DIR")"
fi

# ----------------------------------------------------------
# Docker service status
# ----------------------------------------------------------

DOCKER_STATUS="$(
    if docker info >/dev/null 2>&1; then
        printf '%s' "HEALTHY"
    else
        printf '%s' "CRITICAL"
    fi
)"

POSTGRES_STATUS="$(service_status wzi-postgres)"
REDIS_STATUS="$(service_status wzi-redis)"
N8N_STATUS="$(service_status wzi-n8n)"
CADDY_STATUS="$(service_status wzi-caddy)"
DASHBOARD_STATUS="$(service_status wzi-dashboard)"

POSTGRES_RESTARTS="$(restart_count wzi-postgres)"
REDIS_RESTARTS="$(restart_count wzi-redis)"
N8N_RESTARTS="$(restart_count wzi-n8n)"
CADDY_RESTARTS="$(restart_count wzi-caddy)"
DASHBOARD_RESTARTS="$(restart_count wzi-dashboard)"

# ----------------------------------------------------------
# CPU usage
# ----------------------------------------------------------

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat

TOTAL1=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE1=$((idle + iowait))

sleep 1

read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat

TOTAL2=$((user + nice + system + idle + iowait + irq + softirq + steal))
IDLE2=$((idle + iowait))

TOTAL_DELTA=$((TOTAL2 - TOTAL1))
IDLE_DELTA=$((IDLE2 - IDLE1))

if [ "$TOTAL_DELTA" -gt 0 ]; then
    CPU_PERCENT=$((100 * (TOTAL_DELTA - IDLE_DELTA) / TOTAL_DELTA))
else
    CPU_PERCENT=0
fi

# ----------------------------------------------------------
# Memory
# ----------------------------------------------------------

MEM_TOTAL_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
MEM_AVAILABLE_KB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"

MEMORY_PERCENT="$(
    awk \
        -v total="$MEM_TOTAL_KB" \
        -v available="$MEM_AVAILABLE_KB" \
        'BEGIN {
            if (total > 0)
                printf "%.0f", ((total-available)/total)*100
            else
                print 0
        }'
)"

# ----------------------------------------------------------
# Disk
# ----------------------------------------------------------

DISK_PERCENT="$(
    df -P / |
    awk 'NR==2 {
        gsub("%","",$5)
        print $5
    }'
)"

DISK_AVAILABLE="$(
    df -hP / |
    awk 'NR==2 {print $4}'
)"

# ----------------------------------------------------------
# Load and uptime
# ----------------------------------------------------------

LOAD_1="$(awk '{print $1}' /proc/loadavg)"
LOAD_5="$(awk '{print $2}' /proc/loadavg)"
LOAD_15="$(awk '{print $3}' /proc/loadavg)"

UPTIME_TEXT="$(uptime -p 2>/dev/null || printf 'unknown')"

# ----------------------------------------------------------
# PostgreSQL backup
# ----------------------------------------------------------

BACKUP_ROOT="/opt/wzi/backups/postgres"
BACKUP_STATUS="UNKNOWN"
BACKUP_PATH=""
BACKUP_AGE_HOURS=-1
BACKUP_SIZE="unknown"

LATEST_BACKUP="$(
    find "$BACKUP_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%T@ %p\n' \
        2>/dev/null |
    sort -nr |
    head -n 1 |
    cut -d' ' -f2-
)"

if [ -n "$LATEST_BACKUP" ]; then
    BACKUP_PATH="$LATEST_BACKUP"

    NOW_EPOCH="$(date +%s)"
    BACKUP_EPOCH="$(stat -c %Y "$LATEST_BACKUP")"

    BACKUP_AGE_HOURS=$(( (NOW_EPOCH - BACKUP_EPOCH) / 3600 ))

    BACKUP_SIZE="$(
        du -sh "$LATEST_BACKUP" |
        awk '{print $1}'
    )"

    if [ "$BACKUP_AGE_HOURS" -ge 36 ]; then
        BACKUP_STATUS="CRITICAL"
    elif [ "$BACKUP_AGE_HOURS" -ge 26 ]; then
        BACKUP_STATUS="WARNING"
    else
        BACKUP_STATUS="HEALTHY"
    fi
fi

# ----------------------------------------------------------
# SSL
# ----------------------------------------------------------

SSL_HOST="n8n.wzisaas.com"
SSL_STATUS="UNKNOWN"
SSL_DAYS_REMAINING=-1
SSL_EXPIRY="unknown"

SSL_EXPIRY="$(
    echo |
    openssl s_client \
        -servername "$SSL_HOST" \
        -connect "${SSL_HOST}:443" \
        2>/dev/null |
    openssl x509 \
        -noout \
        -enddate \
        2>/dev/null |
    sed 's/^notAfter=//'
)"

if [ -n "$SSL_EXPIRY" ]; then
    SSL_END_EPOCH="$(
        date -u -d "$SSL_EXPIRY" +%s 2>/dev/null || printf '0'
    )"

    NOW_EPOCH="$(date -u +%s)"

    if [ "$SSL_END_EPOCH" -gt "$NOW_EPOCH" ]; then
        SSL_DAYS_REMAINING=$(( (SSL_END_EPOCH - NOW_EPOCH + 86399) / 86400 ))

        if [ "$SSL_DAYS_REMAINING" -le 7 ]; then
            SSL_STATUS="CRITICAL"
        elif [ "$SSL_DAYS_REMAINING" -le 30 ]; then
            SSL_STATUS="WARNING"
        else
            SSL_STATUS="HEALTHY"
        fi
    else
        SSL_STATUS="CRITICAL"
        SSL_DAYS_REMAINING=0
    fi
fi

# ----------------------------------------------------------
# Git release information
# ----------------------------------------------------------

GIT_BRANCH="$(
    git -C "$PROJECT_ROOT" \
        branch --show-current \
        2>/dev/null ||
    printf 'unknown'
)"

GIT_COMMIT="$(
    git -C "$PROJECT_ROOT" \
        rev-parse --short HEAD \
        2>/dev/null ||
    printf 'unknown'
)"

# ----------------------------------------------------------
# Write sanitized JSON snapshot
# ----------------------------------------------------------

cat > "$TEMP_FILE" <<EOF
{
  "schema_version": 1,
  "generated_at": "$(timestamp)",
  "environment": "Production",
  "release": "v1.5.0",
  "overall_status": "${OVERALL_STATUS}",
  "latest_run": "${LATEST_RUN_ID}",

  "services": {
    "docker": {
      "status": "${DOCKER_STATUS}"
    },
    "postgresql": {
      "status": "${POSTGRES_STATUS}",
      "restart_count": ${POSTGRES_RESTARTS}
    },
    "redis": {
      "status": "${REDIS_STATUS}",
      "restart_count": ${REDIS_RESTARTS}
    },
    "n8n": {
      "status": "${N8N_STATUS}",
      "restart_count": ${N8N_RESTARTS}
    },
    "caddy": {
      "status": "${CADDY_STATUS}",
      "restart_count": ${CADDY_RESTARTS}
    },
    "dashboard": {
      "status": "${DASHBOARD_STATUS}",
      "restart_count": ${DASHBOARD_RESTARTS}
    }
  },

  "host": {
    "cpu_percent": ${CPU_PERCENT},
    "memory_percent": ${MEMORY_PERCENT},
    "disk_percent": ${DISK_PERCENT},
    "disk_available": "${DISK_AVAILABLE}",
    "load_1": "${LOAD_1}",
    "load_5": "${LOAD_5}",
    "load_15": "${LOAD_15}",
    "uptime": "${UPTIME_TEXT}"
  },

  "backup": {
    "status": "${BACKUP_STATUS}",
    "age_hours": ${BACKUP_AGE_HOURS},
    "size": "${BACKUP_SIZE}"
  },

  "ssl": {
    "status": "${SSL_STATUS}",
    "hostname": "${SSL_HOST}",
    "days_remaining": ${SSL_DAYS_REMAINING},
    "expires_at": "${SSL_EXPIRY}"
  },

  "release_info": {
    "branch": "${GIT_BRANCH}",
    "commit": "${GIT_COMMIT}"
  }
}
EOF

chmod 644 "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Dashboard snapshot written:"
echo "$OUTPUT_FILE"
# ----------------------------------------------------------
# Historical telemetry storage
# Failure-isolated: history failure must not break live JSON
# ----------------------------------------------------------

HISTORY_WRITER="${PROJECT_ROOT}/scripts/monitoring/telemetry-history.sh"

if [ -x "$HISTORY_WRITER" ]; then
    if "$HISTORY_WRITER" "$OUTPUT_FILE"; then
        echo "Historical telemetry write: OK"
    else
        echo "Historical telemetry write: WARNING (live snapshot preserved)" >&2
    fi
else
    echo "Historical telemetry writer unavailable; live snapshot preserved." >&2
fi

exit 0
