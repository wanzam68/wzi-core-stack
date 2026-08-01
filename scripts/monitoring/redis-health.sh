#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/utils.sh"

FAILED=0
WARNINGS=0

print_header "WZI Redis Health Monitor"

printf 'Timestamp : %s\n' "$(log_timestamp)"
printf 'Host      : %s\n' "$HOST_NAME"
printf 'Container : %s\n\n' "$REDIS_CONTAINER"

if ! container_exists "$REDIS_CONTAINER"; then
  print_error "Redis container was not found."
  log_message ERROR "Redis container not found: $REDIS_CONTAINER"
  exit 1
fi

STATUS="$(container_status "$REDIS_CONTAINER")"
HEALTH="$(container_health "$REDIS_CONTAINER")"
RESTARTS="$(container_restarts "$REDIS_CONTAINER")"

if [[ "$STATUS" == "running" ]]; then
  print_ok "Container status: $STATUS"
else
  print_error "Container status: $STATUS"
  FAILED=$((FAILED + 1))
fi

if [[ "$HEALTH" == "healthy" ]]; then
  print_ok "Docker health: $HEALTH"
elif [[ "$HEALTH" == "not-configured" ]]; then
  print_warning "Docker health check is not configured."
  WARNINGS=$((WARNINGS + 1))
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

REDIS_EXEC=(
  docker exec
  -e REDISCLI_AUTH="$REDIS_PASSWORD"
  "$REDIS_CONTAINER"
  redis-cli
)

if PING_RESULT="$("${REDIS_EXEC[@]}" ping 2>/dev/null)"; then
  if [[ "$PING_RESULT" == "PONG" ]]; then
    print_ok "Redis responded to PING."
  else
    print_error "Unexpected Redis PING response: $PING_RESULT"
    FAILED=$((FAILED + 1))
  fi
else
  print_error "Unable to execute Redis PING."
  FAILED=$((FAILED + 1))
fi

VERSION="$(
  "${REDIS_EXEC[@]}" INFO server 2>/dev/null |
  awk -F: '/^redis_version:/ {gsub("\r","",$2); print $2}'
)"

if [[ -n "$VERSION" ]]; then
  print_ok "Redis version: $VERSION"
else
  print_warning "Redis version could not be determined."
  WARNINGS=$((WARNINGS + 1))
fi

USED_MEMORY="$(
  "${REDIS_EXEC[@]}" INFO memory 2>/dev/null |
  awk -F: '/^used_memory_human:/ {gsub("\r","",$2); print $2}'
)"

if [[ -n "$USED_MEMORY" ]]; then
  print_ok "Used memory: $USED_MEMORY"
else
  print_warning "Redis memory usage could not be determined."
  WARNINGS=$((WARNINGS + 1))
fi

CONNECTED_CLIENTS="$(
  "${REDIS_EXEC[@]}" INFO clients 2>/dev/null |
  awk -F: '/^connected_clients:/ {gsub("\r","",$2); print $2}'
)"

if [[ -n "$CONNECTED_CLIENTS" ]]; then
  print_ok "Connected clients: $CONNECTED_CLIENTS"
else
  print_warning "Connected client count could not be determined."
  WARNINGS=$((WARNINGS + 1))
fi

if TOTAL_KEYS="$("${REDIS_EXEC[@]}" --scan 2>/dev/null | wc -l)"; then
  print_ok "Total keys: $TOTAL_KEYS"
else
  print_error "Unable to count Redis keys."
  FAILED=$((FAILED + 1))
fi

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
  "Redis monitor completed; warnings=$WARNINGS failures=$FAILED"

exit "$EXIT_CODE"
