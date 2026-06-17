#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VOLUMES_BASE_PATH="${VOLUMES_BASE_PATH:-${ROOT_DIR}/volumes}"

DIRECTORIES=(
  "postgres/data"
  "clickhouse/data"
  "clickhouse/logs"
  "redis/data"
  "nats/data"
  "backend/logs"
  "collector/config"
  "portainer/data"
)

echo "=== Initializing Docker Bind-Mount Volumes ==="
echo "Base path: ${VOLUMES_BASE_PATH}"

for dir in "${DIRECTORIES[@]}"; do
  full_path="${VOLUMES_BASE_PATH}/${dir}"
  if [ -d "$full_path" ]; then
    echo "  EXISTS: ${dir}"
  else
    mkdir -p "$full_path"
    echo "  CREATED: ${dir}"
  fi
done

echo ""
echo "--- Setting Permissions ---"
chmod 750 "${VOLUMES_BASE_PATH}"
echo "  ${VOLUMES_BASE_PATH} -> 750"

if [ -d "${VOLUMES_BASE_PATH}/postgres/data" ]; then
  chmod 700 "${VOLUMES_BASE_PATH}/postgres/data"
  echo "  postgres/data -> 700 (PostgreSQL requires 0700)"
fi

if [ -d "${VOLUMES_BASE_PATH}/clickhouse/data" ]; then
  chmod 750 "${VOLUMES_BASE_PATH}/clickhouse/data"
  chown -R 101:101 "${VOLUMES_BASE_PATH}/clickhouse/data" 2>/dev/null && echo "  clickhouse/data -> owned by 101:101" || echo "  clickhouse/data -> 750 (chown skipped, may need sudo)"
fi

if [ -d "${VOLUMES_BASE_PATH}/clickhouse/logs" ]; then
  chmod 750 "${VOLUMES_BASE_PATH}/clickhouse/logs"
  chown -R 101:101 "${VOLUMES_BASE_PATH}/clickhouse/logs" 2>/dev/null || true
fi

if [ -d "${VOLUMES_BASE_PATH}/redis/data" ]; then
  chmod 750 "${VOLUMES_BASE_PATH}/redis/data"
  echo "  redis/data -> 750"
fi

if [ -d "${VOLUMES_BASE_PATH}/nats/data" ]; then
  chmod 750 "${VOLUMES_BASE_PATH}/nats/data"
  echo "  nats/data -> 750"
fi

if [ -d "${VOLUMES_BASE_PATH}/backend/logs" ]; then
  chmod 750 "${VOLUMES_BASE_PATH}/backend/logs"
  echo "  backend/logs -> 750"
fi

echo ""
echo "=== Volume initialization complete ==="
echo "Directories created under: ${VOLUMES_BASE_PATH}"
echo ""
echo "Next steps:"
echo "  1. Review and adjust permissions if needed (sudo may be required)"
echo "  2. Copy .env.example to .env: cp .env.example .env"
echo "  3. Generate secrets: bash scripts/generate-secrets.sh"
echo "  4. Start services: docker compose --profile core up -d"
