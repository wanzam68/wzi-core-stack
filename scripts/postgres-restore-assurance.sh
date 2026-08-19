#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.6.0
# PostgreSQL Restore Assurance Utility
#
# NON-DESTRUCTIVE VALIDATION ONLY.
# This utility does not restore a database.
# ==========================================================

set -u
set -o pipefail

DEFAULT_BACKUP_ROOT="/opt/wzi/backups/postgres"
BACKUP_ROOT="${WZI_BACKUP_ROOT:-$DEFAULT_BACKUP_ROOT}"
POSTGRES_CONTAINER="${WZI_POSTGRES_CONTAINER:-wzi-postgres}"

usage() {
    cat <<USAGE
Usage:
  $(basename "$0") --backup-set PATH

Purpose:
  Validate a WZI PostgreSQL backup set without restoring it.

This utility verifies:
  - backup-set path containment
  - required backup artifacts
  - SHA-256 checksums
  - MANIFEST.txt contract
  - n8n database identity
  - wzi_saas database identity
  - pg_restore archive readability

Restore execution is NOT supported.
USAGE
}

fail() {
    echo "[FAIL] $1" >&2
    exit 2
}

ok() {
    echo "[OK] $1"
}

pg_restore_list() {
    archive="$1"
    output="$2"

    if command -v pg_restore >/dev/null 2>&1; then
        pg_restore --list "$archive" > "$output" 2>/dev/null
        return $?
    fi

    if command -v docker >/dev/null 2>&1 &&
       docker exec "$POSTGRES_CONTAINER" \
           sh -c 'command -v pg_restore >/dev/null 2>&1' \
           >/dev/null 2>&1; then
        docker exec -i "$POSTGRES_CONTAINER" \
            pg_restore --list \
            < "$archive" \
            > "$output" 2>/dev/null
        return $?
    fi

    return 127
}

BACKUP_SET=""

while [ "$#" -gt 0 ]; do
    case "$1" in
        --backup-set)
            [ "$#" -ge 2 ] ||
                fail "--backup-set requires a path"
            BACKUP_SET="$2"
            shift 2
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --restore|--database|--target-database|--drop|--create)
            fail "Restore-capable option is prohibited in Milestone 6D validation mode: $1"
            ;;
        *)
            fail "Unknown or prohibited argument: $1"
            ;;
    esac
done

[ -n "$BACKUP_SET" ] ||
    fail "--backup-set is required"

[ -d "$BACKUP_ROOT" ] ||
    fail "Backup root does not exist: $BACKUP_ROOT"

[ -d "$BACKUP_SET" ] ||
    fail "Backup set does not exist: $BACKUP_SET"

ROOT_REAL="$(realpath "$BACKUP_ROOT")"
SET_REAL="$(realpath "$BACKUP_SET")"

case "$SET_REAL/" in
    "$ROOT_REAL"/*/)
        ;;
    *)
        fail "Backup set is outside the authorized backup root"
        ;;
esac

ok "Backup-set path validated: $SET_REAL"

REQUIRED_ARTIFACTS=(
    "n8n.dump"
    "n8n.dump.sha256"
    "wzi_saas.dump"
    "wzi_saas.dump.sha256"
    "MANIFEST.txt"
)

for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
    if [ -s "$SET_REAL/$artifact" ] &&
       [ -r "$SET_REAL/$artifact" ]; then
        ok "Required artifact: $artifact"
    else
        fail "Required artifact missing, empty, or unreadable: $artifact"
    fi
done

for checksum_file in \
    "n8n.dump.sha256" \
    "wzi_saas.dump.sha256"
do
    if (
        cd "$SET_REAL" &&
        sha256sum -c "$checksum_file" >/dev/null 2>&1
    ); then
        ok "Checksum validated: $checksum_file"
    else
        fail "Checksum validation failed: $checksum_file"
    fi
done

MANIFEST="$SET_REAL/MANIFEST.txt"

grep -qF 'WZI PostgreSQL backup' "$MANIFEST" ||
    fail "Manifest backup identity invalid"

grep -qE '^Timestamp UTC:[[:space:]]*[0-9]{8}T[0-9]{6}Z$' \
    "$MANIFEST" ||
    fail "Manifest timestamp invalid"

grep -qE '^[[:space:]]*-[[:space:]]+n8n[[:space:]]*$' \
    "$MANIFEST" ||
    fail "Manifest does not identify database n8n"

grep -qE '^[[:space:]]*-[[:space:]]+wzi_saas[[:space:]]*$' \
    "$MANIFEST" ||
    fail "Manifest does not identify database wzi_saas"

ok "Manifest contract and database identities validated"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for database in n8n wzi_saas; do
    ARCHIVE="$SET_REAL/${database}.dump"
    LIST_FILE="$TMP_DIR/${database}.list"

    if ! pg_restore_list "$ARCHIVE" "$LIST_FILE"; then
        fail "pg_restore structural validation failed: ${database}.dump"
    fi

    OBJECT_COUNT="$(
        grep -Ec '^[0-9]+;' "$LIST_FILE" 2>/dev/null || true
    )"

    [ "$OBJECT_COUNT" -gt 0 ] ||
        fail "Archive contains no restorable objects: ${database}.dump"

    ok "Archive validated: ${database}.dump (${OBJECT_COUNT} objects)"
done

echo
echo "Restore Assurance Result : VALID"
echo "Restore Execution         : NOT PERFORMED"
echo "Production Mutation       : NONE"
exit 0
