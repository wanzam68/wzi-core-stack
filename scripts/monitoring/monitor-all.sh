#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.4.0
# Monitoring Orchestrator with Telegram Alerting
# ==========================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

COMMON_LIBRARY="${SCRIPT_DIR}/lib/common.sh"
TELEGRAM_MODULE="${SCRIPT_DIR}/telegram.sh"

if [ ! -f "$COMMON_LIBRARY" ]; then
    echo "CRITICAL: Shared monitoring library is missing: $COMMON_LIBRARY" >&2
    exit 2
fi

# shellcheck source=lib/common.sh
source "$COMMON_LIBRARY"

COMPONENT="monitor-all"

RUN_TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
RUN_DIR="${WZI_MONITORING_LOG_DIR}/runs/${RUN_TIMESTAMP}"
SUMMARY_FILE="${RUN_DIR}/summary.txt"

STATE_DIR="${WZI_MONITORING_LOG_DIR}/state"
STATE_FILE="${STATE_DIR}/overall-status.state"

mkdir -p "$RUN_DIR" "$STATE_DIR"

# Monitor display name | script filename
MONITORS=(
    "Docker|docker-health-check.sh"
    "PostgreSQL|postgres-health.sh"
    "Redis|redis-health.sh"
    "n8n|n8n-health.sh"
    "Caddy|caddy-health.sh"
    "Dashboard|dashboard-health.sh"
    "Host Resources|system-health.sh"
    "PostgreSQL Backup|backup-health.sh"
    "Telemetry Growth|telemetry-growth.sh"
    "SSL Certificate|ssl-health.sh"
)

overall_status="$WZI_STATUS_HEALTHY"
healthy_count=0
warning_count=0
critical_count=0
missing_count=0

warning_names=()
critical_names=()

get_env_value() {
    local key="$1"

    if [ ! -f "$ENV_FILE" ]; then
        return 0
    fi

    sed -n "s/^${key}=//p" "$ENV_FILE" 2>/dev/null |
        tail -n 1 |
        tr -d '\r'
}

env_is_true() {
    case "$(get_env_value "$1")" in
        true|TRUE|yes|YES|1|on|ON)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

status_to_exit_code() {
    case "$1" in
        HEALTHY)  printf '%s' 0 ;;
        WARNING)  printf '%s' 1 ;;
        CRITICAL) printf '%s' 2 ;;
        *)        printf '%s' 2 ;;
    esac
}

send_alert() {
    local severity="$1"
    local message="$2"

    if ! env_is_true TELEGRAM_ENABLED; then
        wzi_log "$COMPONENT" \
            "[INFO] Telegram notification skipped because TELEGRAM_ENABLED is not true"
        return 0
    fi

    if [ ! -x "$TELEGRAM_MODULE" ]; then
        wzi_log "$COMPONENT" \
            "[WARNING] Telegram module is unavailable: ${TELEGRAM_MODULE}"
        return 0
    fi

    set +e
    "$TELEGRAM_MODULE" send "$severity" "$message"
    telegram_exit=$?
    set -e

    if [ "$telegram_exit" -ne 0 ]; then
        wzi_log "$COMPONENT" \
            "[WARNING] Telegram delivery failed with exit code ${telegram_exit}"
    fi

    return 0
}

join_array_lines() {
    local item

    if [ "$#" -eq 0 ]; then
        printf '%s' "None"
        return
    fi

    for item in "$@"; do
        printf '%s\n' "• ${item}"
    done
}

print_header() {
    echo "============================================================"
    echo "WZI Core Stack v1.5.0 - Consolidated Health Monitor"
    echo "============================================================"
    echo "Timestamp : $(wzi_timestamp)"
    echo "Host      : $(hostname)"
    echo "Project   : ${PROJECT_ROOT}"
    echo "Run log   : ${RUN_DIR}"
    echo
}

record_result() {
    local display_name="$1"
    local exit_code="$2"
    local duration_ms="$3"
    local status_name

    status_name="$(wzi_status_name "$exit_code")"

    printf '%-24s %-10s %8s ms\n' \
        "$display_name" \
        "$status_name" \
        "$duration_ms" |
        tee -a "$SUMMARY_FILE"

    case "$exit_code" in
        0)
            healthy_count=$((healthy_count + 1))
            ;;
        1)
            warning_count=$((warning_count + 1))
            warning_names+=("$display_name")
            ;;
        *)
            critical_count=$((critical_count + 1))
            critical_names+=("$display_name")
            ;;
    esac

    overall_status="$(wzi_merge_status "$overall_status" "$exit_code")"
}

