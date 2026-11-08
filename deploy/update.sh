#!/bin/bash
# Install the latest version (built by GitHub from the main branch):
#   sudo bash deploy/update.sh
# Takes a backup first, downloads the new app image, restarts. The database is migrated on start.
set -euo pipefail
cd "$(dirname "$0")/.."
git pull --ff-only 2>/dev/null || true            # compose file, Caddyfile, scripts
docker compose exec -T backup sh /backup.sh now
docker compose pull app || docker compose build app
docker compose up -d --build backup
docker compose up -d
docker image prune -f >/dev/null
docker compose ps
