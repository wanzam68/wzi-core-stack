#!/usr/bin/env bash

log_timestamp() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log_message() {
  local level="$1"
  shift
  local message="$*"

  mkdir -p "$LOG_DIR"
  printf '%s [%s] %s\n' \
    "$(log_timestamp)" \
    "$level" \
    "$message" >> "$LOG_DIR/monitoring.log"
}
