#!/bin/bash
# Put the shop database back to an earlier state. Everything after that point is lost.
#
#   sudo bash deploy/restore.sh backups/shopos-2026-11-08_2330.sqlite3   from a nightly copy (or a downloaded one)
#   sudo bash deploy/restore.sh r2                                       latest copy from Cloudflare R2 (server lost)
#   sudo bash deploy/restore.sh r2 "2026-11-08 14:05"                    R2, as it was at that moment (Indian time)
set -euo pipefail
cd "$(dirname "$0")/.."
src="${1:?Usage: see the top of deploy/restore.sh}"
DB=/rails/storage/production.sqlite3

read -r -p "Replace ALL current shop data with '$src ${2:-}'? Type RESTORE: " ok
[ "$ok" = "RESTORE" ] || { echo "Cancelled"; exit 1; }

# Safety copy of the current state first (skipped on a brand-new server with no data).
docker compose run --rm --no-deps backup now 2>/dev/null || true
docker compose stop app litestream 2>/dev/null || docker compose stop app

if [ "$src" = "r2" ]; then
  ts=()
  [ -n "${2:-}" ] && ts=(-timestamp "$(date -u -d "TZ=\"Asia/Kolkata\" $2" +%Y-%m-%dT%H:%M:%SZ)")   # time given in Indian time
  docker compose --profile r2 run --rm --no-deps --user 0 --entrypoint sh litestream -c \
    "rm -f $DB.restore && litestream restore -config /etc/litestream.yml ${ts[*]:-} -o $DB.restore $DB && \
     rm -f $DB $DB-wal $DB-shm && mv $DB.restore $DB && chown 1000:1000 $DB"
else
  [ -f "$src" ] || { echo "No such file: $src"; exit 1; }
  docker compose run --rm --no-deps --user 0 -v "$(realpath "$src")":/restore.sqlite3:ro --entrypoint sh backup -c \
    "[ \"\$(sqlite3 /restore.sqlite3 'PRAGMA integrity_check;')\" = ok ] && \
     rm -f $DB $DB-wal $DB-shm && cp /restore.sqlite3 $DB && chown 1000:1000 $DB"
fi

docker compose up -d
echo "Restored from $src ${2:-}"
