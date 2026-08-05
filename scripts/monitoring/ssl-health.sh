#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.3.0
# SSL Certificate Health Monitor
# ==========================================================

set -u
set -o pipefail

HOST="${SSL_HOST:-n8n.wzisaas.com}"
PORT="${SSL_PORT:-443}"

SSL_WARNING_DAYS="${SSL_WARNING_DAYS:-30}"
SSL_CRITICAL_DAYS="${SSL_CRITICAL_DAYS:-7}"
CONNECT_TIMEOUT="${SSL_CONNECT_TIMEOUT:-10}"

LOG_DIR="/opt/wzi/core-stack/logs"
LOG_FILE="${LOG_DIR}/monitoring.log"

overall_status=0
TEMP_CERT="$(mktemp)"

mkdir -p "$LOG_DIR"

cleanup() {
    rm -f "$TEMP_CERT"
}

trap cleanup EXIT

timestamp() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

log_line() {
    local message="$1"

    echo "$message"
    printf '%s [ssl-health] %s\n' \
        "$(timestamp)" \
        "$message" >> "$LOG_FILE"
}

set_warning() {
    if [ "$overall_status" -lt 1 ]; then
        overall_status=1
    fi
}

set_critical() {
    overall_status=2
}

echo "=================================================="
echo "WZI SSL Certificate Monitor"
echo "=================================================="
echo "Timestamp : $(timestamp)"
echo "Host      : ${HOST}"
echo "Port      : ${PORT}"
echo

# ----------------------------------------------------------
# Required commands
# ----------------------------------------------------------

for command_name in openssl timeout date awk sed; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log_line "[CRITICAL] Required command unavailable: ${command_name}"
        set_critical
    fi
done

if [ "$overall_status" -eq 2 ]; then
    echo
    log_line "Overall Result: CRITICAL"
    exit 2
fi

# ----------------------------------------------------------
# TLS connection and certificate retrieval
# ----------------------------------------------------------

TLS_OUTPUT="$(
    timeout "$CONNECT_TIMEOUT" \
        openssl s_client \
        -connect "${HOST}:${PORT}" \
        -servername "$HOST" \
        -verify_hostname "$HOST" \
        -showcerts </dev/null 2>&1
)"

TLS_EXIT_CODE=$?

if [ "$TLS_EXIT_CODE" -eq 124 ]; then
    log_line "[CRITICAL] TLS connection timed out after ${CONNECT_TIMEOUT} seconds"
    echo
    log_line "Overall Result: CRITICAL"
    exit 2
elif [ "$TLS_EXIT_CODE" -ne 0 ]; then
    log_line "[CRITICAL] TLS connection failed with exit code ${TLS_EXIT_CODE}"
    set_critical
else
    log_line "[OK]       TLS connection established"
fi

printf '%s\n' "$TLS_OUTPUT" |
    awk '
        /-----BEGIN CERTIFICATE-----/ {
            capture = 1
        }

        capture {
            print
        }

        /-----END CERTIFICATE-----/ {
            exit
        }
    ' > "$TEMP_CERT"

if [ ! -s "$TEMP_CERT" ]; then
    log_line "[CRITICAL] Server certificate could not be retrieved"
    echo
    log_line "Overall Result: CRITICAL"
    exit 2
fi

if ! openssl x509 -in "$TEMP_CERT" -noout >/dev/null 2>&1; then
    log_line "[CRITICAL] Retrieved certificate is unreadable"
    echo
    log_line "Overall Result: CRITICAL"
    exit 2
fi

log_line "[OK]       Server certificate retrieved successfully"

# ----------------------------------------------------------
# Trust-chain and hostname verification
# ----------------------------------------------------------

VERIFY_CODE="$(
    printf '%s\n' "$TLS_OUTPUT" |
        sed -n \
        's/.*Verify return code: \([0-9][0-9]*\).*/\1/p' |
        tail -n 1
)"

VERIFY_TEXT="$(
    printf '%s\n' "$TLS_OUTPUT" |
        sed -n \
        's/.*Verify return code: [0-9][0-9]* (\(.*\)).*/\1/p' |
        tail -n 1
)"

