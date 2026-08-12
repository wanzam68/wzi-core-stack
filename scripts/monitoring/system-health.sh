#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.3.0
# Host Resource Health Monitor
# ==========================================================

set -u
set -o pipefail

SCRIPT_NAME="system-health"
LOG_DIR="/opt/wzi/core-stack/logs"
LOG_FILE="${LOG_DIR}/monitoring.log"

CPU_WARNING=80
CPU_CRITICAL=90

MEMORY_WARNING=80
MEMORY_CRITICAL=90

DISK_WARNING=85
DISK_CRITICAL=95

INODE_WARNING=85
INODE_CRITICAL=95

LOAD_WARNING_RATIO="0.80"
LOAD_CRITICAL_RATIO="1.00"

overall_status=0

mkdir -p "$LOG_DIR"

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log_line() {
    local message="$1"
    echo "$message"
    printf '%s [%s] %s\n' "$(timestamp)" "$SCRIPT_NAME" "$message" >> "$LOG_FILE"
}

set_warning() {
    if [ "$overall_status" -lt 1 ]; then
        overall_status=1
    fi
}

set_critical() {
    overall_status=2
}

check_percentage() {
    local name="$1"
    local value="$2"
    local warning="$3"
    local critical="$4"

    if [ "$value" -ge "$critical" ]; then
        log_line "[CRITICAL] ${name}: ${value}%"
        set_critical
    elif [ "$value" -ge "$warning" ]; then
        log_line "[WARNING]  ${name}: ${value}%"
        set_warning
    else
        log_line "[OK]       ${name}: ${value}%"
    fi
}

get_cpu_usage() {
    local cpu user nice system idle iowait irq softirq steal
    local total1 idle1 total2 idle2 total_delta idle_delta

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat

    total1=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle1=$((idle + iowait))

    sleep 1

    read -r cpu user nice system idle iowait irq softirq steal _ < /proc/stat

    total2=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle2=$((idle + iowait))

    total_delta=$((total2 - total1))
    idle_delta=$((idle2 - idle1))

    if [ "$total_delta" -le 0 ]; then
        echo 0
    else
        echo $((100 * (total_delta - idle_delta) / total_delta))
    fi
}

echo "=================================================="
echo "WZI Host Resource Monitor"
echo "=================================================="
echo "Timestamp : $(timestamp)"
echo "Host      : $(hostname)"
echo

# ----------------------------------------------------------
# CPU usage
# ----------------------------------------------------------

CPU_USAGE="$(get_cpu_usage)"
check_percentage "CPU usage" "$CPU_USAGE" "$CPU_WARNING" "$CPU_CRITICAL"

# ----------------------------------------------------------
# Memory usage
# ----------------------------------------------------------

MEM_TOTAL_KB="$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)"
MEM_AVAILABLE_KB="$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)"

if [ -n "$MEM_TOTAL_KB" ] &&
   [ -n "$MEM_AVAILABLE_KB" ] &&
   [ "$MEM_TOTAL_KB" -gt 0 ]; then

    MEMORY_USED_PERCENT=$(
        awk -v total="$MEM_TOTAL_KB" -v available="$MEM_AVAILABLE_KB" \
        'BEGIN { printf "%.0f", ((total - available) / total) * 100 }'
    )

    MEMORY_AVAILABLE_MB=$((MEM_AVAILABLE_KB / 1024))

    check_percentage \
        "Memory usage" \
        "$MEMORY_USED_PERCENT" \
        "$MEMORY_WARNING" \
        "$MEMORY_CRITICAL"

    log_line "[INFO]     Available memory: ${MEMORY_AVAILABLE_MB} MB"
else
    log_line "[CRITICAL] Unable to read memory information"
    set_critical
fi

# ----------------------------------------------------------
# Root filesystem disk usage
# ----------------------------------------------------------

DISK_USED_PERCENT="$(
    df -P / | awk 'NR == 2 {gsub("%", "", $5); print $5}'
)"

DISK_AVAILABLE="$(
    df -hP / | awk 'NR == 2 {print $4}'
)"

if [[ "$DISK_USED_PERCENT" =~ ^[0-9]+$ ]]; then
    check_percentage \
        "Root disk usage" \
        "$DISK_USED_PERCENT" \
        "$DISK_WARNING" \
        "$DISK_CRITICAL"

    log_line "[INFO]     Root disk available: ${DISK_AVAILABLE}"
