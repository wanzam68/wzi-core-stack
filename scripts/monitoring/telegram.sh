#!/usr/bin/env bash

# ==========================================================
# WZI Core Stack v1.4.0
# Telegram Notification Module
# ==========================================================

set -u
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ENV_FILE="${PROJECT_ROOT}/.env"

get_env_value() {
    local key="$1"

    sed -n "s/^${key}=//p" "$ENV_FILE" 2>/dev/null |
        tail -n 1 |
        tr -d '\r'
}

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Environment file not found: $ENV_FILE" >&2
    exit 2
fi

TELEGRAM_ENABLED="$(get_env_value TELEGRAM_ENABLED)"
TELEGRAM_BOT_TOKEN="$(get_env_value TELEGRAM_BOT_TOKEN)"
TELEGRAM_CHAT_ID="$(get_env_value TELEGRAM_CHAT_ID)"

if [ "${TELEGRAM_ENABLED:-false}" != "true" ]; then
    echo "Telegram notifications are disabled."
    exit 0
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "ERROR: Telegram token or chat ID is missing." >&2
    exit 2
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl is unavailable." >&2
    exit 2
fi

send_telegram() {
    local severity="$1"
    local message="$2"
    local icon
    local hostname_value
    local timestamp_value
    local response
    local curl_exit

    case "$severity" in
        HEALTHY|RECOVERY) icon="🟢" ;;
        WARNING)          icon="🟡" ;;
        CRITICAL)         icon="🔴" ;;
        INFO)             icon="🔵" ;;
        *)                icon="⚪" ;;
    esac

    hostname_value="$(hostname)"
    timestamp_value="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

    response="$(
        curl --silent --show-error \
            --max-time 15 \
            --request POST \
            "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
            --data-urlencode "text=${icon} WZI Core Stack Alert

Status: ${severity}
Host: ${hostname_value}
Time: ${timestamp_value}

${message}" \
            --data "disable_web_page_preview=true"
    )"

    curl_exit=$?

    if [ "$curl_exit" -ne 0 ]; then
        echo "ERROR: Telegram API request failed." >&2
        return 2
    fi

    if printf '%s' "$response" | grep -q '"ok":true'; then
        echo "Telegram ${severity} message sent successfully."
        return 0
    fi

    echo "ERROR: Telegram rejected the message." >&2
    printf '%s\n' "$response" |
        sed -E 's#bot[0-9]+:[A-Za-z0-9_-]+#bot<redacted>#g' >&2

    return 2
}

usage() {
    echo "Usage:"
    echo "  $0 test"
    echo "  $0 send INFO|WARNING|CRITICAL|RECOVERY \"message\""
}

case "${1:-}" in
    test)
        send_telegram \
            "INFO" \
            "Telegram notification module is connected successfully."
        ;;
    send)
        severity="${2:-}"
        message="${3:-}"

        if [ -z "$severity" ] || [ -z "$message" ]; then
            usage
            exit 2
        fi

        send_telegram "$severity" "$message"
        ;;
    *)
        usage
        exit 2
        ;;
esac
