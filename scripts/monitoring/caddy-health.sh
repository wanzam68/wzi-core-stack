#!/bin/bash

# DEV-3.2D isolated candidate guard:
# openssl certificate date output must be structurally valid and current
# before a successful x509 date probe is accepted.
openssl() {
    local wzi_out
    local wzi_rc
    local wzi_args=" $* "
    local wzi_not_after
    local wzi_end_epoch
    local wzi_now_epoch

    wzi_out="$(command openssl "$@" 2>&1)"
    wzi_rc=$?

    if [ "$wzi_rc" -ne 0 ]; then
        printf '%s\n' "$wzi_out" >&2
        return "$wzi_rc"
    fi

    if [[ "$wzi_args" == *" x509 "* ]] &&
       { [[ "$wzi_args" == *" -enddate "* ]] ||
         [[ "$wzi_args" == *" -dates "* ]] ||
         [[ "$wzi_args" == *" -checkend "* ]]; }; then

        if [[ "$wzi_args" == *" -checkend "* ]]; then
            # For -checkend, successful exit status is already the
            # documented semantic result. Preserve it.
            printf '%s\n' "$wzi_out"
            return 0
        fi

        wzi_not_after="$(
            printf '%s\n' "$wzi_out" |
            sed -n 's/^notAfter=//p' |
            head -n 1
        )"

        if [ -z "$wzi_not_after" ]; then
            printf '%s\n' \
                'CRITICAL: OpenSSL output missing valid notAfter certificate date.' \
                >&2
            return 67
        fi

        wzi_end_epoch="$(
            date -u -d "$wzi_not_after" +%s 2>/dev/null
        )" || {
            printf '%s\n' \
                'CRITICAL: OpenSSL certificate expiry date is not parseable.' \
                >&2
            return 68
        }

        wzi_now_epoch="$(date -u +%s)"

        if [ "$wzi_end_epoch" -le "$wzi_now_epoch" ]; then
            printf '%s\n' \
                'CRITICAL: OpenSSL certificate expiry date is stale or expired.' \
                >&2
            return 69
        fi
    fi

    printf '%s\n' "$wzi_out"
    return 0
}

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
