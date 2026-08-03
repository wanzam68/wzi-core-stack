#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/logging.sh"
source "$SCRIPT_DIR/lib/output.sh"

MONITORS=(
  "Docker|docker-health-check.sh"
  "PostgreSQL|postgres-health.sh"
  "Redis|redis-health.sh"
  "n8n|n8n-health.sh"
)

declare -A RESULTS

FAILURES=0
WARNINGS=0

print_header "WZI Core Stack Executive Health Report"

printf 'Timestamp : %s\n' "$(log_timestamp)"
printf 'Host      : %s\n' "$HOST_NAME"
printf 'Project   : %s v%s\n\n' "$PROJECT_NAME" "$PROJECT_VERSION"

for MONITOR_ENTRY in "${MONITORS[@]}"; do
  MONITOR_NAME="${MONITOR_ENTRY%%|*}"
  MONITOR_FILE="${MONITOR_ENTRY#*|}"
  MONITOR_PATH="$SCRIPT_DIR/$MONITOR_FILE"

  echo
  echo ">>> Running $MONITOR_NAME monitor"
  echo

  if [[ ! -x "$MONITOR_PATH" ]]; then
    print_error "$MONITOR_NAME monitor is missing or not executable."
    RESULTS["$MONITOR_NAME"]="CRITICAL"
    FAILURES=$((FAILURES + 1))
    continue
  fi

  set +e
  MONITOR_OUTPUT="$("$MONITOR_PATH" 2>&1)"
  MONITOR_EXIT_CODE=$?
  set -e

  printf '%s\n' "$MONITOR_OUTPUT"

  MONITOR_RESULT="$(
    printf '%s\n' "$MONITOR_OUTPUT" |
      awk -F': ' '/^Overall Result:/ {print $2}' |
      tail -n 1
  )"

  if [[ -z "$MONITOR_RESULT" ]]; then
    MONITOR_RESULT="CRITICAL"
  fi

  RESULTS["$MONITOR_NAME"]="$MONITOR_RESULT"

  case "$MONITOR_RESULT" in
    HEALTHY)
      ;;
    WARNING)
      WARNINGS=$((WARNINGS + 1))
      ;;
    *)
      FAILURES=$((FAILURES + 1))
      ;;
  esac

  if (( MONITOR_EXIT_CODE != 0 )) && [[ "$MONITOR_RESULT" == "HEALTHY" ]]; then
    RESULTS["$MONITOR_NAME"]="CRITICAL"
    FAILURES=$((FAILURES + 1))
  fi
done

echo
echo "===================================================="
echo "Executive Summary"
echo "===================================================="

printf '%-20s %-12s\n' "Monitor" "Result"
printf '%-20s %-12s\n' "--------------------" "------------"

for MONITOR_ENTRY in "${MONITORS[@]}"; do
  MONITOR_NAME="${MONITOR_ENTRY%%|*}"
  printf '%-20s %-12s\n' \
    "$MONITOR_NAME" \
    "${RESULTS[$MONITOR_NAME]:-CRITICAL}"
done

echo

if (( FAILURES > 0 )); then
  OVERALL_RESULT="CRITICAL"
  EXIT_CODE=1
elif (( WARNINGS > 0 )); then
  OVERALL_RESULT="WARNING"
  EXIT_CODE=0
else
  OVERALL_RESULT="HEALTHY"
  EXIT_CODE=0
fi

echo "Overall Platform Result: $OVERALL_RESULT"
echo "Completed: $(log_timestamp)"

log_message "$OVERALL_RESULT" \
  "Consolidated monitor completed; warnings=$WARNINGS failures=$FAILURES"

exit "$EXIT_CODE"