if [ "$VERIFY_CODE" = "0" ]; then
    log_line "[OK]       Certificate trust and hostname verification passed"
else
    if [ -z "$VERIFY_CODE" ]; then
        VERIFY_CODE="unknown"
    fi

    if [ -z "$VERIFY_TEXT" ]; then
        VERIFY_TEXT="verification result unavailable"
    fi

    log_line "[CRITICAL] Certificate verification failed: ${VERIFY_CODE} (${VERIFY_TEXT})"
    set_critical
fi

# ----------------------------------------------------------
# Certificate metadata
# ----------------------------------------------------------

SUBJECT="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -subject \
        -nameopt RFC2253 |
        sed 's/^subject=//'
)"

ISSUER="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -issuer \
        -nameopt RFC2253 |
        sed 's/^issuer=//'
)"

SERIAL="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -serial |
        sed 's/^serial=//'
)"

NOT_BEFORE="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -startdate |
        sed 's/^notBefore=//'
)"

NOT_AFTER="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -enddate |
        sed 's/^notAfter=//'
)"

log_line "[INFO]     Subject: ${SUBJECT}"
log_line "[INFO]     Issuer: ${ISSUER}"
log_line "[INFO]     Serial: ${SERIAL}"
log_line "[INFO]     Valid from: ${NOT_BEFORE}"
log_line "[INFO]     Valid until: ${NOT_AFTER}"

# ----------------------------------------------------------
# Subject Alternative Names
# ----------------------------------------------------------

SAN_NAMES="$(
    openssl x509 \
        -in "$TEMP_CERT" \
        -noout \
        -ext subjectAltName 2>/dev/null |
        tail -n +2 |
        tr '\n' ' ' |
        sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
)"

if [ -n "$SAN_NAMES" ]; then
    log_line "[INFO]     Subject Alternative Names: ${SAN_NAMES}"
else
    log_line "[WARNING]  Subject Alternative Names could not be read"
    set_warning
fi

# ----------------------------------------------------------
# Certificate validity and expiry
# ----------------------------------------------------------

CURRENT_EPOCH="$(date -u +%s)"
START_EPOCH="$(date -u -d "$NOT_BEFORE" +%s 2>/dev/null)"
END_EPOCH="$(date -u -d "$NOT_AFTER" +%s 2>/dev/null)"

if [ -z "$START_EPOCH" ] || [ -z "$END_EPOCH" ]; then
    log_line "[CRITICAL] Certificate validity dates could not be parsed"
    set_critical
else
    if [ "$CURRENT_EPOCH" -lt "$START_EPOCH" ]; then
        log_line "[CRITICAL] Certificate is not yet valid"
        set_critical
    else
        log_line "[OK]       Certificate validity period has started"
    fi

    SECONDS_REMAINING=$((END_EPOCH - CURRENT_EPOCH))

    if [ "$SECONDS_REMAINING" -le 0 ]; then
        DAYS_REMAINING=0
        log_line "[CRITICAL] Certificate has expired"
        set_critical
    else
        DAYS_REMAINING=$(( (SECONDS_REMAINING + 86399) / 86400 ))

        if [ "$DAYS_REMAINING" -le "$SSL_CRITICAL_DAYS" ]; then
            log_line "[CRITICAL] Certificate expires in ${DAYS_REMAINING} day(s)"
            set_critical
        elif [ "$DAYS_REMAINING" -le "$SSL_WARNING_DAYS" ]; then
            log_line "[WARNING]  Certificate expires in ${DAYS_REMAINING} day(s)"
            set_warning
DAYS_REMAINING=$(( (SECONDS_REMAINING + 86399) / 86400 ))        else
            log_line "[OK]       Certificate expires in ${DAYS_REMAINING} day(s)"
        fi
    fi
fi

# ----------------------------------------------------------
# Overall result
# ----------------------------------------------------------

echo

case "$overall_status" in
    0)
        log_line "Overall Result: HEALTHY"
        exit 0
        ;;
    1)
        log_line "Overall Result: WARNING"
        exit 1
        ;;
    *)
        log_line "Overall Result: CRITICAL"
        exit 2
        ;;
esac
