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
