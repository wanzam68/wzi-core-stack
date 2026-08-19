#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.6.0
# PostgreSQL Backup Assurance Monitor
# Milestone 6D candidate
# ==========================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Candidate execution occurs outside the tracked monitoring directory.
# Prefer a colocated config.sh when present; otherwise use the certified
# tracked monitoring configuration.
if [ -r "$SCRIPT_DIR/config.sh" ]; then
    source "$SCRIPT_DIR/config.sh"
elif [ -r "/opt/wzi/core-stack/scripts/monitoring/config.sh" ]; then
    source "/opt/wzi/core-stack/scripts/monitoring/config.sh"
else
    echo "[CRITICAL] Monitoring config.sh unavailable."
    exit 2
fi

# Isolated-fixture override. Production execution uses configured BACKUP_ROOT.
BACKUP_ROOT="${WZI_BACKUP_ROOT:-$BACKUP_ROOT}"

POSTGRES_CONTAINER="${WZI_POSTGRES_CONTAINER:-wzi-postgres}"

overall=0

ok() {
    echo "[OK] $1"
}

warn() {
    echo "[WARNING] $1"
    [ "$overall" -lt 1 ] && overall=1
}

crit() {
    echo "[CRITICAL] $1"
    overall=2
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

echo "=============================================="
echo "WZI PostgreSQL Backup Assurance"
echo "=============================================="
echo "Timestamp : $(date -u)"
echo

#
# Backup root
#

if [ ! -d "$BACKUP_ROOT" ]; then
    crit "Backup root not found: $BACKUP_ROOT"
    exit 2
fi

ok "Backup root exists"

#
# Latest backup directory
#

LATEST="$(ls -1dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -1)"

if [ -z "$LATEST" ]; then
    crit "No backup set found."
    exit 2
fi

ok "Latest backup:"
echo "     $LATEST"

CURRENT_EPOCH="$(date +%s)"
BACKUP_EPOCH="$(stat -c %Y "$LATEST")"
AGE_HOURS=$(( (CURRENT_EPOCH - BACKUP_EPOCH) / 3600 ))

echo "Age : ${AGE_HOURS} hours"

if [ "$AGE_HOURS" -ge "$BACKUP_CRITICAL_HOURS" ]; then
    crit "Backup too old."
elif [ "$AGE_HOURS" -ge "$BACKUP_WARNING_HOURS" ]; then
    warn "Backup approaching expiry."
else
    ok "Backup age OK"
fi

#
# Required backup artifacts
#

REQUIRED_ARTIFACTS=(
    "n8n.dump"
    "n8n.dump.sha256"
    "wzi_saas.dump"
    "wzi_saas.dump.sha256"
    "MANIFEST.txt"
)

for artifact in "${REQUIRED_ARTIFACTS[@]}"; do
    if [ -s "$LATEST/$artifact" ] && [ -r "$LATEST/$artifact" ]; then
        ok "Required artifact: $artifact"
    else
        crit "Required backup artifact missing, empty, or unreadable: $artifact"
    fi
done

#
# File count
#

FILES="$(find "$LATEST" -maxdepth 1 -type f | wc -l)"

if [ "$FILES" -eq 0 ]; then
    crit "Backup directory empty."
else
    ok "$FILES backup file(s) detected."
fi

#
# Size
#

SIZE="$(du -sh "$LATEST" | awk '{print $1}')"
ok "Backup size : $SIZE"

#
# Checksum verification
#

for checksum_file in \
    "n8n.dump.sha256" \
    "wzi_saas.dump.sha256"
do
    if [ ! -s "$LATEST/$checksum_file" ]; then
        crit "Checksum record unavailable: $checksum_file"
        continue
    fi

    if (
        cd "$LATEST" &&
        sha256sum -c "$checksum_file" >/dev/null 2>&1
    ); then
        ok "Checksum validated: $checksum_file"
    else
        crit "Checksum validation failed: $checksum_file"
    fi
done

#
# Manifest validation
#

MANIFEST="$LATEST/MANIFEST.txt"
MANIFEST_VALID=1

if [ ! -s "$MANIFEST" ]; then
    MANIFEST_VALID=0
else
    grep -qF 'WZI PostgreSQL backup' "$MANIFEST" ||
        MANIFEST_VALID=0

    grep -qE '^Timestamp UTC:[[:space:]]*[0-9]{8}T[0-9]{6}Z$' \
        "$MANIFEST" ||
        MANIFEST_VALID=0

    grep -qE '^[[:space:]]*-[[:space:]]+n8n[[:space:]]*$' \
        "$MANIFEST" ||
        MANIFEST_VALID=0

    grep -qE '^[[:space:]]*-[[:space:]]+wzi_saas[[:space:]]*$' \
        "$MANIFEST" ||
        MANIFEST_VALID=0
fi

if [ "$MANIFEST_VALID" -eq 1 ]; then
    ok "MANIFEST.txt contract validated"
else
    crit "MANIFEST.txt contract validation failed"
fi

#
# Non-restoring PostgreSQL archive validation
#

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

for database in n8n wzi_saas; do
    ARCHIVE="$LATEST/${database}.dump"
    LIST_FILE="$TMP_DIR/${database}.list"

    if [ ! -s "$ARCHIVE" ]; then
        crit "Archive unavailable for structural validation: ${database}.dump"
        continue
    fi

    if pg_restore_list "$ARCHIVE" "$LIST_FILE"; then
        OBJECT_COUNT="$(
            grep -Ec '^[0-9]+;' "$LIST_FILE" 2>/dev/null || true
        )"

        if [ "$OBJECT_COUNT" -gt 0 ]; then
            ok "Archive validated: ${database}.dump (${OBJECT_COUNT} objects)"
        else
            crit "Archive contains no restorable objects: ${database}.dump"
        fi
    else
        crit "pg_restore structural validation failed: ${database}.dump"
    fi
done

#
# Overall
#

echo

case "$overall" in
    0)
        echo "Overall Result : HEALTHY"
        exit 0
        ;;
    1)
        echo "Overall Result : WARNING"
        exit 1
        ;;
    *)
        echo "Overall Result : CRITICAL"
        exit 2
        ;;
esac