else
    log_line "[CRITICAL] Unable to determine root disk usage"
    set_critical
fi

# ----------------------------------------------------------
# Root filesystem inode usage
# ----------------------------------------------------------

INODE_USED_PERCENT="$(
    df -Pi / | awk 'NR == 2 {gsub("%", "", $5); print $5}'
)"

if [[ "$INODE_USED_PERCENT" =~ ^[0-9]+$ ]]; then
    check_percentage \
        "Root inode usage" \
        "$INODE_USED_PERCENT" \
        "$INODE_WARNING" \
        "$INODE_CRITICAL"
else
    log_line "[WARNING]  Unable to determine inode usage"
    set_warning
fi

# ----------------------------------------------------------
# Load average
# ----------------------------------------------------------

CPU_CORES="$(nproc 2>/dev/null || echo 1)"
LOAD_1="$(awk '{print $1}' /proc/loadavg)"
LOAD_5="$(awk '{print $2}' /proc/loadavg)"
LOAD_15="$(awk '{print $3}' /proc/loadavg)"

LOAD_WARNING="$(
    awk -v cores="$CPU_CORES" -v ratio="$LOAD_WARNING_RATIO" \
    'BEGIN {printf "%.2f", cores * ratio}'
)"

LOAD_CRITICAL="$(
    awk -v cores="$CPU_CORES" -v ratio="$LOAD_CRITICAL_RATIO" \
    'BEGIN {printf "%.2f", cores * ratio}'
)"

LOAD_RESULT="$(
    awk \
        -v current_load="$LOAD_1" \
        -v warning="$LOAD_WARNING" \
        -v critical="$LOAD_CRITICAL" \
        'BEGIN {
            if (current_load >= critical) print 2;
            else if (current_load >= warning) print 1;
            else print 0;
        }'
)"

if [ "$LOAD_RESULT" -eq 2 ]; then
    log_line "[CRITICAL] Load average: ${LOAD_1}, ${LOAD_5}, ${LOAD_15} across ${CPU_CORES} CPU core(s)"
    set_critical
elif [ "$LOAD_RESULT" -eq 1 ]; then
    log_line "[WARNING]  Load average: ${LOAD_1}, ${LOAD_5}, ${LOAD_15} across ${CPU_CORES} CPU core(s)"
    set_warning
else
    log_line "[OK]       Load average: ${LOAD_1}, ${LOAD_5}, ${LOAD_15} across ${CPU_CORES} CPU core(s)"
fi

# ----------------------------------------------------------
# System uptime
# ----------------------------------------------------------

UPTIME_TEXT="$(uptime -p 2>/dev/null || uptime)"
log_line "[INFO]     Uptime: ${UPTIME_TEXT}"

# ----------------------------------------------------------
# Docker engine and container status
# ----------------------------------------------------------

if ! command -v docker >/dev/null 2>&1; then
    log_line "[CRITICAL] Docker command is unavailable"
    set_critical
elif ! docker info >/dev/null 2>&1; then
    log_line "[CRITICAL] Docker engine is unavailable or inaccessible"
    set_critical
else
    RUNNING_CONTAINERS="$(
        docker ps --format '{{.Names}}' 2>/dev/null | wc -l
    )"

    TOTAL_CONTAINERS="$(
        docker ps -a --format '{{.Names}}' 2>/dev/null | wc -l
    )"

    UNHEALTHY_CONTAINERS="$(
        docker ps \
            --filter health=unhealthy \
            --format '{{.Names}}' 2>/dev/null | wc -l
    )"

    log_line "[OK]       Docker engine is available"
    log_line "[INFO]     Containers running: ${RUNNING_CONTAINERS}/${TOTAL_CONTAINERS}"

    if [ "$UNHEALTHY_CONTAINERS" -gt 0 ]; then
        log_line "[CRITICAL] Unhealthy containers detected: ${UNHEALTHY_CONTAINERS}"
        docker ps \
            --filter health=unhealthy \
            --format '           - {{.Names}}' 2>/dev/null
        set_critical
    else
        log_line "[OK]       No unhealthy Docker containers detected"
    fi
fi

# ----------------------------------------------------------
# Overall result
# ----------------------------------------------------------

echo

case "$overall_status" in
    0)
        log_line "Overall Result: HEALTHY"
        exit 0
        ;;
    1)
        log_line "Overall Result: WARNING"
        exit 1
        ;;
    *)
        log_line "Overall Result: CRITICAL"
        exit 2
        ;;
esac
