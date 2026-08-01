#!/usr/bin/env bash

print_header() {
  local title="$1"

  echo "===================================================="
  echo "$title"
  echo "===================================================="
}

print_ok() {
  printf '[OK]      %s\n' "$*"
}

print_warning() {
  printf '[WARNING] %s\n' "$*"
}

print_error() {
  printf '[ERROR]   %s\n' "$*"
}
