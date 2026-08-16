#!/usr/bin/env bash

CONTAINER="wzi-n8n"
HEALTH_URL="http://127.0.0.1:5678/healthz"

SEVERITY=0

ok() {
    echo "[OK]      $*"
}

warning() {
    echo "[WARNING] $*"

    if [ "$SEVERITY" -lt 1 ]; then
        SEVERITY=1
    fi
}

critical() {
    echo "[ERROR]   $*"
    SEVERITY=2
}

set_critical_silent() {
    SEVERITY=2
}

echo "===================================================="
echo "WZI n8n Health Monitor"
echo "===================================================="
echo "Timestamp : $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "Host      : $(hostname)"
echo "Container : $CONTAINER"
echo

CONTAINER_PRESENT=0

if docker inspect "$CONTAINER" >/dev/null 2>&1; then
    CONTAINER_PRESENT=1
else
    critical "n8n container not found."
fi

if [ "$CONTAINER_PRESENT" -eq 1 ]; then

    if CONTAINER_STATUS="$(
        docker inspect \
            -f '{{.State.Status}}' \
            "$CONTAINER" 2>/dev/null
    )"; then

        if [ "$CONTAINER_STATUS" = "running" ]; then
            ok "Container status: $CONTAINER_STATUS"
        elif [ -n "$CONTAINER_STATUS" ]; then
            critical "Container status: $CONTAINER_STATUS"
        else
            critical "Container status unavailable."
        fi
    else
        critical "Container status inspection failed."
    fi

    if DOCKER_HEALTH="$(
        docker inspect \
            -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}not-configured{{end}}' \
            "$CONTAINER" 2>/dev/null
    )"; then

        if [ "$DOCKER_HEALTH" = "healthy" ]; then
            ok "Docker health: $DOCKER_HEALTH"
        elif [ -n "$DOCKER_HEALTH" ]; then
            critical "Docker health: $DOCKER_HEALTH"
        else
            critical "Docker health unavailable."
        fi
    else
        critical "Docker health inspection failed."
    fi

    if RESTART_COUNT="$(
        docker inspect \
            -f '{{.RestartCount}}' \
            "$CONTAINER" 2>/dev/null
    )"; then

        if printf '%s' "$RESTART_COUNT" |
            grep -Eq '^[0-9]+$'; then

            if [ "$RESTART_COUNT" -eq 0 ]; then
                ok "Container restart count: $RESTART_COUNT"
            else
                warning "Container restart count: $RESTART_COUNT"
            fi
        else
            critical "Container restart count invalid."
        fi
    else
        critical "Container restart count inspection failed."
    fi

    echo

    START_MS="$(date +%s%3N)"

    if HEALTH_RESPONSE="$(
        docker exec "$CONTAINER" sh -c \
        "if command -v wget >/dev/null 2>&1; then
             wget -qO- '$HEALTH_URL'
         elif command -v curl >/dev/null 2>&1; then
             curl -fsS --max-time 5 '$HEALTH_URL'
         elif command -v node >/dev/null 2>&1; then
             node -e \"
               const http=require('http');
               const r=http.get('$HEALTH_URL',res=>{
                 let d='';
                 res.on('data',c=>d+=c);
                 res.on('end',()=>{process.stdout.write(d);});
               });
               r.on('error',()=>process.exit(1));
               r.setTimeout(5000,()=>{r.destroy();process.exit(1);});
             \"
         else
             exit 127
         fi" 2>/dev/null
    )"; then

        END_MS="$(date +%s%3N)"
        RESPONSE_MS=$((END_MS - START_MS))

        if printf '%s\n' "$HEALTH_RESPONSE" |
            grep -Eq '"status"[[:space:]]*:[[:space:]]*"ok"'; then
            ok "Health endpoint returned OK."
        else
            critical "Unexpected health endpoint response."
        fi

        if [ "$RESPONSE_MS" -ge 0 ]; then
            ok "Response time: ${RESPONSE_MS} ms"
        fi
    else
        critical "Health endpoint request failed."
    fi
fi

echo

case "$SEVERITY" in
    0)
        echo "Overall Result: HEALTHY"
        exit 0
        ;;
    1)
        echo "Overall Result: WARNING"
        exit 1
        ;;
    *)
        echo "Overall Result: CRITICAL"
        exit 2
        ;;
esac