print_header

{
    echo "Monitor                  Status       Duration"
    echo "------------------------------------------------"
} | tee "$SUMMARY_FILE"

for monitor_entry in "${MONITORS[@]}"; do
    IFS='|' read -r display_name script_name <<< "$monitor_entry"

    monitor_path="${SCRIPT_DIR}/${script_name}"
    monitor_log="${RUN_DIR}/${script_name%.sh}.log"

    if [ ! -f "$monitor_path" ]; then
        printf '%-24s %-10s %8s\n' \
            "$display_name" \
            "MISSING" \
            "-" |
            tee -a "$SUMMARY_FILE"

        printf 'Missing monitor: %s\n' "$monitor_path" > "$monitor_log"

        missing_count=$((missing_count + 1))
        critical_count=$((critical_count + 1))
        critical_names+=("${display_name} (missing)")
        overall_status="$WZI_STATUS_CRITICAL"
        continue
    fi

    if [ ! -x "$monitor_path" ]; then
        chmod +x "$monitor_path" 2>/dev/null || true
    fi

    echo
    echo "Running: ${display_name}"

    start_ns="$(date +%s%N)"

    set +e
    "$monitor_path" > "$monitor_log" 2>&1
    monitor_exit=$?
    set -e

    end_ns="$(date +%s%N)"
    duration_ms="$(wzi_duration_ms "$start_ns" "$end_ns")"

    case "$monitor_exit" in
        0|1|2)
            ;;
        *)
            printf '\nUnexpected exit code: %s\n' \
                "$monitor_exit" >> "$monitor_log"
            monitor_exit=2
            ;;
    esac

    record_result "$display_name" "$monitor_exit" "$duration_ms"
done

current_status="$(wzi_status_name "$overall_status")"

echo

{
    echo "------------------------------------------------"
    echo "Healthy  : ${healthy_count}"
    echo "Warnings : ${warning_count}"
    echo "Critical : ${critical_count}"
    echo "Missing  : ${missing_count}"
    echo
    echo "Overall Result: ${current_status}"
} | tee -a "$SUMMARY_FILE"

previous_status="UNKNOWN"

if [ -s "$STATE_FILE" ]; then
    previous_status="$(head -n 1 "$STATE_FILE" | tr -d '\r\n')"
fi

warning_text="$(join_array_lines "${warning_names[@]}")"
critical_text="$(join_array_lines "${critical_names[@]}")"

alert_message="Environment: Production
Release: v1.4.0
Previous status: ${previous_status}
Current status: ${current_status}

Warnings:
${warning_text}

Critical:
${critical_text}

Summary:
Healthy=${healthy_count}
Warning=${warning_count}
Critical=${critical_count}
Missing=${missing_count}

Run:
${RUN_TIMESTAMP}"

# ----------------------------------------------------------
# Alert transition logic
# ----------------------------------------------------------

if [ "$current_status" != "$previous_status" ]; then
    case "$current_status" in
        CRITICAL)
            if env_is_true TELEGRAM_NOTIFY_CRITICAL; then
                send_alert "CRITICAL" "$alert_message"
            fi
            ;;

        WARNING)
            if env_is_true TELEGRAM_NOTIFY_WARNING; then
                send_alert "WARNING" "$alert_message"
            fi
            ;;

        HEALTHY)
            case "$previous_status" in
                WARNING|CRITICAL)
                    if env_is_true TELEGRAM_NOTIFY_RECOVERY; then
                        send_alert "RECOVERY" "$alert_message"
                    fi
                    ;;
                UNKNOWN)
                    if env_is_true TELEGRAM_NOTIFY_HEALTHY; then
                        send_alert "HEALTHY" "$alert_message"
                    fi
                    ;;
            esac
            ;;
    esac
else
    wzi_log "$COMPONENT" \
        "[INFO] Alert suppressed; overall state remains ${current_status}"
fi

printf '%s\n' "$current_status" > "${STATE_FILE}.tmp"
mv "${STATE_FILE}.tmp" "$STATE_FILE"

wzi_log "$COMPONENT" \
    "Overall Result: ${current_status} | Previous=${previous_status} | Healthy=${healthy_count} Warning=${warning_count} Critical=${critical_count} Missing=${missing_count}"

echo
echo "Previous state : ${previous_status}"
echo "Current state  : ${current_status}"
echo "State file     : ${STATE_FILE}"
echo "Detailed logs  : ${RUN_DIR}"

exit "$overall_status"
