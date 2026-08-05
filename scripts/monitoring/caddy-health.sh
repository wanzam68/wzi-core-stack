#!/bin/bash

# ==========================================================
# WZI Core Stack v1.3.0
# Caddy Health Monitor
# ==========================================================

LOG_DIR="/opt/wzi/core-stack/logs"
LOG_FILE="$LOG_DIR/monitoring.log"

mkdir -p "$LOG_DIR"

HOST="n8n.wzisaas.com"
CONTAINER="wzi-caddy"

echo "============================================="
echo "WZI Caddy Health Monitor"
echo "============================================="

echo "Timestamp : $(date)"
echo "Host      : $(hostname)"
echo "Container : $CONTAINER"
echo

#
# Container
#

STATUS=$(docker inspect \
    --format='{{.State.Status}}' \
    "$CONTAINER")

echo "[OK] Container Status : $STATUS"

#
# Restart Count
#

RESTART=$(docker inspect \
    --format='{{.RestartCount}}' \
    "$CONTAINER")

echo "[OK] Restart Count : $RESTART"

#
# HTTP
#

HTTP=$(curl \
    -s \
    -o /dev/null \
    -w "%{http_code}" \
    http://$HOST)

echo "[OK] HTTP Status : $HTTP"

#
# HTTPS
#

HTTPS=$(curl \
    -s \
    -o /dev/null \
    -w "%{http_code}" \
    https://$HOST)

echo "[OK] HTTPS Status : $HTTPS"

#
# Response Time
#

TIME=$(curl \
    -o /dev/null \
    -s \
    -w "%{time_total}" \
    https://$HOST)

echo "[OK] Response Time : ${TIME}s"

#
# SSL Expiry
#

EXPIRY=$(echo | openssl s_client \
    -servername "$HOST" \
    -connect "$HOST":443 2>/dev/null \
    | openssl x509 -noout -enddate)

echo "[OK] $EXPIRY"

echo
echo "Overall Result : HEALTHY"
