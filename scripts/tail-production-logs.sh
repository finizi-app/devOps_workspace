#!/bin/bash
# tail-production-logs.sh - Tail b4b production deployment logs
# Usage: ./tail-production-logs.sh [service] [--lines N]

set -e

PROD_HOST="20.212.32.64"
PROD_USER="azureuser"
APP_DIR="/mnt/b4b-api"
COMPOSE_FILE="docker-compose.production.yml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse args
SERVICE=""
LINES="100"

while [[ $# -gt 0 ]]; do
    case $1 in
        --lines)
            LINES="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [service] [--lines N]"
            echo ""
            echo "Services:"
            echo "  app       - Backend API (default)"
            echo "  frontend  - Frontend Next.js"
            echo "  worker    - Celery worker"
            echo "  webhook   - Celery webhook"
            echo "  beat      - Celery beat"
            echo "  redis     - Redis cache"
            echo "  all       - All services"
            echo ""
            echo "Options:"
            echo "  --lines N  Number of past lines to show (default: 100)"
            echo "  -h, --help Show this help"
            exit 0
            ;;
        *)
            SERVICE="$1"
            shift
            ;;
    esac
done

# Default to 'all' if no service specified
if [ -z "$SERVICE" ]; then
    SERVICE="all"
fi

echo -e "${BLUE}=== B4B Production Logs ===${NC}"
echo -e "Host: ${PROD_HOST}"
echo -e "Service: ${SERVICE}"
echo -e "Lines: ${LINES}"
echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
echo ""

# SSH and tail logs
ssh "${PROD_USER}@${PROD_HOST}" "cd ${APP_DIR} && docker compose -f ${COMPOSE_FILE} logs --tail ${LINES} -f ${SERVICE}"
