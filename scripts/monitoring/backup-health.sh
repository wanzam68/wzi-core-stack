#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.3.0
# PostgreSQL Backup Verification Monitor
# ==========================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/config.sh"

overall=0

ok() {
    echo "[OK] $1"
}

warn() {
    echo "[WARNING] $1"
    [ $overall -lt 1 ] && overall=1
}

crit() {
    echo "[CRITICAL] $1"
    overall=2
}

echo "=============================================="
echo "WZI PostgreSQL Backup Verification"
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

LATEST=$(ls -1dt "$BACKUP_ROOT"/*/ 2>/dev/null | head -1)

if [ -z "$LATEST" ]; then
    crit "No backup set found."
    exit 2
fi

ok "Latest backup:"
echo "     $LATEST"

CURRENT_EPOCH=$(date +%s)
BACKUP_EPOCH=$(stat -c %Y "$LATEST")
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
# SQL files
#

FILES=$(find "$LATEST" -type f | wc -l)

if [ "$FILES" -eq 0 ]; then
    crit "Backup directory empty."
else
    ok "$FILES backup file(s) detected."
fi
CURRENT_EPOCH=$(date +%s)
BACKUP_EPOCH=$(stat -c %Y "$LATEST")

AGE_HOURS=$(( (CURRENT_EPOCH - BACKUP_EPOCH) / 3600 ))
#
# Size
#

SIZE=$(du -sh "$LATEST" | awk '{print $1}')

ok "Backup size : $SIZE"

#
# Overall
#

echo

case $overall in
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
