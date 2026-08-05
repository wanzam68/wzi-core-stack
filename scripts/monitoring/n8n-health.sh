#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/utils.sh"

FAILED=0
WARNINGS=0

print_header "WZI n8n Health Monitor"

printf 'Timestamp : %s\n' "$(log_timestamp)"
printf 'Host      : %s\n' "$HOST_NAME"
printf 'Container : %s\n\n' "$N8N_CONTAINER"

if ! container_exists "$N8N_CONTAINER"; then
    print_error "n8n container not found."
    log_message ERROR "n8n container not found."
    exit 1
fi

STATUS="$(container_status "$N8N_CONTAINER")"
HEALTH="$(container_health "$N8N_CONTAINER")"
RESTARTS="$(container_restarts "$N8N_CONTAINER")"

if [[ "$STATUS" == "running" ]]; then
    print_ok "Container status: $STATUS"
else
    print_error "Container status: $STATUS"
    FAILED=$((FAILED + 1))
fi

if [[ "$HEALTH" == "healthy" ]]; then
    print_ok "Docker health: $HEALTH"
else
    print_error "Docker health: $HEALTH"
    FAILED=$((FAILED + 1))
fi

if (( RESTARTS == 0 )); then
    print_ok "Container restart count: $RESTARTS"
else
    print_warning "Container restart count: $RESTARTS"
    WARNINGS=$((WARNINGS + 1))
fi

echo

START_TIME=$(date +%s%3N)

RESPONSE="$(
docker exec "$N8N_CONTAINER" \
wget -qO- http://127.0.0.1:5678/healthz
)"

END_TIME=$(date +%s%3N)

RESPONSE_MS=$((END_TIME - START_TIME))

if [[ "$RESPONSE" == *'"status":"ok"'* ]]; then
    print_ok "Health endpoint returned OK."
else
    print_error "Unexpected health endpoint response."
    FAILED=$((FAILED + 1))
fi

print_ok "Response time: ${RESPONSE_MS} ms"

echo

if (( FAILED > 0 )); then
    RESULT="CRITICAL"
    EXIT_CODE=1
elif (( WARNINGS > 0 )); then
    RESULT="WARNING"
    EXIT_CODE=0
else
    RESULT="HEALTHY"
    EXIT_CODE=0
fi

echo "Overall Result: $RESULT"

log_message "$RESULT" \
"n8n monitor completed; warnings=$WARNINGS failures=$FAILED"

exit "$EXIT_CODE"
#!/bin/bash

# ==========================================================
# WZI Core Stack v1.3.0
# n8n Health Monitor
# ==========================================================

set -e

LOG_DIR="/opt/wzi/core-stack/logs"
LOG_FILE="${LOG_DIR}/monitoring.log"

mkdir -p "$LOG_DIR"

SERVICE="n8n"

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log() {
    echo "$(timestamp) [$SERVICE] $1" | tee -a "$LOG_FILE"
}

# ----------------------------------------------------------
# Check container
# ----------------------------------------------------------

if ! docker ps --format '{{.Names}}' | grep -q '^wzi-n8n$'; then
    log "CRITICAL : Container not running"
    exit 2
fi

STATUS=$(docker inspect \
    --format='{{.State.Status}}' \
    wzi-n8n)

HEALTH=$(docker inspect \
    --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' \
    wzi-n8n)

RESTARTS=$(docker inspect \
    --format='{{.RestartCount}}' \
    wzi-n8n)

log "Container Status : $STATUS"
log "Health          : $HEALTH"
log "Restart Count   : $RESTARTS"

# ----------------------------------------------------------
# Check HTTP Endpoint
# ----------------------------------------------------------

HTTP_CODE=$(curl \
    -o /dev/null \
    -s \
    -w "%{http_code}" \
    http://127.0.0.1:5678)

RESPONSE_TIME=$(curl \
    -o /dev/null \
    -s \
    -w "%{time_total}" \
    http://127.0.0.1:5678)

if [ "$HTTP_CODE" = "200" ]; then
    log "HTTP Status     : OK ($HTTP_CODE)"
    log "Response Time   : ${RESPONSE_TIME}s"
    log "RESULT          : HEALTHY"
    exit 0
else
    log "HTTP Status     : $HTTP_CODE"
    log "RESULT          : CRITICAL"
    exit 2
fi
