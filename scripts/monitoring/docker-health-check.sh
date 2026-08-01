#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/output.sh"
source "$SCRIPT_DIR/lib/utils.sh"

CONTAINERS=(
  "$POSTGRES_CONTAINER"
  "$REDIS_CONTAINER"
  "$N8N_CONTAINER"
  "$CADDY_CONTAINER"
)

FAILED=0
WARNINGS=0

print_header "WZI Docker Health Monitor"

printf 'Timestamp : %s\n' "$(log_timestamp)"
printf 'Host      : %s\n' "$HOST_NAME"
printf 'Project   : %s v%s\n\n' "$PROJECT_NAME" "$PROJECT_VERSION"

printf '%-18s %-10s %-18s %-10s\n' \
  "Container" "Status" "Health" "Restarts"
printf '%-18s %-10s %-18s %-10s\n' \
  "------------------" "----------" "------------------" "----------"

for CONTAINER in "${CONTAINERS[@]}"; do
  if ! container_exists "$CONTAINER"; then
    printf '%-18s %-10s %-18s %-10s\n' \
      "$CONTAINER" "missing" "unknown" "-"
    print_error "$CONTAINER was not found."
    FAILED=$((FAILED + 1))
    continue
  fi

  STATUS="$(container_status "$CONTAINER")"
  HEALTH="$(container_health "$CONTAINER")"
  RESTARTS="$(container_restarts "$CONTAINER")"

  printf '%-18s %-10s %-18s %-10s\n' \
    "$CONTAINER" "$STATUS" "$HEALTH" "$RESTARTS"

  if [[ "$STATUS" != "running" ]]; then
    FAILED=$((FAILED + 1))
  fi

  if [[ "$HEALTH" == "unhealthy" ]]; then
    FAILED=$((FAILED + 1))
  elif [[ "$HEALTH" == "starting" ]]; then
    WARNINGS=$((WARNINGS + 1))
  fi

  if (( RESTARTS > 0 )); then
    WARNINGS=$((WARNINGS + 1))
  fi
done

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
  "Docker monitor completed; warnings=$WARNINGS failures=$FAILED"

exit "$EXIT_CODE"
