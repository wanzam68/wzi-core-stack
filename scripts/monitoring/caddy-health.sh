#!/bin/bash
CONTAINER="wzi-caddy"
HTTP_URL="http://n8n.wzisaas.com"
HTTPS_URL="https://n8n.wzisaas.com"
TLS_HOST="n8n.wzisaas.com"
SEVERITY=0
ok(){ echo "[OK] $*"; }
warning(){ echo "[WARNING] $*"; [ "$SEVERITY" -lt 1 ] && SEVERITY=1; }
critical(){ echo "[CRITICAL] $*"; SEVERITY=2; }
valid_http_status(){ case "$1" in 200|301|302|307|308) return 0;; *) return 1;; esac; }
valid_number(){ printf '%s' "$1" | grep -Eq '^[0-9]+([.][0-9]+)?$'; }

echo "============================================="
echo "WZI Caddy Health Monitor"
echo "============================================="
echo "Timestamp : $(date)"
echo "Host      : $(hostname)"
echo "Container : $CONTAINER"
echo

if CONTAINER_STATUS="$(docker inspect -f '{{.State.Status}}' "$CONTAINER" 2>/dev/null)"; then
  if [ "$CONTAINER_STATUS" = running ]; then ok "Container Status : $CONTAINER_STATUS";
  elif [ -z "$CONTAINER_STATUS" ]; then critical "Container Status : unavailable";
  else critical "Container Status : $CONTAINER_STATUS"; fi
else critical "Container Status : inspection failed"; fi

if RESTART_COUNT="$(docker inspect -f '{{.RestartCount}}' "$CONTAINER" 2>/dev/null)"; then
  if printf '%s' "$RESTART_COUNT" | grep -Eq '^[0-9]+$'; then
    if [ "$RESTART_COUNT" -eq 0 ]; then ok "Restart Count : $RESTART_COUNT"; else warning "Restart Count : $RESTART_COUNT"; fi
  else critical "Restart Count : invalid"; fi
else critical "Restart Count : inspection failed"; fi

if HTTP_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$HTTP_URL" 2>/dev/null)"; then
  if printf '%s' "$HTTP_STATUS" | grep -Eq '^[0-9]{3}$' && valid_http_status "$HTTP_STATUS"; then ok "HTTP Status : $HTTP_STATUS"; else critical "HTTP Status : ${HTTP_STATUS:-invalid}"; fi
else critical "HTTP Status : request failed"; fi

if HTTPS_STATUS="$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$HTTPS_URL" 2>/dev/null)"; then
  if printf '%s' "$HTTPS_STATUS" | grep -Eq '^[0-9]{3}$' && valid_http_status "$HTTPS_STATUS"; then ok "HTTPS Status : $HTTPS_STATUS"; else critical "HTTPS Status : ${HTTPS_STATUS:-invalid}"; fi
else critical "HTTPS Status : request failed"; fi

if RESPONSE_TIME="$(curl -sS -o /dev/null -w '%{time_total}' --connect-timeout 5 --max-time 10 "$HTTPS_URL" 2>/dev/null)"; then
  if [ -n "$RESPONSE_TIME" ] && valid_number "$RESPONSE_TIME"; then ok "Response Time : ${RESPONSE_TIME}s"; else critical "Response Time : invalid"; fi
else critical "Response Time : request failed"; fi

if CERT_DATA="$(printf '' | openssl s_client -servername "$TLS_HOST" -connect "${TLS_HOST}:443" 2>/dev/null)"; then
  if CERT_EXPIRY="$(printf '%s\n' "$CERT_DATA" | openssl x509 -noout -enddate 2>/dev/null)"; then
    if [ -n "$CERT_EXPIRY" ]; then ok "$CERT_EXPIRY"; else critical "TLS Certificate : expiry unavailable"; fi
  else critical "TLS Certificate : parsing failed"; fi
else critical "TLS Certificate : connection failed"; fi

echo
case "$SEVERITY" in
  0) echo "Overall Result : HEALTHY"; exit 0;;
  1) echo "Overall Result : WARNING"; exit 1;;
  *) echo "Overall Result : CRITICAL"; exit 2;;
esac
