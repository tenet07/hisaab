#!/bin/sh
# Nightly copy of the shop database into ./backups on the server, kept $KEEP_DAYS days.
# The owner downloads these from Settings -> Backups. (Litestream separately copies every
# change to Cloudflare R2 within a second; this is the second, simpler safety net.)
#   sh backup.sh now    one copy immediately
#   sh backup.sh loop   (default) one copy every night at $BACKUP_AT
set -eu
DB="${SHOP_DB:-/rails/storage/production.sqlite3}"
DIR="${BACKUP_DIR:-/backups}"
backup_now() {
  f="$DIR/shopos-$(date +%Y-%m-%d_%H%M).sqlite3"
  # .backup takes a consistent copy while the app keeps running.
  sqlite3 "$DB" ".backup '$f.part'"
  # A backup you can't open is not a backup.
  [ "$(sqlite3 "$f.part" 'PRAGMA integrity_check;')" = "ok" ] || { echo "$(date '+%F %T') BACKUP CORRUPT"; rm -f "$f.part"; return 1; }
  mv "$f.part" "$f"
  find "$DIR" -name 'shopos-*.sqlite3' -mtime +"${KEEP_DAYS:-30}" -delete
  echo "$(date '+%F %T') backup ok: $f ($(du -h "$f" | cut -f1))"
}
if [ "${1:-loop}" = "now" ]; then backup_now; exit 0; fi
BACKUP_AT="${BACKUP_AT:-23:30}"
echo "Backups every night at ${BACKUP_AT}, kept ${KEEP_DAYS:-30} days"
while true; do
  # Seconds until the next BACKUP_AT (HH:MM), with plain arithmetic so it works with any date tool.
  h=${BACKUP_AT%:*}; m=${BACKUP_AT#*:}
  now=$(( $(date +%-H) * 3600 + $(date +%-M) * 60 + $(date +%-S) ))
  target=$(( ${h#0} * 3600 + ${m#0} * 60 ))
  [ "$target" -le "$now" ] && target=$((target + 86400))
  sleep $((target - now))
  backup_now || echo "$(date '+%F %T') BACKUP FAILED"
done
