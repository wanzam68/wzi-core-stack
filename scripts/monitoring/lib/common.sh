#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.3.0
# Shared Monitoring Library
# ==========================================================

WZI_MONITORING_ROOT="${WZI_MONITORING_ROOT:-/opt/wzi/core-stack}"
WZI_MONITORING_LOG_DIR="${WZI_MONITORING_LOG_DIR:-${WZI_MONITORING_ROOT}/logs}"
WZI_MONITORING_LOG_FILE="${WZI_MONITORING_LOG_FILE:-${WZI_MONITORING_LOG_DIR}/monitoring.log}"

WZI_STATUS_HEALTHY=0
WZI_STATUS_WARNING=1
WZI_STATUS_CRITICAL=2

mkdir -p "$WZI_MONITORING_LOG_DIR"

wzi_timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

wzi_status_name() {
    case "${1:-2}" in
        0) printf '%s' "HEALTHY" ;;
        1) printf '%s' "WARNING" ;;
        *) printf '%s' "CRITICAL" ;;
    esac
}

wzi_log() {
    local component="${1:-monitoring}"
    shift || true

    local message="$*"

    printf '%s\n' "$message"
    printf '%s [%s] %s\n' \
        "$(wzi_timestamp)" \
        "$component" \
        "$message" >> "$WZI_MONITORING_LOG_FILE"
}

wzi_merge_status() {
    local current="${1:-0}"
    local candidate="${2:-0}"

    if [ "$candidate" -gt "$current" ]; then
        printf '%s' "$candidate"
    else
        printf '%s' "$current"
    fi
}

wzi_duration_ms() {
    local start_ns="${1:-0}"
    local end_ns="${2:-0}"

    if [[ "$start_ns" =~ ^[0-9]+$ ]] &&
       [[ "$end_ns" =~ ^[0-9]+$ ]] &&
       [ "$end_ns" -ge "$start_ns" ]; then
        printf '%s' "$(( (end_ns - start_ns) / 1000000 ))"
    else
        printf '%s' "0"
    fi
}

wzi_require_command() {
    local command_name="${1:?command name required}"

    command -v "$command_name" >/dev/null 2>&1
}
