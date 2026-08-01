SCRIPT_CONFIG_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_CONFIG_DIR/../.." && pwd)"

set -a
source "$PROJECT_ROOT/.env"
set +a

REDIS_PASSWORD="${REDIS_PASSWORD:?REDIS_PASSWORD is missing from .env}"
#!/usr/bin/env bash

# WZI Monitoring Framework Configuration
# File: scripts/monitoring/config.sh

PROJECT_NAME="WZI Core Stack"
PROJECT_VERSION="1.3.0"
HOST_NAME="$(hostname)"

POSTGRES_CONTAINER="wzi-postgres"
REDIS_CONTAINER="wzi-redis"
N8N_CONTAINER="wzi-n8n"
CADDY_CONTAINER="wzi-caddy"

POSTGRES_USER="wzi_admin"
POSTGRES_DATABASE="wzi_saas"
N8N_DATABASE="n8n"

LOG_DIR="/opt/wzi/core-stack/monitoring/logs"
STATE_DIR="/opt/wzi/core-stack/monitoring/state"
BACKUP_ROOT="/opt/wzi/backups/postgres"

N8N_HEALTH_URL="https://n8n.wzisaas.com/healthz"
N8N_DOMAIN="n8n.wzisaas.com"
APP_DOMAIN="app.wzisaas.com"

DISK_WARNING_PERCENT=80
DISK_CRITICAL_PERCENT=90

MEMORY_WARNING_PERCENT=80
MEMORY_CRITICAL_PERCENT=90

BACKUP_WARNING_HOURS=26
BACKUP_CRITICAL_HOURS=36

SSL_WARNING_DAYS=30
SSL_CRITICAL_DAYS=14
