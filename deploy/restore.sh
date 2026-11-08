#!/bin/bash
# Put the database back to a backup. EVERYTHING after that backup is lost.
#   sudo bash deploy/restore.sh backups/shopos-2026-11-08_2330.dump
set -euo pipefail
cd "$(dirname "$0")/.."
f="${1:?Usage: sudo bash deploy/restore.sh backups/shopos-YYYY-MM-DD_HHMM.dump}"
[ -f "$f" ] || { echo "No such file: $f"; exit 1; }
read -r -p "Replace ALL current data with $f? Type RESTORE: " ok
[ "$ok" = "RESTORE" ] || { echo "Cancelled"; exit 1; }
docker compose exec -T backup sh /backup.sh now   # safety copy of the current state first
docker compose stop app
docker compose exec -T db dropdb -U shopos --if-exists shopos_restoring
docker compose exec -T db createdb -U shopos shopos_restoring
docker compose exec -T db pg_restore -U shopos --no-owner -d shopos_restoring < "$f"
docker compose exec -T db psql -U shopos -d postgres -c "DROP DATABASE shopos WITH (FORCE)" -c "ALTER DATABASE shopos_restoring RENAME TO shopos"
docker compose start app
echo "Restored from $f"
