#!/bin/bash
# Install a new version: copy the new code over this folder (keep .env and backups/), then
#   sudo bash deploy/update.sh
# Takes a backup first, rebuilds, and restarts. The database is migrated on start.
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T backup sh /backup.sh now
docker compose up -d --build
docker image prune -f >/dev/null
docker compose ps
