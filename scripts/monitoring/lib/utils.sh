#!/usr/bin/env bash

container_exists() {
  docker inspect "$1" >/dev/null 2>&1
}

container_status() {
  docker inspect \
    --format '{{.State.Status}}' \
    "$1" 2>/dev/null
}

container_health() {
  docker inspect \
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' \
    "$1" 2>/dev/null
}

container_restarts() {
  docker inspect \
    --format '{{.RestartCount}}' \
    "$1" 2>/dev/null
}

hours_since_epoch() {
  local epoch="$1"
  local now

  now="$(date +%s)"
  echo $(( (now - epoch) / 3600 ))
}
