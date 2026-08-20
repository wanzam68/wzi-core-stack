#!/usr/bin/env bash

set -u
set -o pipefail

BACKUP_ROOT="${WZI_BACKUP_ROOT:-/opt/wzi/backups/postgres}"
RETENTION_DAYS="${WZI_RETENTION_DAYS:-14}"

usage() {
    cat <<USAGE
Usage:
  $0 [--backup-root PATH] [--retention-days DAYS]

Purpose:
  Non-destructively characterize PostgreSQL backup retention status.

This utility DOES NOT delete backup files.
This utility DOES NOT restore databases.
USAGE
}

fail() {
    echo "[FAIL] $*" >&2
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --backup-root)
            shift
            [ "$#" -gt 0 ] || {
                fail "--backup-root requires a value"
                exit 2
            }
            BACKUP_ROOT="$1"
            ;;
        --retention-days)
            shift
            [ "$#" -gt 0 ] || {
                fail "--retention-days requires a value"
                exit 2
            }
            RETENTION_DAYS="$1"
            ;;
        --delete|--prune|--remove|--purge|--execute|--apply)
            fail "Destructive retention option is prohibited: $1"
            exit 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown or prohibited argument: $1"
            exit 2
            ;;
    esac
    shift
done

if [ ! -d "$BACKUP_ROOT" ]; then
    fail "Backup root not found: $BACKUP_ROOT"
    exit 2
fi

case "$RETENTION_DAYS" in
    ''|*[!0-9]*)
        fail "Retention days must be a non-negative integer"
        exit 2
        ;;
esac

NOW_EPOCH="$(date -u +%s)"

mapfile -t BACKUP_DIRS < <(
    find "$BACKUP_ROOT" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' |
    grep -E '^[0-9]{8}T[0-9]{6}Z$' |
    sort
)

TOTAL="${#BACKUP_DIRS[@]}"

if [ "$TOTAL" -eq 0 ]; then
    fail "No timestamped backup sets found"
    exit 2
fi

NEWEST="${BACKUP_DIRS[$((TOTAL - 1))]}"
OLDEST="${BACKUP_DIRS[0]}"

RETAINED=0
EXPIRED=0
INVALID=0

echo "WZI PostgreSQL Retention Assurance"
echo "Backup Root       : $BACKUP_ROOT"
echo "Retention Days    : $RETENTION_DAYS"
echo "Backup Set Count  : $TOTAL"
echo "Oldest Backup     : $OLDEST"
echo "Newest Backup     : $NEWEST"
echo
echo "Backup Set Classification"
echo "------------------------------------------------------------"

for NAME in "${BACKUP_DIRS[@]}"; do
    PATHNAME="$BACKUP_ROOT/$NAME"

    if ! EPOCH="$(
        date -u \
            -d "${NAME:0:8} ${NAME:9:2}:${NAME:11:2}:${NAME:13:2}" \
            +%s 2>/dev/null
    )"; then
        echo "$NAME  INVALID_TIMESTAMP"
        INVALID=$((INVALID + 1))
        continue
    fi

    AGE_SECONDS=$((NOW_EPOCH - EPOCH))

    if [ "$AGE_SECONDS" -lt 0 ]; then
        AGE_DAYS=0
    else
        AGE_DAYS=$((AGE_SECONDS / 86400))
    fi

    STATUS="RETAIN"

    if [ "$AGE_DAYS" -gt "$RETENTION_DAYS" ]; then
        STATUS="EXPIRED"
    fi

    if [ "$NAME" = "$NEWEST" ] &&
       [ "$STATUS" = "EXPIRED" ]; then
        STATUS="RETAIN_NEWEST_SAFETY"
    fi

    case "$STATUS" in
        EXPIRED)
            EXPIRED=$((EXPIRED + 1))
            ;;
        RETAIN|RETAIN_NEWEST_SAFETY)
            RETAINED=$((RETAINED + 1))
            ;;
    esac

    printf '%s  age_days=%s  status=%s\n' \
        "$NAME" "$AGE_DAYS" "$STATUS"
done

echo
echo "Retention Assurance Summary"
echo "------------------------------------------------------------"
echo "Total Backup Sets : $TOTAL"
echo "Retained Sets     : $RETAINED"
echo "Expired Sets      : $EXPIRED"
echo "Invalid Sets      : $INVALID"
echo "Newest Backup     : $NEWEST"
echo "Deletion Executed : NO"
echo "Production Mutation: NONE"

if [ "$INVALID" -ne 0 ]; then
    echo "Retention Assurance Result : INVALID"
    exit 2
fi

echo "Retention Assurance Result : VALID"
exit 0
